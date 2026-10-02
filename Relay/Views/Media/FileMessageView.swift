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

import PDFKit
import RelayInterface
import SwiftUI
import UniformTypeIdentifiers

/// Renders a file attachment as a compact bubble with a system document icon,
/// filename, file size, and download button on hover. Double-click opens a PDF
/// in Plic's own viewer, and offers to save any other file.
struct FileMessageView: View {
    @Environment(\.matrixService) private var matrixService
    @Environment(\.errorReporter) private var errorReporter
    let message: TimelineMessage

    @State private var isLoadingMedia = false
    @State private var isHovering = false
    @AppStorage(MessageBubbleStyle.key) private var bubbleStyle = MessageBubbleStyle.standard

    private var mediaInfo: TimelineMessage.MediaInfo {
        message.mediaInfo!
    }

    private var style: BubbleStyle {
        .message(for: message, style: bubbleStyle)
    }

    /// The resolved UTType for this file, derived from the MIME type or filename extension.
    private var resolvedContentType: UTType {
        if let mime = mediaInfo.mimetype, let type = UTType(mimeType: mime) {
            return type
        }
        let ext = (mediaInfo.filename as NSString).pathExtension
        if !ext.isEmpty, let type = UTType(filenameExtension: ext) {
            return type
        }
        return .data
    }

    /// The system icon for this file type, looked up via NSWorkspace.
    private var fileIcon: NSImage {
        NSWorkspace.shared.icon(for: resolvedContentType)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: fileIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(mediaInfo.filename)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let size = mediaInfo.size, size > 0 {
                    Text(formatFileSize(size))
                        .font(.caption)
                        .foregroundStyle(style.usesWhiteText ? .white.opacity(0.7) : .secondary)
                }
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
            Task { await openAttachment() }
        }
        .overlay {
            if isLoadingMedia {
                BubbleStyle.shape
                    .fill(.ultraThinMaterial)
                    .overlay { ProgressView() }
            }
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
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

    /// Opens a PDF in Plic's own viewer, from memory. Any other document can
    /// only be displayed by another app, which needs a file — so it is offered
    /// for saving instead, and written only where the user chooses.
    private func openAttachment() async {
        guard isPDF else {
            await saveMedia(
                message: "Plic keeps attachments in memory and never writes them to disk on its own. Save this file to open it in another app."
            )
            return
        }
        guard !isLoadingMedia else { return }
        isLoadingMedia = true
        defer { isLoadingMedia = false }

        guard let data = await matrixService.mediaContent(
            mxcURL: mediaInfo.mxcURL, mediaSourceJSON: mediaInfo.mediaSourceJSON
        ), let document = PDFDocument(data: data) else {
            errorReporter.report(.mediaPreviewFailed(filename: mediaInfo.filename, reason: "The PDF could not be opened."))
            return
        }
        MediaViewer.show(.pdf(document), title: mediaInfo.filename)
    }

    private var isPDF: Bool {
        mediaInfo.mimetype == "application/pdf" || mediaInfo.filename.lowercased().hasSuffix(".pdf")
    }

    private func saveMedia(message: String? = nil) async {
        do {
            try await MediaFileHelper.saveToFile(
                mediaInfo: mediaInfo, matrixService: matrixService,
                contentTypes: [resolvedContentType], message: message
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
