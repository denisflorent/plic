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
import Foundation
import Testing

@testable import OpusCodec

/// End-to-end coverage for the encoder: synthesise PCM, encode it, and decode
/// the result back with AVFoundation.
///
/// The round trip is the point. macOS can *decode* Ogg/Opus perfectly well —
/// it is only encoding that is broken — so if these bytes read back at the
/// right length and pitch, they are a real Ogg/Opus file that other clients
/// will accept.
struct OggOpusEncoderTests {

    /// Writes `seconds` of a sine wave as 48 kHz mono PCM.
    private func makeToneFile(frequency: Double, seconds: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tone-\(UUID().uuidString).wav")

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false
        )!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let frames = AVAudioFrameCount(48_000 * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let channel = buffer.floatChannelData![0]
        for index in 0..<Int(frames) {
            let phase: Double = 2.0 * Double.pi * frequency * Double(index) / 48_000.0
            channel[index] = Float(sin(phase) * 0.5)
        }
        try file.write(from: buffer)
        return url
    }

    /// Dominant frequency by zero-crossing rate — crude, but ample for telling
    /// a 440 Hz tone from silence or from noise.
    private func dominantFrequency(_ buffer: AVAudioPCMBuffer, rate: Double) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 1 else { return 0 }
        var crossings = 0
        for index in 1..<count where (channel[index - 1] < 0) != (channel[index] < 0) {
            crossings += 1
        }
        return Double(crossings) / 2.0 * rate / Double(count)
    }

    @Test("A tone survives the encode/decode round trip")
    func roundTripPreservesAudio() throws {
        let source = try makeToneFile(frequency: 440, seconds: 2)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("encoded-\(UUID().uuidString).ogg")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: destination)
        }

        try OggOpusEncoder.encode(source: source, to: destination)

        let size = try #require(
            try FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int
        )
        // The zero-byte files macOS produced are exactly what this guards against.
        #expect(size > 1_000, "Encoder wrote \(size) bytes")

        let decoded = try AVAudioFile(forReading: destination)
        let seconds = Double(decoded.length) / decoded.processingFormat.sampleRate
        #expect(abs(seconds - 2.0) < 0.15, "Round trip lasted \(seconds) s")

        let buffer = AVAudioPCMBuffer(
            pcmFormat: decoded.processingFormat,
            frameCapacity: AVAudioFrameCount(decoded.length)
        )!
        try decoded.read(into: buffer)
        let frequency = dominantFrequency(buffer, rate: decoded.processingFormat.sampleRate)
        #expect(abs(frequency - 440) < 25, "Decoded tone measured \(frequency) Hz")
    }

    @Test("The file starts with an Ogg page carrying an Opus header")
    func containerHeadersAreWellFormed() throws {
        let source = try makeToneFile(frequency: 440, seconds: 0.5)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("headers-\(UUID().uuidString).ogg")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: destination)
        }

        try OggOpusEncoder.encode(source: source, to: destination)
        let bytes = try Data(contentsOf: destination)

        #expect(bytes.prefix(4) == Data("OggS".utf8), "Missing Ogg capture pattern")
        // RFC 7845 puts OpusHead at the start of the first page's payload, and
        // OpusTags in its own page right after.
        #expect(bytes.range(of: Data("OpusHead".utf8)) != nil)
        #expect(bytes.range(of: Data("OpusTags".utf8)) != nil)
    }

    @Test("A recording shorter than one frame still encodes")
    func handlesSubFrameInput() throws {
        // 10 ms, less than the 20 ms Opus frame: the tail padding path.
        let source = try makeToneFile(frequency: 440, seconds: 0.01)
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("short-\(UUID().uuidString).ogg")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: destination)
        }

        try OggOpusEncoder.encode(source: source, to: destination)
        let size = try #require(
            try FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int
        )
        #expect(size > 0)
    }
}
