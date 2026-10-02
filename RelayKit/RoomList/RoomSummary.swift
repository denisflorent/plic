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

// RoomSummary.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A lightweight, `Identifiable` summary of a room for display in a list.
///
/// `RoomSummary` is a plain Swift struct built from the SDK's `RoomInfo`
/// and latest event data. It contains all the information needed to
/// render a room list row: name, avatar, unread counts, last message, etc.
///
/// ## Topics
///
/// ### Identity
/// - ``id``
/// - ``name``
/// - ``avatarURL``
///
/// ### State
/// - ``isDirect``
/// - ``isEncrypted``
/// - ``isFavourite``
/// - ``isLowPriority``
/// - ``membership``
///
/// ### Unread Counts
/// - ``notificationCount``
/// - ``highlightCount``
/// - ``unreadMessages``
struct RoomSummary: Identifiable, Sendable {
    /// The Matrix room ID.
    let id: String

    /// The computed display name of the room.
    let name: String?

    /// The room's avatar URL, if set.
    let avatarURL: URL?

    /// Whether this is a direct message room.
    let isDirect: Bool

    /// Whether end-to-end encryption is enabled.
    let isEncrypted: Bool

    /// Whether the user has marked this room as a favourite.
    let isFavourite: Bool

    /// Whether the user has marked this room as low priority.
    let isLowPriority: Bool

    /// Whether this room is a Matrix space.
    let isSpace: Bool

    /// The user's current membership state.
    let membership: Membership

    /// The number of unread notification events.
    let notificationCount: UInt64

    /// The number of highlighted (mentioned) unread events.
    let highlightCount: UInt64

    /// The number of unread messages.
    let unreadMessages: UInt64

    /// The room's heroes (used for display name/avatar computation).
    let heroes: [RoomHero]

    /// The room's join rule.
    let joinRule: JoinRule?

    /// The room's canonical alias, if set.
    let canonicalAlias: String?

    /// Whether the room has an active call.
    let hasRoomCall: Bool

    /// The number of active (joined + invited) members.
    let activeMembersCount: UInt64

    /// The IDs of pinned events in this room.
    let pinnedEventIDs: [String]

    /// Creates a room summary from a `RoomInfo`.
    ///
    /// - Parameter roomInfo: The SDK room info record.
    public init(roomInfo: RoomInfo) {
        self.id = roomInfo.id
        self.name = roomInfo.displayName
        self.avatarURL = roomInfo.avatarUrl.matrixURL
        self.isDirect = roomInfo.isDirect
        self.isEncrypted = roomInfo.encryptionState != .notEncrypted
        self.isFavourite = roomInfo.isFavourite
        self.isLowPriority = roomInfo.isLowPriority
        self.isSpace = roomInfo.isSpace
        self.membership = roomInfo.membership
        self.notificationCount = roomInfo.notificationCount
        self.highlightCount = roomInfo.highlightCount
        self.unreadMessages = roomInfo.numUnreadMessages
        self.heroes = roomInfo.heroes
        self.joinRule = roomInfo.joinRule
        self.canonicalAlias = roomInfo.canonicalAlias
        self.hasRoomCall = roomInfo.hasRoomCall
        self.activeMembersCount = roomInfo.activeMembersCount
        self.pinnedEventIDs = roomInfo.pinnedEventIds
    }
}
