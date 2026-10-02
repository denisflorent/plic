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

import SwiftUI

/// A full-area overlay that dims the timeline and presents a ``ReactionPickerCapsule``
/// just above the target message bubble.
///
/// Presented at the ``TimelineView`` level so the dimming covers the whole
/// message list and the capsule can extend beyond any single row. Tapping the
/// dimmed backdrop dismisses the overlay.
struct ReactionPickerOverlay: View {
    /// The frame of the message bubble in **global** (window) coordinates.
    /// Captured this way because it must cross the table renderer's per-row
    /// `NSHostingView` boundary, where a named timeline coordinate space can't
    /// resolve. The overlay converts it to its own local space below.
    let bubbleFrame: CGRect

    /// Whether the target message is outgoing (determines capsule alignment).
    let isOutgoing: Bool

    /// Called when the user selects an emoji.
    let onSelect: (String) -> Void

    /// Called when the overlay should be dismissed (backdrop tap or selection).
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// Vertical gap between the bottom of the capsule and the top of the bubble.
    private let gap: CGFloat = 8

    var body: some View {
        ZStack {
            // Dimmed backdrop — darker in dark mode, lighter fog in light mode.
            // Kept as its own layer so its `.ignoresSafeArea()` expansion can't
            // grow the capsule's alignment container. Tapping it dismisses.
            (colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1))
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Anchor the capsule's bottom edge `gap` above the bubble's top.
            // Outgoing: trailing-aligned to the bubble's trailing edge.
            // Incoming: leading-aligned to the bubble's leading edge so the
            // capsule extends rightward into the visible timeline area.
            GeometryReader { geo in
                // Convert the bubble's global frame into this overlay's local
                // space by subtracting the overlay's own global origin.
                let origin = geo.frame(in: .global).origin
                let bubble = bubbleFrame.offsetBy(dx: -origin.x, dy: -origin.y)
                let bottomInset = max(0, geo.size.height - (bubble.minY - gap))

                ReactionPickerCapsule { emoji in
                    onSelect(emoji)
                    onDismiss()
                }
                .fixedSize()
                .padding(.bottom, bottomInset)
                .padding(
                    isOutgoing ? .trailing : .leading,
                    isOutgoing
                        ? max(0, geo.size.width - bubble.maxX)
                        : max(0, bubble.minX)
                )
                .frame(
                    width: geo.size.width,
                    height: geo.size.height,
                    alignment: isOutgoing ? .bottomTrailing : .bottomLeading
                )
            }
        }
        .transition(.opacity)
    }
}
