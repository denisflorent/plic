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

/// Derives a waveform from decoded audio when the sender did not supply one.
///
/// Matrix senders are not obliged to include amplitude samples with a voice
/// message, and plenty do not. Rather than draw a flat placeholder — which
/// tells the reader nothing and makes every recording look identical — Plic
/// decodes the file and measures it.
nonisolated enum WaveformExtractor {

    /// Matrix carries waveform amplitudes on a 0–1024 scale.
    static let maximumAmplitude: UInt16 = 1024

    /// Measures decoded audio and returns one amplitude per bucket.
    ///
    /// Each bucket holds the loudest sample in its slice of the track — peak
    /// rather than RMS, because speech is mostly quiet and an averaged waveform
    /// of a voice note reads as a flat smear. Values are normalised against the
    /// loudest bucket, so a quietly recorded message still fills the view.
    ///
    /// Proportional to the track's length: call it off the main actor.
    ///
    /// - Parameters:
    ///   - buffer: The track, from ``InMemoryAudio/decode(_:)``.
    ///   - buckets: How many bars the caller intends to draw.
    /// - Returns: `buckets` amplitudes on a 0–1024 scale, or `nil` if the
    ///   buffer held no audio.
    static func extract(from buffer: AVAudioPCMBuffer, buckets: Int) -> [UInt16]? {
        let frames = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        guard buckets > 0, frames > 0, channels > 0, let samples = buffer.floatChannelData else { return nil }

        var peaks = [Float](repeating: 0, count: buckets)
        for frame in 0..<frames {
            let bucket = min(frame * buckets / frames, buckets - 1)
            var loudest: Float = 0
            for channel in 0..<channels {
                loudest = max(loudest, abs(samples[channel][frame]))
            }
            if loudest > peaks[bucket] { peaks[bucket] = loudest }
        }

        guard let ceiling = peaks.max(), ceiling > 0 else { return nil }

        return peaks.map { peak in
            UInt16((peak / ceiling * Float(maximumAmplitude)).rounded())
        }
    }
}
