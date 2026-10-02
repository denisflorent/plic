// Copyright 2026 Link Dupont
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

import RelayInterface
import SwiftUI
import UniformTypeIdentifiers

/// Renders an audio attachment as a compact bubble with waveform icon, filename,
/// duration, download button, and play/pause on double-click.
struct AudioMessageView: View {
    @Environment(\.matrixService) private var matrixService
    @Environment(\.errorReporter) private var errorReporter
    let message: TimelineMessage

    @State private var isHovering = false
    @Environment(\.audioPlayback) private var playback
    @State private var isPreparingPlayback = false
    @State private var waveform: [UInt16]?
    @AppStorage(MessageBubbleStyle.key) private var bubbleStyle = MessageBubbleStyle.standard

    /// Bars drawn for a voice message. Enough to give a recording a recognisable
    /// silhouette at this bubble width without the bars becoming hairlines.
    private static let barCount = 40

    /// The bubble asks the shared player about its own message rather than
    /// holding a player of its own.
    private var messageID: String { message.id }

    private var mediaInfo: TimelineMessage.MediaInfo {
        message.mediaInfo!
    }

    private var style: BubbleStyle {
        .message(for: message, style: bubbleStyle)
    }

    var body: some View {
        HStack(spacing: 10) {
            playButton

            if mediaInfo.isVoiceMessage {
                voiceBody
            } else {
                attachmentBody
            }

            Spacer(minLength: 0)

            if isHovering {
                downloadButton
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 200, maxWidth: 300)
        .background(style.backgroundColor)
        .foregroundStyle(style.usesWhiteText ? .white : .primary)
        .onTapGesture(count: 2) {
            // Plays in place: the bubble is its own player, and opening the
            // audio anywhere else would mean writing it out decrypted.
            Task { await togglePlayback() }
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .task { await resolveWaveform() }
    }

    /// A voice message: waveform and elapsed time, no filename.
    ///
    /// Senders generate names like `voice-message-recording.ogg`, which say
    /// nothing and make every recording look alike. The waveform identifies it
    /// instead — two messages of the same length have different silhouettes.
    private var voiceBody: some View {
        VStack(alignment: .leading, spacing: 5) {
            WaveformView(
                amplitudes: waveform ?? [],
                progress: playback.progress(messageID),
                usesWhiteText: style.usesWhiteText,
                onSeek: { playback.seek($0, for: messageID) }
            )
            .frame(height: 26)
            .opacity(waveform == nil ? 0 : 1)

            Text(displayedTime)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(style.usesWhiteText ? .white.opacity(0.7) : .secondary)
        }
    }

    /// An attached audio file: the filename matters here, so it stays.
    private var attachmentBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(mediaInfo.filename)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 6) {
                if let duration = mediaInfo.duration, duration > 0 {
                    Text(playback.isLoaded(messageID) ? displayedTime : duration.formattedDuration)
                        .font(.caption)
                        .monospacedDigit()
                }
                if let size = mediaInfo.size, size > 0, !playback.isLoaded(messageID) {
                    if mediaInfo.duration != nil && mediaInfo.duration! > 0 {
                        Text("·")
                            .font(.caption)
                    }
                    Text(formatFileSize(size))
                        .font(.caption)
                }
            }
            .foregroundStyle(style.usesWhiteText ? .white.opacity(0.7) : .secondary)
        }
    }

    /// Elapsed time once playback has started, total length before that.
    private var displayedTime: String {
        guard playback.isLoaded(messageID) else {
            return (mediaInfo.duration ?? 0).formattedDuration
        }
        return "\(playback.currentTime(messageID).formattedDuration) · \(playback.duration(messageID).formattedDuration)"
    }

    /// Resolves the waveform, computing one when the sender omitted it.
    ///
    /// Runs on appearance rather than on first play: a bubble that draws nothing
    /// until you click it is worse than one that takes a moment to fill in.
    private func resolveWaveform() async {
        guard mediaInfo.isVoiceMessage, waveform == nil else { return }

        if let sent = mediaInfo.waveform, !sent.isEmpty {
            waveform = Self.resample(sent, to: Self.barCount)
            return
        }

        guard let data = await matrixService.mediaContent(
            mxcURL: mediaInfo.mxcURL, mediaSourceJSON: mediaInfo.mediaSourceJSON
        ) else { return }

        // Decoded in memory, never written out. Decoding is CPU work on audio
        // that may be minutes long; keep it off the main actor so the timeline
        // does not hitch while it runs.
        let buckets = Self.barCount
        let measured = await Task.detached(priority: .utility) {
            (try? InMemoryAudio.decode(data)).flatMap { WaveformExtractor.extract(from: $0, buckets: buckets) }
        }.value

        waveform = measured
    }

    /// Fits a sender-supplied waveform to the number of bars actually drawn.
    ///
    /// Senders choose their own resolution — Element sends far more samples
    /// than a bubble this wide can show — so buckets are averaged rather than
    /// sampled, which would drop peaks and flatten the result.
    private static func resample(_ source: [UInt16], to count: Int) -> [UInt16] {
        guard count > 0, !source.isEmpty else { return [] }
        guard source.count > count else { return source }

        return (0..<count).map { index in
            let start = index * source.count / count
            let end = max(start + 1, (index + 1) * source.count / count)
            let slice = source[start..<end]
            return UInt16(slice.reduce(0) { $0 + Int($1) } / slice.count)
        }
    }

    private var playButton: some View {
        Button {
            Task { await togglePlayback() }
        } label: {
            ZStack {
                Circle()
                    .fill(style.usesWhiteText ? Color.white.opacity(0.2) : Color.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                if isPreparingPlayback {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: symbolName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(style.usesWhiteText ? .white : .accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isPreparingPlayback || playback.failed(messageID))
        .help(playbackHelp)
        .accessibilityLabel(playbackHelp)
    }

    private var symbolName: String {
        if playback.failed(messageID) { return "waveform" }
        return playback.isPlaying(messageID) ? "pause.fill" : "play.fill"
    }

    private var playbackHelp: String {
        if playback.failed(messageID) { return "This audio could not be decoded" }
        return playback.isPlaying(messageID) ? "Pause" : "Play"
    }

    private func togglePlayback() async {
        if playback.isLoaded(messageID) {
            playback.togglePlayback(for: messageID)
            return
        }

        guard !isPreparingPlayback else { return }
        isPreparingPlayback = true
        defer { isPreparingPlayback = false }

        guard let data = await matrixService.mediaContent(
            mxcURL: mediaInfo.mxcURL, mediaSourceJSON: mediaInfo.mediaSourceJSON
        ) else {
            errorReporter.report(
                .mediaPreviewFailed(filename: mediaInfo.filename, reason: "The audio could not be downloaded.")
            )
            return
        }
        // Played from memory: the decrypted audio is never written to disk.
        if let buffer = await InMemoryAudio.decodeInBackground(data),
           playback.load(buffer, for: messageID) {
            playback.togglePlayback(for: messageID)
        } else {
            errorReporter.report(
                .mediaPreviewFailed(filename: mediaInfo.filename, reason: "The audio could not be decoded.")
            )
        }
    }

    private var downloadButton: some View {
        Button {
            Task { await saveMedia() }
        } label: {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    style.usesWhiteText ? .white : .primary,
                    style.usesWhiteText ? .white.opacity(0.25) : Color(.systemGray).opacity(0.2)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save…")
        .help("Save…")
    }

    private func saveMedia() async {
        do {
            try await MediaFileHelper.saveToFile(
                mediaInfo: mediaInfo, matrixService: matrixService,
                contentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
            )
        } catch {
            errorReporter.report(.mediaSaveFailed(filename: mediaInfo.filename, reason: error.localizedDescription))
        }
    }

    private func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
