// Copyright 2026 Denis Florent
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import AVFoundation
import COgg
import COpus
import COpusShim
import Foundation

/// Encodes PCM audio into an Ogg-contained Opus stream.
///
/// Matrix voice messages are Ogg/Opus by [MSC3245], and macOS cannot produce
/// that combination — it advertises both the `opus` encoder and the `Oggf`
/// container, then fails every write with `pck?`. This wraps Xiph's own
/// libraries instead, following [RFC 7845] for the header packets.
///
/// [MSC3245]: https://github.com/matrix-org/matrix-spec-proposals/pull/3245
/// [RFC 7845]: https://datatracker.ietf.org/doc/html/rfc7845
public enum OggOpusEncoder {

    public enum EncodingError: Error {
        /// The source file could not be opened or held no audio.
        case unreadableSource
        /// libopus refused to start, carrying its own error code.
        case encoderUnavailable(Int32)
        /// libopus rejected a frame.
        case encodeFailed(Int32)
        /// The output file could not be created or written.
        case writeFailed
    }

    /// Opus always runs at 48 kHz internally; feeding it anything else means
    /// resampling twice.
    private static let sampleRate: Int32 = 48_000

    /// 20 ms per packet — the size every Opus implementation handles, and what
    /// WebRTC and Element both use for speech.
    private static let frameSize: Int32 = 960

    /// Comfortable for mono speech; a voice message stays small at this rate.
    private static let bitRate: Int32 = 24_000

    /// Reads `source`, encodes it, and writes an `.ogg` file to `destination`.
    ///
    /// The source is converted to 48 kHz mono float as it is read, so any
    /// format `AVAudioFile` can open will do — including the PCM that
    /// `AVAudioRecorder` produces reliably.
    ///
    /// Blocking: call it off the main actor.
    ///
    /// - Parameters:
    ///   - source: A local audio file.
    ///   - destination: Where to write the Ogg/Opus result.
    ///   - progress: Called with a 0–1 fraction as frames are encoded. Fires on
    ///     the encoding thread, so hop before touching UI. Called at most once
    ///     per percent, which is often enough to animate and cheap enough not to
    ///     slow the encode.
    public static func encode(
        source: URL,
        to destination: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) throws {
        let samples = try readMonoSamples(from: source)
        guard !samples.isEmpty else { throw EncodingError.unreadableSource }

        var status: Int32 = 0
        guard let encoder = opus_encoder_create(sampleRate, 1, OPUS_APPLICATION_VOIP, &status),
              status == OPUS_OK
        else { throw EncodingError.encoderUnavailable(status) }
        defer { opus_encoder_destroy(encoder) }

        _ = plic_opus_set_bitrate(encoder, bitRate)

        // The encoder discards this many samples of its own latency at the
        // start; the container has to declare it so players can skip them.
        var lookahead: Int32 = 0
        _ = plic_opus_get_lookahead(encoder, &lookahead)
        let preSkip = UInt16(clamping: lookahead)

        FileManager.default.createFile(atPath: destination.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: destination) else {
            throw EncodingError.writeFailed
        }
        defer { try? handle.close() }

        var stream = ogg_stream_state()
        guard ogg_stream_init(&stream, Int32.random(in: 1...Int32.max)) == 0 else {
            throw EncodingError.writeFailed
        }
        defer { ogg_stream_clear(&stream) }

        try writeHeaders(into: &stream, handle: handle, preSkip: preSkip)
        try writeAudio(
            samples: samples,
            encoder: encoder,
            stream: &stream,
            handle: handle,
            preSkip: preSkip,
            progress: progress
        )
    }

    // MARK: - Header packets

