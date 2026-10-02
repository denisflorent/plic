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

import Foundation
import Testing

@testable import Relay

/// Pins what each notification setting lets out of Plic.
@MainActor
struct NotificationPreviewTests {

    private func banner(_ preview: NotificationPreview, isDirect: Bool = false) -> (title: String, body: String) {
        preview.banner(roomName: "Book Club", author: "Alice", message: "the secret", isDirect: isDirect)
    }

    @Test("Name and message: everything, as before the setting existed")
    func nameAndMessage() {
        #expect(banner(.nameAndMessage) == ("Alice in Book Club", "the secret"))
        #expect(banner(.nameAndMessage, isDirect: true) == ("Book Club", "the secret"))
        #expect(NotificationPreview.standard == .nameAndMessage)
    }

    @Test("Name only: who wrote, never what")
    func nameOnly() {
        let shown = banner(.nameOnly)
        #expect(shown.title == "Alice in Book Club")
        #expect(!shown.body.contains("secret"))
    }

    @Test("Nothing: neither who nor what")
    func nothing() {
        let shown = banner(.nothing)
        #expect(!"\(shown.title) \(shown.body)".contains("Alice"))
        #expect(!"\(shown.title) \(shown.body)".contains("Book Club"))
        #expect(!"\(shown.title) \(shown.body)".contains("secret"))
    }
}
