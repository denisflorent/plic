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

/// Renders an image attachment with thumbnail loading, tap-to-reveal for hidden media,
/// click-to-zoom preview in Plic's own viewer, and a download/save button on hover.
struct ImageMessageView: View {
    @Environment(\.matrixService) private var matrixService
    @Environment(\.mediaAutoReveal) private var autoReveal
    @Environment(\.errorReporter) private var errorReporter
    @Environment(\.gifAnimationOverride) private var gifAnimationOverride
    @AppStorage("behavior.animateGIFs") private var globalAnimateGIFs = GIFAnimationMode.onHover

    private var animateGIFs: GIFAnimationMode {
        if let override = gifAnimationOverride, let mode = GIFAnimationMode(rawValue: override) {
            return mode
        }
        return globalAnimateGIFs
    }
    let message: TimelineMessage

    @State private var image: NSImage?
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var isHovering = false
    @State private var isLoadingFullImage = false
    @State private var isRevealed = false

    private var mediaInfo: TimelineMessage.MediaInfo {
        message.mediaInfo!
    }

    /// The longest side to decode at: the displayed size, at Retina scale.
    private var maxPixelSize: CGFloat {
        max(displaySize.width, displaySize.height) * 2
    }

    private var displaySize: CGSize {
        mediaInfo.displaySize()
    }

    /// Whether this message contains a GIF image, detected by MIME type or file extension.
    private var isGIF: Bool {
        if let mime = mediaInfo.mimetype, mime.lowercased() == "image/gif" {
            return true
        }
        return mediaInfo.filename.lowercased().hasSuffix(".gif")
    }

    /// Whether the GIF should currently be animating, based on the user preference.
    private var shouldAnimateGIF: Bool {
        switch animateGIFs {
        case .always: true
        case .onHover: isHovering
        case .never: false
        }
    }

    private var shouldShow: Bool { autoReveal || isRevealed }

    /// What VoiceOver says for the image: its caption when the sender wrote
    /// one, else its file name, which is often all there is.
    private var accessibilityDescription: String {
        if let caption = mediaInfo.caption, !caption.isEmpty { return "Image: \(caption)" }
        return "Image: \(mediaInfo.filename)"
    }

    var body: some View {
        ZStack {
            if shouldShow {
                if isGIF, let imageData {
                    AnimatedImageView(data: imageData, isAnimating: shouldAnimateGIF)
                        .frame(width: displaySize.width, height: displaySize.height)
                        .clipped()
                        .accessibilityElement()
                        .accessibilityLabel(accessibilityDescription)
                        .accessibilityAddTraits(.isImage)
                } else if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: displaySize.width, height: displaySize.height)
                        .clipped()
                        .accessibilityLabel(accessibilityDescription)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray).opacity(0.15))
                        .frame(width: displaySize.width, height: displaySize.height)
                        .overlay {
                            if isLoading {
                                ProgressView()
                            } else {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
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
            if shouldShow, !isGIF, image != nil {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.ultraThinMaterial)
                    .shadow(radius: 2)
                    .opacity(isHovering ? 0.8 : 0)
                    .scaleEffect(isHovering ? 1.25 : 0.85)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if shouldShow, image != nil {
                downloadButton
                    .padding(8)
                    .opacity(isHovering ? 1 : 0)
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
                Task { await openViewer() }
            }
        }
        .overlay {
            if isLoadingFullImage {
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
            if isGIF {
                // Load full content for GIFs to preserve animation frames.
                if let data = await matrixService.mediaContent(
                    mxcURL: mediaInfo.mxcURL,
                    mediaSourceJSON: mediaInfo.mediaSourceJSON
                ) {
                    // Animation decodes every frame at full size, so a GIF too
                    // large to play safely is shown as its first frame.
                    imageData = ImageDecoding.canAnimate(data) ? data : nil
                    image = ImageDecoding.thumbnail(from: data, maxPixelSize: maxPixelSize)
                }
            } else {
                if let data = await matrixService.mediaThumbnail(
                    mxcURL: mediaInfo.mxcURL,
                    mediaSourceJSON: mediaInfo.mediaSourceJSON,
                    width: UInt64(displaySize.width * 2),
                    height: UInt64(displaySize.height * 2)
                ) {
                    image = ImageDecoding.thumbnail(from: data, maxPixelSize: maxPixelSize)
                }
            }
            isLoading = false
        }
    }

    private var downloadButton: some View {
        Button {
            Task { await saveImage() }
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

    /// Opens the full image in Plic's own viewer, from memory.
    private func openViewer() async {
        guard !isLoadingFullImage else { return }
        isLoadingFullImage = true
        defer { isLoadingFullImage = false }

        guard let data = await matrixService.mediaContent(
            mxcURL: mediaInfo.mxcURL, mediaSourceJSON: mediaInfo.mediaSourceJSON
        ) else {
            errorReporter.report(.mediaPreviewFailed(filename: mediaInfo.filename, reason: "The image could not be downloaded."))
            return
        }
        if !MediaViewer.show(.image(data), title: mediaInfo.filename) {
            errorReporter.report(.mediaPreviewFailed(filename: mediaInfo.filename, reason: "The image could not be displayed."))
        }
    }

    private func saveImage() async {
        do {
            try await MediaFileHelper.saveToFile(
                mediaInfo: mediaInfo, matrixService: matrixService,
                contentTypes: [.image]
            )
        } catch {
            errorReporter.report(.mediaSaveFailed(filename: mediaInfo.filename, reason: error.localizedDescription))
        }
    }
}