    private static func writeHeaders(
        into stream: inout ogg_stream_state,
        handle: FileHandle,
        preSkip: UInt16
    ) throws {
        var head = Data("OpusHead".utf8)
        head.append(1)                                   // version
        head.append(1)                                   // channel count
        head.append(contentsOf: withUnsafeBytes(of: preSkip.littleEndian, Array.init))
        head.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian, Array.init))
        head.append(contentsOf: withUnsafeBytes(of: UInt16(0).littleEndian, Array.init))  // output gain
        head.append(0)                                   // channel mapping family

        try submit(head, into: &stream, packetNumber: 0, granulePosition: 0, beginsStream: true)
        // Each header occupies a page of its own, as RFC 7845 requires.
        try flushPages(from: &stream, to: handle, force: true)

        let vendor = Data("Plic".utf8)
        var tags = Data("OpusTags".utf8)
        tags.append(contentsOf: withUnsafeBytes(of: UInt32(vendor.count).littleEndian, Array.init))
        tags.append(vendor)
        tags.append(contentsOf: withUnsafeBytes(of: UInt32(0).littleEndian, Array.init))  // no comments

        try submit(tags, into: &stream, packetNumber: 1, granulePosition: 0, beginsStream: false)
        try flushPages(from: &stream, to: handle, force: true)
    }

    // MARK: - Audio packets

    private static func writeAudio(
        samples: [Float],
        encoder: OpaquePointer,
        stream: inout ogg_stream_state,
        handle: FileHandle,
        preSkip: UInt16,
        progress: (@Sendable (Double) -> Void)?
    ) throws {
        let frame = Int(frameSize)
        // Opus only accepts whole frames, so pad the tail with silence rather
        // than dropping the last fraction of a second of speech.
        let frameCount = (samples.count + frame - 1) / frame
        var padded = samples
        padded.append(contentsOf: repeatElement(0, count: frameCount * frame - samples.count))

        var encoded = [UInt8](repeating: 0, count: 4_000)
        var packetNumber: Int64 = 2
        var granule = Int64(preSkip)
        var lastReportedPercent = -1

        for index in 0..<frameCount {
            let start = index * frame
            let bytes: Int32 = padded.withUnsafeBufferPointer { input in
                encoded.withUnsafeMutableBufferPointer { output in
                    opus_encode_float(
                        encoder,
                        input.baseAddress! + start,
                        frameSize,
                        output.baseAddress!,
                        Int32(output.count)
                    )
                }
            }
            guard bytes > 0 else { throw EncodingError.encodeFailed(bytes) }

            granule += Int64(frameSize)
            let isLast = index == frameCount - 1
            try submit(
                Data(encoded[0..<Int(bytes)]),
                into: &stream,
                packetNumber: packetNumber,
                granulePosition: granule,
                beginsStream: false,
                endsStream: isLast
            )
            packetNumber += 1
            try flushPages(from: &stream, to: handle, force: isLast)

            if let progress {
                let percent = (index + 1) * 100 / frameCount
                if percent != lastReportedPercent {
                    lastReportedPercent = percent
                    progress(Double(percent) / 100)
                }
            }
        }
    }

    // MARK: - Ogg plumbing

    private static func submit(
        _ payload: Data,
        into stream: inout ogg_stream_state,
        packetNumber: Int64,
        granulePosition: Int64,
        beginsStream: Bool,
        endsStream: Bool = false
    ) throws {
        var bytes = [UInt8](payload)
        try bytes.withUnsafeMutableBufferPointer { buffer in
            var packet = ogg_packet(
                packet: buffer.baseAddress,
                bytes: Int(buffer.count),
                b_o_s: beginsStream ? 1 : 0,
                e_o_s: endsStream ? 1 : 0,
                granulepos: granulePosition,
                packetno: packetNumber
            )
            guard ogg_stream_packetin(&stream, &packet) == 0 else {
                throw EncodingError.writeFailed
            }
        }
    }

    /// Drains whatever pages libogg has ready.
    ///
    /// - Parameter force: Emit a partially filled page too. Used after each
    ///   header and at end of stream; during audio it would waste space.
    private static func flushPages(
        from stream: inout ogg_stream_state,
        to handle: FileHandle,
        force: Bool
    ) throws {
        var page = ogg_page()
        while true {
            let ready = force
                ? ogg_stream_flush(&stream, &page)
                : ogg_stream_pageout(&stream, &page)
            guard ready != 0 else { break }

            var output = Data(bytes: page.header, count: page.header_len)
            output.append(Data(bytes: page.body, count: page.body_len))
            do {
                try handle.write(contentsOf: output)
            } catch {
                throw EncodingError.writeFailed
            }
        }
    }

    // MARK: - Source reading

    /// Reads any decodable file as 48 kHz mono float samples.
    private static func readMonoSamples(from url: URL) throws -> [Float] {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else {
            throw EncodingError.unreadableSource
        }
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: false
        ) else { throw EncodingError.unreadableSource }

        let source = file.processingFormat
        guard let converter = AVAudioConverter(from: source, to: target) else {
            throw EncodingError.unreadableSource
        }

        var samples: [Float] = []
        samples.reserveCapacity(Int(Double(file.length) / source.sampleRate * Double(sampleRate)))

        let chunk = AVAudioFrameCount(32_768)
        guard let input = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: chunk) else {
            throw EncodingError.unreadableSource
        }
        var reachedEnd = false

        while !reachedEnd {
            let capacity = AVAudioFrameCount(Double(chunk) * Double(sampleRate) / source.sampleRate) + 1_024
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
                throw EncodingError.unreadableSource
            }

            var conversionError: NSError?
            let outcome = converter.convert(to: output, error: &conversionError) { _, status in
                input.frameLength = 0
                guard (try? file.read(into: input)) != nil, input.frameLength > 0 else {
                    status.pointee = .endOfStream
                    reachedEnd = true
                    return nil
                }
                status.pointee = .haveData
                return input
            }

            if outcome == .error { throw EncodingError.unreadableSource }
            if let channel = output.floatChannelData?[0], output.frameLength > 0 {
                samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
            }
            if outcome == .endOfStream { break }
        }

        return samples
    }
}
