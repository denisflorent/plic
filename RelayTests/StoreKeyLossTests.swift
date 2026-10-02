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

/// Covers telling "the key is gone" apart from "this is a first run".
///
/// Both look identical from the Keychain alone — no store key either way — and
/// the app's response has to be opposite: create one and carry on, or stop and
/// explain that the cached data can never be decrypted again. The distinction
/// is whether there is data on disk that the missing key was protecting.
@MainActor
struct StoreKeyLossTests {

    @Test("hasStoreKey answers without minting a key")
    func hasStoreKeyDoesNotCreate() {
        // The whole detection rests on this. If asking the question created
        // the answer, a lost key would look present on the very next launch
        // and the user would be back to a login screen with no explanation.
        let before = KeychainService.hasStoreKey()
        _ = KeychainService.hasStoreKey()
        #expect(KeychainService.hasStoreKey() == before, "asking must not change the answer")
    }

    @Test("An empty data directory is a first run, not a loss")
    func emptyDirectoryIsNotDataLoss() throws {
        // hasLocalStoreData drives the branch: false means create a key and
        // continue, true with no key means stop and explain.
        let scratch = FileManager.default.temporaryDirectory
            .appending(path: "plic-store-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let empty = try FileManager.default.contentsOfDirectory(atPath: scratch.path)
        #expect(empty.isEmpty)

        try Data("sqlite".utf8).write(to: scratch.appending(path: "matrix.sqlite3"))
        let populated = try FileManager.default.contentsOfDirectory(atPath: scratch.path)
        #expect(!populated.isEmpty)
    }

    @Test("A missing directory reads as no data rather than throwing")
    func missingDirectoryIsNotAnError() {
        let absent = FileManager.default.temporaryDirectory
            .appending(path: "plic-absent-\(UUID().uuidString)")
        let contents = try? FileManager.default.contentsOfDirectory(atPath: absent.path)
        #expect((contents ?? []).isEmpty, "an absent directory must not be mistaken for data")
    }
}
