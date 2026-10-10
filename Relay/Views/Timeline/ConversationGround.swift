// Copyright 2026 Denis Florent Media Group SRL
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

/// The surface the conversation sits on.
///
/// Two system colours composited rather than one hex value: `windowBackgroundColor`
/// is white in light mode, `underPageBackgroundColor` sits near 60% brightness,
/// and mixing them gives every shade between. Because both are system colours the
/// result inverts correctly in dark mode, which a grey tuned by eye in light mode
/// would not — it would need a second value, and both would drift the next time
/// macOS changes its palette.
struct ConversationGround: View {
    /// How much of the darker ground is mixed in, from ``Depth/range``.
    let depth: Double

    @AppStorage("appearance.mode") private var appearanceMode: AppAppearance = .system

    var body: some View {
        ZStack {
            if appearanceMode.usesGlass {
                // Under Liquid Glass the page cannot be opaque, or the glass
                // behind it disappears: a light black tint instead, scaled so
                // the standard depth lands on the shade a glass surface gets.
                Color.black.opacity(depth * Self.glassTintScale)
            } else {
                Color(nsColor: .windowBackgroundColor)
                Color(nsColor: .underPageBackgroundColor).opacity(depth)
            }
        }
    }

    /// Maps the depth range onto the tint a surface gets over glass, 0…0.27.
    static let glassTintScale = 0.45

    /// The stored setting behind ``ConversationGround``.
    enum Depth {
        /// The `@AppStorage` key. Shared so the Appearance tab and the timeline
        /// cannot drift onto different defaults.
        static let key = "appearance.conversationGroundDepth"

        /// Plain white reads as no ground at all: the compose bar is a
        /// translucent material, and over white it has no visible edge. This
        /// lands around 86% brightness — clearly a surface the bubbles rest on,
        /// without competing with them.
        static let standard = 0.35

        /// Zero is offered deliberately: it restores the white background this
        /// replaced, for anyone who preferred it. The top is short of the full
        /// darker ground, which is too heavy behind a page of text.
        static let range: ClosedRange<Double> = 0...0.6
    }

    /// The same setting for the compose field, stored separately.
    ///
    /// Two controls rather than one because they answer different questions.
    /// The conversation ground decides how far the page sits from the bubbles;
    /// this decides how far the field sits from the page. Tie them together and
    /// moving either one keeps their difference constant, which is the one
    /// thing the pair is for.
    enum FieldDepth {
        static let key = "appearance.composeFieldGroundDepth"

        /// Zero leaves the glass material untouched — the look this shipped
        /// with. Above it the tint takes over progressively, which is what a
        /// user reaches for when the translucent field disappears into
        /// whatever is behind it.
        static let standard = 0.0

        static let range: ClosedRange<Double> = 0...0.6
    }

    /// The shadow cast by the whole bottom bar — the message field and the
    /// buttons beside it together.
    ///
    /// A shade difference alone stops separating the bar from the page once
    /// someone picks a page shade close to it, and a shadow separates by depth
    /// instead, which does not depend on the two colours. Only the opacity is
    /// exposed: radius and offset that move with it produce a shadow that
    /// changes character rather than strength.
    enum BarShadow {
        static let key = "appearance.composeBarShadowOpacity"

        /// Subtle but present. The bar had no shadow at all, and a control
        /// that starts at zero looks broken until the first drag.
        static let standard = 0.15

        /// The top is deliberately short of anything heavy: this is a bar
        /// resting on a page, not a sheet floating over one.
        static let range: ClosedRange<Double> = 0...0.5

        /// Fixed alongside the opacity so one slider stays meaningful.
        static let radius: CGFloat = 8
        static let yOffset: CGFloat = 2
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach([0.0, 0.2, 0.35, 0.5, 0.6], id: \.self) { depth in
            ConversationGround(depth: depth)
                .frame(height: 44)
                .overlay(Text(depth, format: .number).font(.caption))
        }
    }
    .frame(width: 220)
}
