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

/// Pins which links reach `NSWorkspace` from message text written by others.
@MainActor
struct LinkPolicyTests {

    private func links(in text: NSAttributedString) -> [String] {
        var found: [String] = []
        text.enumerateAttribute(.link, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            if let value, let url = LinkPolicy.url(from: value) { found.append(url.absoluteString) }
        }
        return found
    }

    nonisolated static let dangerous = [
        "file:///System/Applications/Calculator.app",
        "smb://evil.example/share",
        "afp://evil.example",
        "vnc://evil.example",
        "ssh://evil.example",
        "shortcuts://run-shortcut?name=Anything",
        "applescript://com.apple.scripteditor?action=new&script=beep",
        "facetime://+33600000000",
    ]

    @Test("A dangerous URL in plain text stays plain text", arguments: dangerous)
    func plainTextIsNotLinked(url: String) {
        let text = NSAttributedString(matrixMarkdown: "have a look: \(url) thanks")
        #expect(links(in: text).isEmpty, "\(url) became clickable")
    }

    @Test("A Markdown link cannot hide a dangerous destination behind its text", arguments: dangerous)
    func markdownLinkIsStripped(url: String) {
        let text = NSAttributedString(matrixMarkdown: "look [at the photos](\(url))")
        #expect(links(in: text).isEmpty)
        #expect(text.string.contains("at the photos"), "the text must survive; only the link goes")
    }

    @Test("An HTML message cannot carry one either, tagged or bare", arguments: dangerous)
    func htmlIsFiltered(url: String) {
        let tagged = NSAttributedString(matrixHTML: "<a href=\"\(url)\">the photos</a>")
        let bare = NSAttributedString(matrixHTML: "<p>see \(url)</p>")
        #expect(tagged.map(links(in:))?.isEmpty ?? true)
        #expect(bare.map(links(in:))?.isEmpty ?? true)
    }

    @Test("Web and Matrix links still work")
    func ordinaryLinksSurvive() {
        let text = NSAttributedString(matrixMarkdown: "read https://example.com/page and ping @alice:example.org")
        let found = links(in: text)
        #expect(found.contains("https://example.com/page"))
        #expect(found.contains { $0.hasPrefix("https://matrix.to/") }, "Matrix identifiers must stay linked")
    }

    @Test("The click-time check refuses what rendering would have stripped")
    func openability() {
        for url in Self.dangerous {
            #expect(!LinkPolicy.isOpenable(URL(string: url)!), "\(url)")
        }
        #expect(LinkPolicy.isOpenable(URL(string: "https://example.com")!))
        #expect(LinkPolicy.isOpenable(URL(string: "matrix:u/alice:example.org")!))
        #expect(LinkPolicy.url(from: "https://example.com") != nil, "string-valued links are understood")
    }
}
