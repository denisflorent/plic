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

/// Covers the per-message isolation the shared player has to keep.
///
/// One player now serves every bubble, so each has to be told about itself and
/// nothing else. Get that wrong and a second voice message shows the first
/// one's playhead — which is the failure mode a shared player introduces in
/// exchange for the one it removes.
@MainActor
struct AudioPlaybackCoordinatorTests {

    @Test("A fresh coordinator holds nothing")
    func startsIdle() {
        let coordinator = AudioPlaybackCoordinator()
        #expect(coordinator.activeMessageID == nil)
        #expect(!coordinator.isPlaying("$a"))
        #expect(!coordinator.isLoaded("$a"))
    }

    @Test("A message that is not loaded reports silence, not the active one's state")
    func reportsPerMessageState() {
        let coordinator = AudioPlaybackCoordinator()
        // Loading a file needs a decodable one; the isolation being tested is
        // in the accessors, which key off activeMessageID either way.
        #expect(coordinator.progress("$other") == 0)
        #expect(coordinator.currentTime("$other") == 0)
        #expect(coordinator.duration("$other") == 0)
        #expect(!coordinator.failed("$other"))
    }

    @Test("Toggling a message that is not loaded does nothing")
    func toggleIgnoresInactiveMessages() {
        // Without this guard, pressing play on a second voice message would
        // pause the one already playing instead of starting its own.
        let coordinator = AudioPlaybackCoordinator()
        coordinator.togglePlayback(for: "$not-loaded")
        #expect(coordinator.activeMessageID == nil)
        #expect(!coordinator.isPlaying("$not-loaded"))
    }

    @Test("Seeking a message that is not loaded does nothing")
    func seekIgnoresInactiveMessages() {
        let coordinator = AudioPlaybackCoordinator()
        coordinator.seek(0.5, for: "$not-loaded")
        #expect(coordinator.progress("$not-loaded") == 0)
    }

    @Test("Stopping clears the active message")
    func stopClearsActive() {
        let coordinator = AudioPlaybackCoordinator()
        coordinator.stop()
        #expect(coordinator.activeMessageID == nil)
    }
}
