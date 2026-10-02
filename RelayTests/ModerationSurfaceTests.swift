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
import RelayInterface
import Testing

@testable import Relay

/// Pins down when the report action is offered.
///
/// The reporting path exists for App Store guideline 1.2 as much as for its own
/// sake, so its disappearance from the context menu would be a compliance
/// regression that no build step notices. The rules are pure logic in
/// `TimelineMessageContextMenu.entries`, which makes them cheap to hold here.
struct ModerationSurfaceTests {

    private func message(
        eventID: String = "$evt:example.org",
        isOutgoing: Bool = false,
        kind: TimelineMessage.Kind = .text
    ) -> TimelineMessage {
        TimelineMessage(
            id: eventID,
            eventID: eventID,
            senderID: "@costina:example.org",
            body: "hello",
            timestamp: Date(timeIntervalSince1970: 1_760_000_000),
            isOutgoing: isOutgoing,
            kind: kind
        )
    }

    @Test("An incoming message can be reported")
    func incomingIsReportable() {
        let entries = TimelineMessageContextMenu.entries(for: message())
        #expect(entries.contains(.report))
    }

    @Test("Your own message cannot be reported")
    func outgoingIsNotReportable() {
        let entries = TimelineMessageContextMenu.entries(for: message(isOutgoing: true))
        #expect(!entries.contains(.report))
    }

    @Test("A redacted message cannot be reported")
    func redactedIsNotReportable() {
        let entries = TimelineMessageContextMenu.entries(for: message(kind: .redacted))
        #expect(!entries.contains(.report))
    }

    @Test("A local echo cannot be reported")
    func localEchoIsNotReportable() {
        // Before the server confirms an event it has a transaction ID, not a
        // "$"-prefixed event ID, and there is nothing on the server to report.
        let entries = TimelineMessageContextMenu.entries(for: message(eventID: "txn-123"))
        #expect(!entries.contains(.report))
    }
}
