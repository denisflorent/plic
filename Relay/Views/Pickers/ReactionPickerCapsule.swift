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

import AppKit
import SwiftUI

/// A horizontally scrollable capsule of recently used emoji for quick reactions.
///
/// Displays emoji from ``RecentEmojiStore`` with a trailing button to open the
/// system Character Palette for the full emoji catalog. Styled as a material
/// capsule intended to float above a message bubble inside ``ReactionPickerOverlay``.
struct ReactionPickerCapsule: View {
    /// Called with the selected emoji string when the user taps an emoji.
    let onSelect: (String) -> Void

    @Environment(\.recentEmojiStore) private var recentEmojiStore
    @State private var openCharacterPalette = false

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    // swiftlint:disable:next identifier_name
                    ForEach(recentEmojiStore.recentEmoji, id: \.self) { e in
                        EmojiCell(emoji: e) { onSelect(e) }
                    }
                }
            }
            .scrollIndicators(.hidden)

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 2)

            Button {
                openCharacterPalette = true
            } label: {
                Image(systemName: "face.smiling")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More Emoji")
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .fixedSize(horizontal: true, vertical: true)
        .background {
            EmojiCaptureField(activate: $openCharacterPalette) { text in
                onSelect(text)
            }
            .frame(width: 1, height: 1)
            .opacity(0.01)
        }
    }
}

// MARK: - Character Palette Capture

private struct EmojiCaptureField: NSViewRepresentable {
    @Binding var activate: Bool
    var onInput: (String) -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.isEditable = true
        field.stringValue = ""
        field.focusRingType = .none
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.onInput = onInput
        if activate {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                NSApp.orderFrontCharacterPalette(nil)
                activate = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onInput: onInput)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var onInput: (String) -> Void

        init(onInput: @escaping (String) -> Void) {
            self.onInput = onInput
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                onInput(text)
                field.stringValue = ""
            }
        }
    }
}

private struct EmojiCell: View {
    let emoji: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(emoji)
                .font(.title2)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isHovering ? Color.primary.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

#Preview {
    ReactionPickerCapsule { emoji in
        print("Selected: \(emoji)")
    }
    .padding()
}
