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
import Observation
import OpusCodec
import OSLog
import SwiftUI

/// Records a voice message to disk and tracks its level as it goes.
///
/// Captures uncompressed PCM, then hands it to ``OggOpusEncoder`` to produce the
/// Ogg/Opus that [MSC3245] standardises on. Two stages rather than one because
/// macOS cannot write Ogg/Opus at all: it advertises the encoder and the
/// container, then fails every path with `pck?`. AAC was tried first and
/// Element X refused to play it, which is what forced Xiph's libraries into the
/// project.
///
/// [MSC3245]: https://github.com/matrix-org/matrix-spec-proposals/pull/3245
@MainActor
@Observable
final class VoiceRecorder {

    /// A finished recording, ready to upload.
    struct Recording {
        /// Local file holding the encoded audio.
        let url: URL
        /// Length in seconds.
        let duration: TimeInterval
        /// Amplitudes on the Matrix 0–1024 scale, one per sampling tick.
        let waveform: [UInt16]
        /// MIME type matching whichever encoder actually ran.
        let mimeType: String
    }

    nonisolated private static let logger = Logger(subsystem: "im.plic", category: "VoiceRecorder")

    /// Whether audio is being captured right now.
    private(set) var isRecording = false

    /// How long the current recording has been running.
    private(set) var duration: TimeInterval = 0

    /// Amplitudes captured so far, for drawing a live waveform.
    private(set) var levels: [UInt16] = []

    /// How often the level is sampled. Ten a second gives a waveform detailed
    /// enough to read without producing thousands of points for a long message.
    private static let sampleInterval: Duration = .milliseconds(100)

    /// Quietest level that still draws, in dBFS.
    ///
    /// Speech sits around −20 to −15 dBFS, so anchoring at −50 squeezed every
    /// bar into the top third of the range and produced a near-flat waveform.
    /// −60 spreads ordinary speech across the full height while still keeping a
    /// quiet room at the bottom.
    private static let floorDecibels: Float = -60

    private var recorder: AVAudioRecorder?
    private var ticker: Task<Void, Never>?
    private var mimeType = "audio/ogg"

    /// Ticks counted since capture began.
    ///
    /// Duration is derived from this rather than from `AVAudioRecorder.currentTime`,
    /// which drops to zero the moment the recorder stops. If the encoder gives
    /// up mid-recording, reading it would throw away audio we actually captured.
    private var ticks = 0

    /// Set when the recorder stopped without being asked to.
    private(set) var endedEarly = false

    /// Whether the captured audio is being encoded to Opus right now.
    private(set) var isEncoding = false

    /// How far encoding has got, 0 to 1.
    private(set) var encodingProgress: Double = 0

    /// Begins recording into a new temporary file.
    ///
    /// - Returns: `true` if capture started.
    @discardableResult
    func start() -> Bool {
        stopTicking()

        let permission = AVCaptureDevice.authorizationStatus(for: .audio)
        Self.logger.info("Starting recording; microphone authorization = \(permission.rawValue)")

        for candidate in Self.encoderCandidates {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice-\(UUID().uuidString)")
                .appendingPathExtension(candidate.fileExtension)

            let recorder: AVAudioRecorder
            do {
                recorder = try AVAudioRecorder(url: url, settings: candidate.settings)
            } catch {
                Self.logger.error(
                    "\(candidate.fileExtension, privacy: .public) recorder init failed: \(error.localizedDescription, privacy: .public)"
                )
                continue
            }

            recorder.isMeteringEnabled = true
            let prepared = recorder.prepareToRecord()
            let started = prepared && recorder.record()
            guard started else {
                Self.logger.error(
                    "\(candidate.fileExtension, privacy: .public) refused to start (prepared: \(prepared))"
                )
                try? FileManager.default.removeItem(at: url)
                continue
            }

            Self.logger.info("Recording to \(candidate.fileExtension, privacy: .public)")
            self.recorder = recorder
            mimeType = candidate.mimeType
            duration = 0
            levels = []
            isRecording = true
            startTicking()
            return true
        }

        Self.logger.error("No encoder would start")
        return false
    }

