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

import AVFoundation
import RelayInterface
import SwiftUI
import UniformTypeIdentifiers

/// Renders a video attachment with a thumbnail preview, play button overlay,
/// download button, and a click that plays it in Plic's own player.
struct VideoMessageView: View {
    @Environment(\.matrixService) private var matrixService
    @Environment(\.mediaAutoReveal) private var autoReveal
    @Environment(\.errorReporter) private var errorReporter
    let message: TimelineMessage

    @State private var thumbnail: NSImage?
    @State private var isLoading = true
    @State private var isHovering = false
    @State private var isLoadingMedia = false
    @State private var isRevealed = false

    private var mediaInfo: TimelineMessage.MediaInfo {
        message.mediaInfo!
    }

    private var displaySize: CGSize {
        mediaInfo.displaySize(defaultHeight: 180)
    }

    private var shouldShow: Bool { autoReveal || isRevealed }

    var body: some View {
        ZStack {
            if shouldShow {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: displaySize.width, height: displaySize.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray).opacity(0.15))
                        .frame(width: displaySize.width, height: displaySize.height)
                        .overlay {
                            if isLoading {
                                ProgressView()
                            }
                        }
                }
            } else {
                // A button rather than a tap gesture: hidden media is a safety
                // setting, and revealing it has to work from the keyboard and
                // with VoiceOver too.
                Button {
                    isRevealed = true
                } label: {
                    Rectangle()
                        .fill(Color(.systemGray).opacity(0.15))
                        .frame(width: displaySize.width, height: displaySize.height)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "eye.slash")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("Media Hidden")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show Hidden Media")
            }
        }
        .overlay {
            if shouldShow, !isLoadingMedia, thumbnail != nil {
                Image(systemName: "play.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.ultraThinMaterial)
                    .shadow(radius: 2)
                    .opacity(isHovering ? 0.8 : 0)
                    .scaleEffect(isHovering ? 1.25 : 0.85)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if shouldShow {
                HStack(spacing: 4) {
                    if let duration = mediaInfo.duration, duration > 0 {
                        Text(duration.formattedDuration)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    if isHovering {
                        downloadButton
                    }
                }
                .padding(8)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if shouldShow, let caption = mediaInfo.caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(8)
            }
        }
        .onTapGesture {
            if shouldShow {
                Task { await openPlayer() }
            }
        }
        .overlay {
            if isLoadingMedia {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay { ProgressView() }
            }
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .task(id: shouldShow ? mediaInfo.mxcURL : nil) {
            guard shouldShow else { return }
            isLoading = true

            // Try server-side thumbnail first.
            if let data = await matrixService.mediaThumbnail(
                mxcURL: mediaInfo.mxcURL,
                mediaSourceJSON: mediaInfo.mediaSourceJSON,
                width: UInt64(displaySize.width * 2),
                height: UInt64(displaySize.height * 2)
            ) {
                thumbnail = ImageDecoding.thumbnail(
                    from: data, maxPixelSize: max(displaySize.width, displaySize.height) * 2
                )
            }

            // Fall back to extracting a frame from the video locally.
            if thumbnail == nil, let data = await matrixService.mediaContent(
                mxcURL: mediaInfo.mxcURL,
                mediaSourceJSON: mediaInfo.mediaSourceJSON
            ) {
                // Read from memory, never written out to be inspected.
                let source = InMemoryAsset(data: data, mimeType: mediaInfo.mimetype, filename: mediaInfo.filename)
                let generator = AVAssetImageGenerator(asset: source.asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(
                    width: displaySize.width * 2,
                    height: displaySize.height * 2
                )
                if let cgImage = try? await generator.image(at: .zero).image {
                    thumbnail = NSImage(cgImage: cgImage, size: .zero)
                }
                // The resource loader holds its delegate weakly: keep the source
                // alive until the frame is out.
                withExtendedLifetime(source) {}
            }

            isLoading = false
        }
    }

    private var downloadButton: some View {
        Button {
            Task { await saveMedia() }
        } label: {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.5))
                .shadow(radius: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save…")
        .help("Save…")
    }

    /// Plays the video in Plic's own player, from memory.
    private func openPlayer() async {
        guard !isLoadingMedia else { return }
        isLoadingMedia = true
        defer { isLoadingMedia = false }

        guard let data = await matrixService.mediaContent(
            mxcURL: mediaInfo.mxcURL, mediaSourceJSON: mediaInfo.mediaSourceJSON
        ) else {
            errorReporter.report(.mediaPreviewFailed(filename: mediaInfo.filename, reason: "The video could not be downloaded."))
            return
        }
        let source = InMemoryAsset(data: data, mimeType: mediaInfo.mimetype, filename: mediaInfo.filename)
        MediaViewer.show(.video(source), title: mediaInfo.filename)
    }

    private func saveMedia() async {
        do {
            try await MediaFileHelper.saveToFile(
                mediaInfo: mediaInfo, matrixService: matrixService,
                contentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie]
            )
        } catch {
            errorReporter.report(.mediaSaveFailed(filename: mediaInfo.filename, reason: error.localizedDescription))
        }
    }
}
