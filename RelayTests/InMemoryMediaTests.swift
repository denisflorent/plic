// Copyright 2026 Denis Florent Media Group SRL
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
import Foundation
import OpusCodec
import Testing

@testable import Relay

/// Pins that received audio and video are decoded, played and inspected from
/// memory — and that doing so writes nothing to disk.
///
/// Fixtures are synthesised here (a tone, a few solid frames). Making them
/// needs files, which are deleted before the code under test runs; the checks
/// then look for anything new in the app's temporary and cache directories.
@MainActor
struct InMemoryMediaTests {

    // MARK: - Fixtures

    private func scratchFile(_ ext: String) -> URL {
        URL.temporaryDirectory.appending(path: "plic-fixture-\(UUID().uuidString).\(ext)")
    }

    /// A mono tone as WAV bytes.
    private func toneWAV(seconds: Double, rate: Double = 48_000) throws -> Data {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let frames = AVAudioFrameCount(seconds * rate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let samples = try #require(buffer.floatChannelData)[0]
        for index in 0..<Int(frames) {
            samples[index] = 0.5 * sin(2 * .pi * 440 * Double(index) / rate).asFloat
        }
        let url = scratchFile("wav")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        return try Data(contentsOf: url)
    }

    /// The same tone as an Ogg Opus voice message, made by Plic's own encoder.
    private func toneOggOpus(seconds: Double) throws -> Data {
        let wav = scratchFile("wav")
        let ogg = scratchFile("ogg")
        defer {
            try? FileManager.default.removeItem(at: wav)
            try? FileManager.default.removeItem(at: ogg)
        }
        try toneWAV(seconds: seconds).write(to: wav)
        try OggOpusEncoder.encode(source: wav, to: ogg)
        return try Data(contentsOf: ogg)
    }

    /// Names in the app's temporary and cache directories.
    ///
    /// Leaves out macOS's cache of compiled machine-learning models. PDFKit
    /// fills it when a PDF is shown — for text recognition — so the viewer
    /// tests, running in parallel, add to it; it holds Apple's models, never
    /// the content being viewed.
    private func diskSnapshot() -> Set<String> {
        var names: Set<String> = []
        for root in [URL.temporaryDirectory, URL.cachesDirectory] {
            let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            while let url = enumerator?.nextObject() as? URL {
                if url.path.contains("/com.apple.e5rt.e5bundlecache") { continue }
                names.insert(url.path)
            }
        }
        return names
    }

    // MARK: - Audio

    @Test("A voice message decodes from memory, at its real length")
    func decodesOggOpus() throws {
        let data = try toneOggOpus(seconds: 1.5)
        let before = diskSnapshot()

        let buffer = try InMemoryAudio.decode(data)

        #expect(buffer.format.sampleRate == 48_000)
        let seconds = Double(buffer.frameLength) / buffer.format.sampleRate
        #expect(abs(seconds - 1.5) < 0.05, "decoded \(seconds) s")
        #expect(diskSnapshot().subtracting(before).isEmpty, "decoding wrote to disk")
    }

    @Test("Ordinary audio files decode from memory too")
    func decodesWAV() throws {
        let buffer = try InMemoryAudio.decode(try toneWAV(seconds: 0.5))
        #expect(buffer.frameLength == 24_000)
    }

    @Test("Garbage is refused, not played")
    func refusesGarbage() {
        #expect(throws: (any Error).self) { try InMemoryAudio.decode(Data(repeating: 0x42, count: 10_000)) }
    }

    @Test("A seek plays exactly what remains")
    func tailCopiesTheRest() throws {
        let buffer = try InMemoryAudio.decode(try toneWAV(seconds: 0.5))
        let tail = try #require(InMemoryAudio.tail(of: buffer, from: 10_000))

        #expect(tail.frameLength == buffer.frameLength - 10_000)
        let source = try #require(buffer.floatChannelData)[0]
        let copied = try #require(tail.floatChannelData)[0]
        #expect(copied[0] == source[10_000])
        #expect(copied[Int(tail.frameLength) - 1] == source[Int(buffer.frameLength) - 1])
        #expect(InMemoryAudio.tail(of: buffer, from: AVAudioFramePosition(buffer.frameLength)) == nil)
    }

    @Test("The player loads decoded audio and reports its length")
    func playerLoadsBuffer() throws {
        let controller = AudioPlaybackController()
        let loaded = controller.load(try InMemoryAudio.decode(try toneOggOpus(seconds: 1)))
        #expect(loaded)
        #expect(controller.isLoaded)
        #expect(abs(controller.duration - 1) < 0.05)
    }

    @Test("The waveform is measured from memory")
    func waveformFromBuffer() throws {
        let waveform = try #require(WaveformExtractor.extract(from: try InMemoryAudio.decode(try toneWAV(seconds: 0.5)), buckets: 40))
        #expect(waveform.count == 40)
        #expect(waveform.max() == WaveformExtractor.maximumAmplitude)
    }

    // MARK: - Video

    /// A short H.264 movie of solid frames, as bytes.
    private func movie() async throws -> Data {
        let url = scratchFile("mov")
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<15 {
            var pixels: CVPixelBuffer?
            CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &pixels)
            let buffer = try #require(pixels)
            CVPixelBufferLockBaseAddress(buffer, [])
            memset(CVPixelBufferGetBaseAddress(buffer), 0x80, CVPixelBufferGetDataSize(buffer))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 15))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return try Data(contentsOf: url)
    }

    @Test("A video is read and a frame extracted from memory, writing nothing")
    func videoFromMemory() async throws {
        let data = try await movie()
        let before = diskSnapshot()

        let source = InMemoryAsset(data: data, mimeType: "video/quicktime", filename: "clip.mov")
        let duration = try await source.asset.load(.duration)
        let generator = AVAssetImageGenerator(asset: source.asset)
        let frame = try await generator.image(at: .zero).image
        withExtendedLifetime(source) {}

        #expect(duration.seconds > 0.9 && duration.seconds < 1.1, "\(duration.seconds) s")
        #expect(frame.width == 64)

        // CoreMedia sets up its media cache index on first use. It holds no
        // media — nothing is checked in for data served from memory — and
        // that is exactly what is checked: any other file, or any entry in the
        // index, fails the test.
        let added = diskSnapshot().subtracting(before)
        let index = URL.cachesIndex
        #expect(added.subtracting([index.deletingLastPathComponent().path, index.path]).isEmpty, "\(added)")
        if added.contains(index.path) {
            let plist = try #require(NSDictionary(contentsOf: index))
            #expect((plist["checkedinlist"] as? NSDictionary)?.count ?? 0 == 0, "CoreMedia cached media on disk")
        }
    }
}

private extension Double {
    var asFloat: Float { Float(self) }
}

private extension URL {
    /// CoreMedia's media cache index, in the app's temporary directory.
    static var cachesIndex: URL {
        URL.temporaryDirectory.appending(path: "MediaCache/diskcacherepository.plist")
    }
}