    /// Stops recording, encodes to Ogg/Opus, and returns the result.
    ///
    /// Encoding runs off the main actor; the captured PCM is deleted either way.
    ///
    /// - Returns: The recording, or `nil` if nothing usable was captured or the
    ///   encoder failed.
    func finish() async -> Recording? {
        guard let captured = stopCapture() else { return nil }

        let destination = captured.url.deletingPathExtension().appendingPathExtension("ogg")
        let source = captured.url

        isEncoding = true
        encodingProgress = 0
        defer {
            isEncoding = false
            encodingProgress = 0
        }

        // The callback fires on the encoding thread; hop back before touching
        // observable state the view is reading.
        let report: @Sendable (Double) -> Void = { [weak self] fraction in
            Task { @MainActor [weak self] in
                self?.encodingProgress = fraction
            }
        }

        let encoded = await Task.detached(priority: .userInitiated) { () -> Bool in
            do {
                try OggOpusEncoder.encode(source: source, to: destination, progress: report)
                return true
            } catch {
                Self.logger.error("Opus encoding failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }.value

        try? FileManager.default.removeItem(at: source)
        guard encoded else {
            try? FileManager.default.removeItem(at: destination)
            return nil
        }

        return Recording(
            url: destination,
            duration: captured.duration,
            waveform: Self.downsample(captured.waveform, to: Self.waveformEntries),
            mimeType: "audio/ogg"
        )
    }

    /// Averages the captured levels down to `count` entries.
    private static func downsample(_ source: [UInt16], to count: Int) -> [UInt16] {
        guard count > 0, !source.isEmpty else { return [] }
        guard source.count > count else { return source }

        return (0..<count).map { index in
            let start = index * source.count / count
            let end = max(start + 1, (index + 1) * source.count / count)
            let slice = source[start..<end]
            return UInt16(slice.reduce(0) { $0 + Int($1) } / slice.count)
        }
    }

    /// Stops the transport and hands back what was captured, before encoding.
    private func stopCapture() -> Recording? {
        guard let recorder else { return nil }

        stopTicking()
        // Our own tick count, not `recorder.currentTime`: the latter reads zero
        // once the transport has stopped, which would discard a good recording
        // whose encoder quit early.
        let length = duration
        recorder.stop()
        isRecording = false
        self.recorder = nil

        let url = recorder.url
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        Self.logger.info(
            "Finishing: \(length, format: .fixed(precision: 2)) s, \(size ?? 0) bytes, endedEarly=\(self.endedEarly)"
        )
        // A recording too short to have said anything is almost always a
        // mis-click on the button; discard it rather than sending silence.
        guard length >= 0.5 else {
            try? FileManager.default.removeItem(at: url)
            duration = 0
            levels = []
            return nil
        }

        let captured = levels
        duration = length
        return Recording(url: url, duration: length, waveform: captured, mimeType: mimeType)
    }

    /// Stops recording and deletes the file.
    func cancel() {
        stopTicking()
        if let recorder {
            recorder.stop()
            try? FileManager.default.removeItem(at: recorder.url)
        }
        recorder = nil
        isRecording = false
        duration = 0
        levels = []
    }

    private func startTicking() {
        ticks = 0
        endedEarly = false
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let recorder = self.recorder, self.isRecording else { return }

                // The encoder can give up mid-recording and stop the transport
                // without raising anything. Notice it rather than carrying on
                // appending silence to a waveform nothing is feeding.
                guard recorder.isRecording else {
                    Self.logger.error(
                        "Recorder stopped on its own after \(self.duration, format: .fixed(precision: 2)) s"
                    )
                    // Stop sampling but leave the strip on screen. Whatever was
                    // captured before the encoder quit is still worth sending,
                    // and a UI that vanishes mid-recording looks like a crash.
                    self.endedEarly = true
                    self.stopTicking()
                    return
                }

                recorder.updateMeters()
                self.ticks += 1
                self.duration = Double(self.ticks) * 0.1
                // Peak, not average: speech alternates between attacks and gaps
                // many times within 100 ms, and averaging over that window flattens
                // exactly the shape the waveform exists to show. This matches what
                // WaveformExtractor already does for received messages.
                self.levels.append(Self.amplitude(fromDecibels: recorder.peakPower(forChannel: 0)))
                try? await Task.sleep(for: Self.sampleInterval)
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }

    /// Converts a dBFS reading into the 0–1024 scale Matrix uses.
    ///
    /// The meter is logarithmic and speech sits well below 0 dBFS, so a linear
    /// reading would leave every bar near the floor. Anchoring at
    /// ``floorDecibels`` and normalising across that span puts ordinary speech
    /// in the middle of the range.
    private static func amplitude(fromDecibels decibels: Float) -> UInt16 {
        guard decibels.isFinite else { return 0 }
        let clamped = max(decibels, floorDecibels)
        let fraction = (clamped - floorDecibels) / -floorDecibels
        return UInt16(max(0, min(1, fraction)) * Float(WaveformExtractor.maximumAmplitude))
    }

    /// Capture format.
    ///
    /// Uncompressed, deliberately. macOS advertises an Opus encoder and an Ogg
    /// container and cannot write the combination — `AVAudioRecorder` produces a
    /// zero-byte file and stops the transport after seconds, and both
    /// `AVAudioFile` and `ExtAudioFile` fail with `pck?`. Capturing raw and
    /// encoding afterwards with Xiph's own libraries sidesteps all of it, and
    /// PCM is the one format `AVAudioRecorder` never gets wrong.
    private static let encoderCandidates: [(settings: [String: Any], fileExtension: String, mimeType: String)] = [
        (
            [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 48_000.0,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
            ],
            "wav",
            "audio/wav"
        )
    ]

    /// Waveform entries sent with the event.
    ///
    /// MSC3246 shows a short array, and sampling ten times a second would put
    /// 300 values on a 30-second message. Downsampling keeps the event small
    /// and matches what other clients draw.
    private static let waveformEntries = 100
}
