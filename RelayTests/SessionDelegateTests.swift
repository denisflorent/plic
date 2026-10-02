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
import os
import Testing

@testable import RelayKit

/// Pins that a superseded client can no longer write tokens.
///
/// Uses a probe instead of the Keychain: a test writing the live session is
/// how a test run once signed its developer out.
@MainActor
struct SessionDelegateTests {

    private let session = Session(
        accessToken: "access", refreshToken: "refresh", userId: "@me:example.org",
        deviceId: "DEVICE", homeserverUrl: "https://example.org", oauthData: nil,
        slidingSyncVersion: .native
    )

    @Test("A refresh from a live client is saved")
    func liveClientSaves() {
        let writes = OSAllocatedUnfairLock(initialState: 0)
        let delegate = KeychainSessionDelegate(write: { _ in writes.withLock { $0 += 1 } })

        delegate.saveSessionInKeychain(session: session)

        #expect(writes.withLock { $0 } == 1)
    }

    @Test("After invalidation, a stale client's refresh never reaches the Keychain")
    func invalidatedClientWritesNothing() {
        let writes = OSAllocatedUnfairLock(initialState: 0)
        let delegate = KeychainSessionDelegate(write: { _ in writes.withLock { $0 += 1 } })

        delegate.invalidate()
        delegate.saveSessionInKeychain(session: session)

        // Written after the new session's, these tokens would be revoked ones,
        // and the next launch would find itself signed out.
        #expect(writes.withLock { $0 } == 0)
        #expect(throws: (any Error).self) { try delegate.retrieveSessionFromKeychain(userId: "@me:example.org") }
    }

    @Test("Concurrent refreshes and an invalidation never write after it returns")
    func noWriteAfterInvalidate() async {
        let state = OSAllocatedUnfairLock(initialState: (invalidated: false, lateWrites: 0))
        let delegate = KeychainSessionDelegate(write: { _ in
            state.withLock { if $0.invalidated { $0.lateWrites += 1 } }
        })
        let session = self.session

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<200 {
                group.addTask { delegate.saveSessionInKeychain(session: session) }
            }
            group.addTask { @MainActor in
                delegate.invalidate()
                state.withLock { $0.invalidated = true }
            }
        }

        #expect(state.withLock { $0.lateWrites } == 0)
    }
}
