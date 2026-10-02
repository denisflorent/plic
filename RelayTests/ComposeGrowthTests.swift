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

import AppKit
import Testing

@testable import Relay

/// Covers the compose field growing with wrapped text.
///
/// The field should rise line by line as a message outgrows one line and stop
/// at five, the way every messaging app behaves. Every piece of that is
/// present — a height callback, a frame bound to it, `widthTracksTextView` —
/// so if it does not grow the fault is in the measurement, which is what these
/// exercise directly.
@MainActor
struct ComposeGrowthTests {

    /// A text view configured the way `ComposeTextView.makeNSView` configures
    /// one, laid out at a realistic sidebar-adjacent width.
    private func makeField(width: CGFloat = 320) -> ComposeInputTextView {
        let view = ComposeInputTextView(frame: NSRect(x: 0, y: 0, width: width, height: 22))
        view.textContainer?.lineFragmentPadding = 4
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.size = NSSize(width: width, height: .greatestFiniteMagnitude)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.textContainerInset = NSSize(width: 8, height: 10)
        view.font = MessageTextScale.baseFont
        return view
    }

    private func height(of text: String, width: CGFloat = 320) -> CGFloat {
        let view = makeField(width: width)
        view.string = text
        view.recalculateHeight()
        return view.cachedHeight
    }

    @Test("A short message stays one line tall")
    func shortTextIsOneLine() {
        let single = height(of: "Ceci est un test de texte court")
        let empty = height(of: "")
        #expect(single == empty, "text that fits on one line must not change the height")
    }

    @Test("Text that wraps makes the field taller")
    func wrappedTextGrows() {
        let single = height(of: "Ceci est un test")
        let wrapped = height(
            of: "Ceci est un test de texte de message long qui a besoin de plusieurs lignes."
        )
        #expect(
            wrapped > single,
            """
            The compose field did not grow for text that must wrap \
            (\(wrapped) vs \(single) points at 320pt wide).
            """
        )
    }

    @Test("Each extra line adds height")
    func growthIsProgressive() {
        let two = height(of: String(repeating: "mot ", count: 12))
        let four = height(of: String(repeating: "mot ", count: 30))
        #expect(four > two, "a longer message must be taller than a shorter wrapped one")
    }

    @Test("Growth stops at the line cap")
    func growthIsCapped() {
        // Past the cap the field scrolls instead of pushing the timeline off
        // the top of the window.
        let long = height(of: String(repeating: "mot ", count: 400))
        let veryLong = height(of: String(repeating: "mot ", count: 4000))
        #expect(long == veryLong, "height must stop rising once the cap is reached")

        let lineHeight = MessageTextScale.baseFont.pointSize * 1.2
        let cap = lineHeight * ComposeInputTextView.maximumVisibleLines + 20
        #expect(abs(long - cap) < 1, "expected the cap plus insets, got \(long)")
    }

    @Test("An explicit newline grows the field too")
    func newlinesGrow() {
        let one = height(of: "une ligne")
        let three = height(of: "une ligne\ndeux lignes\ntrois lignes")
        #expect(three > one)
    }
}
