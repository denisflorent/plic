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

/// Encapsulates the visual properties of a message bubble: background color,
/// text color, corner radius, and padding. Used by ``MessageBubbleContent``,
/// ``ReplyPreviewBubble``, and ``AudioMessageView`` to ensure consistent styling
/// across all message types.
struct BubbleStyle {
    /// The bubble's background fill color.
    let backgroundColor: Color

    /// The primary text color inside the bubble.
    let foregroundStyle: AnyShapeStyle

    /// The corner radius for the bubble shape.
    static let cornerRadius: CGFloat = 17

    /// Horizontal padding inside the bubble.
    static let horizontalPadding: CGFloat = 12

    /// Vertical padding inside the bubble.
    static let verticalPadding: CGFloat = 7

    /// The continuous rounded rectangle used to clip all bubble content.
    static let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    /// The slightly larger shape used to wrap a reply + message composite.
    static let replyWrapperShape = RoundedRectangle(cornerRadius: 19, style: .continuous)

    /// Whether a filled background is drawn at all.
    ///
    /// False under ``MessageBubbleStyle/none``, where the fill is clear and
    /// the border, shadow and clipping that dress a bubble would outline
    /// nothing.
    let drawsBubble: Bool

    /// Whether this style uses white (light-on-dark) text.
    var usesWhiteText: Bool {
        // White text is used when the foreground style is white.
        // This is a convenience for callers that need a Bool (e.g. MessageTextView).
        _usesWhiteText
    }
    private let _usesWhiteText: Bool

    // MARK: - Standard Styles

    /// Returns the bubble style for a regular message (text, image, video, audio).
    static func message(
        for message: TimelineMessage,
        style: MessageBubbleStyle
    ) -> BubbleStyle {
        guard style.drawsBubble else {
            // Primary on a clear fill: the text sits on the conversation
            // ground, so it has to read against that rather than against a
            // bubble that is no longer there.
            return BubbleStyle(
                backgroundColor: .clear,
                foregroundStyle: AnyShapeStyle(.primary),
                drawsBubble: false,
                _usesWhiteText: false
            )
        }
        let colored = style.isSenderColored
        let usesWhite = message.isOutgoing || colored
        let background: Color
        if message.isOutgoing {
            background = colored
                ? Color(stableColorFor: message.senderID)
                : .accentColor
        } else if colored {
            background = Color(stableColorFor: message.senderID)
        } else {
            background = Color(.unemphasizedSelectedContentBackgroundColor)
        }
        return BubbleStyle(
            backgroundColor: background,
            foregroundStyle: AnyShapeStyle(usesWhite ? .white : .primary),
            drawsBubble: true,
            _usesWhiteText: usesWhite
        )
    }

    /// Returns the bubble style for a reply preview bubble.
    static func reply(
        senderID: String,
        outgoing: Bool,
        style: MessageBubbleStyle
    ) -> BubbleStyle {
        // A reply preview keeps a fill even under `none`: it is a quotation
        // inside a message, and without a fill there is nothing to show where
        // the quote ends and the reply begins.
        let colored = style.isSenderColored
        let usesWhite = (outgoing || colored) && style.drawsBubble
        let background: Color
        if !style.drawsBubble {
            background = Color(.systemGray).opacity(0.15)
        } else if colored {
            background = Color(stableColorFor: senderID)
        } else if outgoing {
            background = .accentColor
        } else {
            background = Color(.systemGray).opacity(0.2)
        }
        return BubbleStyle(
            backgroundColor: background,
            foregroundStyle: AnyShapeStyle(usesWhite ? .white : .primary),
            drawsBubble: true,
            _usesWhiteText: usesWhite
        )
    }

    /// The bubble style for emote messages (`/me` actions).
    /// Keeps its tint under every style: the colour is what marks it as an
    /// action rather than something someone said.
    static let emote = BubbleStyle(
        backgroundColor: Color.purple.opacity(0.1),
        foregroundStyle: AnyShapeStyle(.primary),
        drawsBubble: true,
        _usesWhiteText: false
    )

    /// Returns the bubble style for special message types (redacted, encrypted, etc.).
    static func special(kind: TimelineMessage.Kind) -> BubbleStyle {
        let background: Color = switch kind {
        case .redacted: Color(.systemGray).opacity(0.1)
        case .encrypted: Color.orange.opacity(0.1)
        default: Color(.systemGray).opacity(0.15)
        }
        let foreground: Color = switch kind {
        case .encrypted: .orange
        default: .primary
        }
        // Also keeps its fill: an undecryptable or deleted message is a state
        // the reader has to notice, and the tint is how it is announced.
        return BubbleStyle(
            backgroundColor: background,
            foregroundStyle: AnyShapeStyle(foreground.opacity(0.6)),
            drawsBubble: true,
            _usesWhiteText: false
        )
    }
}
