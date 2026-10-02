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

@testable import RelayKit

/// Covers the binding between the search index and the key that encrypted it.
///
/// Without it the index outlives its key silently, and the SDK reports the
/// mismatch as `IndexError("… invalid MAC of the store key …")` — per room, on
/// every search, for good. That happened on a real install: nine of eleven room
/// indexes were written under a store key that a later launch had replaced.
///
/// Every test works in a temporary directory. The live index must never be
/// reachable from here — deleting it is precisely what this code does.
@MainActor
struct SearchIndexStampTests {

    private struct Scratch {
        let root: URL
        var index: URL { root.appending(path: "search-index") }
        var stamp: URL { root.appending(path: "search-index.keycheck") }

        init() {
            root = URL.temporaryDirectory.appending(path: "plic-index-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: index, withIntermediateDirectories: true)
        }

        /// Writes something where a room's index would be.
        func seedIndex(room: String = "!room:example.org") {
            let directory = index.appending(path: room)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? Data("seshat".utf8).write(to: directory.appending(path: "seshat-index.key"))
        }

        var indexContents: [String] {
            (try? FileManager.default.contentsOfDirectory(atPath: index.path)) ?? []
        }

        func cleanUp() {
            try? FileManager.default.removeItem(at: root)
        }
    }

    @Test("A fresh index is stamped, not discarded")
    func firstRunStamps() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }

        let discarded = AuthenticationService.reconcileSearchIndex(
            directory: scratch.index, stamp: scratch.stamp, password: "key-one"
        )

        #expect(discarded == false, "there was nothing to discard on a first run")
        #expect(FileManager.default.fileExists(atPath: scratch.stamp.path))
        #expect(FileManager.default.fileExists(atPath: scratch.index.path))
    }

    @Test("The same key leaves the index alone")
    func matchingKeyIsANoOp() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }

        AuthenticationService.reconcileSearchIndex(
            directory: scratch.index, stamp: scratch.stamp, password: "key-one"
        )
        scratch.seedIndex()

        let discarded = AuthenticationService.reconcileSearchIndex(
            directory: scratch.index, stamp: scratch.stamp, password: "key-one"
        )

        // Every launch calls this. Discarding here would rebuild the index
        // daily and make message search permanently thin.
        #expect(discarded == false)
        #expect(scratch.indexContents.count == 1)
    }

    @Test("A changed key discards the index it can no longer open")
    func changedKeyDiscards() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }

        AuthenticationService.reconcileSearchIndex(
            directory: scratch.index, stamp: scratch.stamp, password: "key-one"
        )
        scratch.seedIndex()

        let discarded = AuthenticationService.reconcileSearchIndex(
            directory: scratch.index, stamp: scratch.stamp, password: "key-two"
        )

        #expect(discarded == true)
        #expect(scratch.indexContents.isEmpty, "the stale index must be gone, not merely ignored")
        #expect(FileManager.default.fileExists(atPath: scratch.index.path), "the directory itself must survive for the SDK to open")
    }

    @Test("An index from before this check existed is discarded once")
    func unstampedIndexIsDiscarded() {
        // The shipped state: an index on disk, no record of which key wrote it.
        // It may be readable, but nothing says so, and the machine that
        // produced this bug proves the other case happens.
        let scratch = Scratch()
        defer { scratch.cleanUp() }
        scratch.seedIndex()

        let first = AuthenticationService.reconcileSearchIndex(
            directory: scratch.index, stamp: scratch.stamp, password: "key-one"
        )
        let second = AuthenticationService.reconcileSearchIndex(
            directory: scratch.index, stamp: scratch.stamp, password: "key-one"
        )

        #expect(first == true)
        #expect(second == false, "the rebuild happens once, not on every launch")
    }

    @Test("Dropping the stamp schedules a rebuild")
    func invalidationForcesTheNextRunToDiscard() {
        // What a mid-search `IndexError` triggers: the index cannot be replaced
        // under an open client, so the repair is deferred by one launch.
        let scratch = Scratch()
        defer { scratch.cleanUp() }

        AuthenticationService.reconcileSearchIndex(
            directory: scratch.index, stamp: scratch.stamp, password: "key-one"
        )
        scratch.seedIndex()
        try? FileManager.default.removeItem(at: scratch.stamp)

        let discarded = AuthenticationService.reconcileSearchIndex(
            directory: scratch.index, stamp: scratch.stamp, password: "key-one"
        )

        #expect(discarded == true)
    }

    @Test("The stamp holds a digest, never the key")
    func stampIsNotTheKey() {
        let scratch = Scratch()
        defer { scratch.cleanUp() }
        let password = "a-store-key-in-base64=="

        AuthenticationService.reconcileSearchIndex(
            directory: scratch.index, stamp: scratch.stamp, password: password
        )
        let written = (try? String(contentsOf: scratch.stamp, encoding: .utf8)) ?? ""

        // The file sits unprotected beside the index. It answers one question —
        // same key or not — and must give away nothing else.
        let isHex = written.allSatisfy(\.isHexDigit)
        #expect(written.range(of: password) == nil)
        #expect(written.count == 64, "expected a SHA-256 hex digest, got \(written.count) characters")
        #expect(isHex)
    }

    @Test("Different keys produce different stamps")
    func fingerprintsDiffer() {
        let one = Scratch()
        let two = Scratch()
        defer { one.cleanUp(); two.cleanUp() }

        AuthenticationService.reconcileSearchIndex(directory: one.index, stamp: one.stamp, password: "key-one")
        AuthenticationService.reconcileSearchIndex(directory: two.index, stamp: two.stamp, password: "key-two")

        let first = try? String(contentsOf: one.stamp, encoding: .utf8)
        let second = try? String(contentsOf: two.stamp, encoding: .utf8)
        #expect(first != second)
    }
}
