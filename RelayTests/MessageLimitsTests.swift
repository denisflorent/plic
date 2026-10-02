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
import Foundation
import Testing

@testable import Relay

/// Pins the bounds on what one received message can cost to display.
@MainActor
struct MessageLimitsTests {

    private func nested(_ open: String, _ close: String, depth: Int) -> String {
        String(repeating: open, count: depth) + "x" + String(repeating: close, count: depth)
    }

    @Test("Nesting is measured on container tags, and never goes negative")
    func measuresNesting() {
        #expect(MatrixMessageLimits.containerNesting(of: "<ul><li><b>a</b></li><li>b</li></ul>") == 2)
        #expect(MatrixMessageLimits.containerNesting(of: "</blockquote></blockquote><blockquote>a</blockquote>") == 1)
        #expect(MatrixMessageLimits.containerNesting(of: "<BLOCKQUOTE><Blockquote>a") == 2, "tag names are case-insensitive")
        #expect(MatrixMessageLimits.containerNesting(of: "a < b and c<d") == 0)
    }

    @Test("A message nested beyond the limit falls back to its plain body")
    func deepNestingIsRefused() {
        // 2,600 levels took 1.9 s to parse before the limit, on the main thread.
        let hostile = nested("<ul><li>", "</li></ul>", depth: 2_600)
        #expect(NSAttributedString(matrixHTML: hostile) == nil)
    }

    @Test("Real nesting, at the limit, still renders")
    func ordinaryNestingRenders() {
        let quotes = nested("<blockquote>", "</blockquote>", depth: MatrixMessageLimits.maximumContainerNesting)
        #expect(NSAttributedString(matrixHTML: quotes) != nil)
    }

    @Test("A body packed with Markdown markers is shown unstyled, text intact")
    func markerFloodIsNotParsed() {
        let flood = String(repeating: "*a", count: MatrixMessageLimits.maximumMarkdownMarkers + 1)
        let text = NSAttributedString(matrixMarkdown: flood)
        #expect(text.string == flood, "without Markdown, the stars stay as typed")
    }

    @Test("Ordinary Markdown is still styled")
    func ordinaryMarkdownIsStyled() {
        let text = NSAttributedString(matrixMarkdown: "this is **important**")
        #expect(text.string == "this is important")
    }
}
