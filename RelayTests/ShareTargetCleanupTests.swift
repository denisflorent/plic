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

@testable import RelayKit

/// Pins that signing out leaves nothing of the account's rooms for the share
/// sheet or the share extension to offer.
@MainActor
struct ShareTargetCleanupTests {

    @MainActor
    private final class Recorder {
        var events: [String] = []
    }

    private let room = RelayInterface.RoomSummary(id: "!club:example.org", name: "Book Club")

    @Test("Sign-out deletes the room list and pending shares, and nothing else")
    func appGroupCleanup() throws {
        // Not the temporary directory: other suites watch it to prove that
        // decrypting media writes nothing to disk.
        let container = URL.applicationSupportDirectory.appending(path: "share-cleanup-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: container) }
        let pending = container.appending(path: PendingShareStore.pendingSharesDirectory)
        try FileManager.default.createDirectory(at: pending, withIntermediateDirectories: true)
        try Data("photo".utf8).write(to: pending.appending(path: "photo.jpg"))
        try Data("[]".utf8).write(to: container.appending(path: PendingShareStore.manifestFilename))
        try Data(#"[{"id":"!club:example.org","name":"Book Club","isDirect":false}]"#.utf8)
            .write(to: container.appending(path: PendingShareStore.roomCacheFilename))
        try Data("keep".utf8).write(to: container.appending(path: "unrelated.txt"))

        PendingShareStore.removeAll(in: container)

        let left = try FileManager.default.contentsOfDirectory(at: container, includingPropertiesForKeys: nil)
        #expect(left.map(\.lastPathComponent) == ["unrelated.txt"])
    }

    @Test("Sign-out waits for a donation in flight, then deletes every donation")
    func donationsDeletedAfterInFlightOnes() async {
        let recorder = Recorder()
        let service = IntentDonationService(
            donate: { _ in recorder.events.append("donate") },
            deleteAll: { recorder.events.append("deleteAll") }
        )

        // The second call falls inside the debounce window and donates nothing.
        service.donateIncomingMessage(roomSummary: room, senderName: "Alice")
        service.donateIncomingMessage(roomSummary: room, senderName: "Alice")
        // The donation has not run yet: deleting first would let it land
        // afterwards and bring the room back.
        await service.removeAllDonations()
        #expect(recorder.events == ["donate", "deleteAll"])

        // A new session starts with a clean debounce.
        service.donateIncomingMessage(roomSummary: room, senderName: "Alice")
        await service.removeAllDonations()
        #expect(recorder.events == ["donate", "deleteAll", "donate", "deleteAll"])
    }

    @Test("Turned off, suggestions are withdrawn and no new ones are made")
    func suggestionsCanBeTurnedOff() async {
        let recorder = Recorder()
        let service = IntentDonationService(
            donate: { _ in recorder.events.append("donate") },
            deleteAll: { recorder.events.append("deleteAll") }
        )

        await service.setEnabled(false)
        #expect(recorder.events == ["deleteAll"])

        service.donateOutgoingMessage(roomSummary: room)
        service.donateIncomingMessage(roomSummary: room, senderName: "Alice")
        await service.setEnabled(true)
        service.donateOutgoingMessage(roomSummary: room)
        // Flushes the donation in flight before reading the record.
        await service.removeAllDonations()
        #expect(recorder.events == ["deleteAll", "donate", "deleteAll"])
    }
}
