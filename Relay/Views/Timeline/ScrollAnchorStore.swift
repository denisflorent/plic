// Copyright 2026 Link Dupont
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

import SwiftUI

/// A saved scroll position for a room's timeline, anchored to an event ID.
struct ScrollAnchor {
    /// The event ID of the message nearest the top of the visible area.
    let eventId: String
    /// Whether the user was scrolled near the bottom (live edge) when leaving.
    let isNearBottom: Bool
}

/// Caches scroll anchors per room so scroll position survives room switches.
///
/// When the user navigates away from a room, the ``TimelineView`` is destroyed
/// (due to its `.id(selectedRoomId)` modifier) and the `NSTableView` is torn
/// down, losing scroll position. ``ScrollAnchorStore`` saves the event ID of
/// the top-visible message so the timeline can scroll back to it when the user
/// returns.
///
/// The store lives for the app session. Anchors are not persisted across app
/// restarts — the `alwaysLoadNewest` preference and fully-read marker handle
/// cross-session scroll restoration.
@MainActor
final class ScrollAnchorStore {
    private var anchors: [String: ScrollAnchor] = [:]

    /// Saves a scroll anchor for a room.
    func save(roomId: String, anchor: ScrollAnchor) {
        anchors[roomId] = anchor
    }

    /// Returns and removes the saved scroll anchor for a room, if one exists.
    func take(roomId: String) -> ScrollAnchor? {
        anchors.removeValue(forKey: roomId)
    }
}

// MARK: - Environment Key

private struct ScrollAnchorStoreKey: EnvironmentKey {
    static let defaultValue = ScrollAnchorStore()
}

extension EnvironmentValues {
    /// The shared scroll anchor store used to preserve scroll position across room switches.
    var scrollAnchorStore: ScrollAnchorStore {
        get { self[ScrollAnchorStoreKey.self] }
        set { self[ScrollAnchorStoreKey.self] = newValue }
    }
}
