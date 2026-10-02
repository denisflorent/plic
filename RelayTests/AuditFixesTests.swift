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
@testable import RelayKit

/// Pins the fixes from the September 2026 code audit that can be exercised
/// without a homeserver.
@MainActor
struct AuditFixesTests {

    // MARK: - Drafts do not outlive the session

    @Test("A sign-out discards every draft")
    func draftsAreDiscarded() {
        let store = ComposeDraftStore()
        let before = store.draft(for: "!room:example.org")
        #expect(store.draft(for: "!room:example.org") === before, "a draft must persist across room switches")

        store.removeAll()

        // Room IDs are global in Matrix: a draft kept here would reappear for
        // the next account to open the same room.
        #expect(store.draft(for: "!room:example.org") !== before)
    }

    // MARK: - Search pagination state

    @Test("Dismissing search forgets that more results were pending")
    func dismissClearsPagination() {
        let model = SearchViewModel()
        model.searchText = "cahiers"
        model.hasMoreMessages = true

        model.dismiss()

        // Left set, the next search would offer "Load More Results" before its
        // first batch had even arrived.
        #expect(model.hasMoreMessages == false)
    }

    // MARK: - Decrypted media never lingers on disk

    @Test("The plaintext media cache from earlier builds is removed")
    func legacyPlaintextCacheIsPurged() throws {
        #if DEBUG
        let legacyName = "Relay/media-cache-debug"
        #else
        let legacyName = "Relay/media-cache"
        #endif
        let legacy = URL.cachesDirectory.appending(path: legacyName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data("\u{89}PNG".utf8).write(to: legacy.appending(path: "decrypted-image"))

        _ = MediaService()

        // That directory held message media, decrypted, in the clear. It goes
        // the first time the service starts, not when someone next signs out.
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }
}
