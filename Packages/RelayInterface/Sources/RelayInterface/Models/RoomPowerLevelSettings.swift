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

/// The numeric power level thresholds configured for a room.
///
/// Each field represents the minimum power level required to perform the
/// corresponding action. Standard Matrix power levels are 0 (default user),
/// 50 (moderator), and 100 (administrator).
///
/// This type mirrors the SDK's `RoomPowerLevelsValues` without depending on
/// the SDK, keeping ``RelayInterface`` free of SDK imports.
public struct RoomPowerLevelSettings: Sendable, Equatable {
    /// The power level required to ban a user.
    public let ban: Int64

    /// The power level required to kick a user.
    public let kick: Int64

    /// The power level required to invite a user.
    public let invite: Int64

    /// The power level required to redact other users' messages.
    public let redact: Int64

    /// The default power level required to send message events.
    public let eventsDefault: Int64

    /// The default power level required to send state events.
    public let stateDefault: Int64

    /// The default power level assigned to new room members.
    public let usersDefault: Int64

    /// The power level required to change the room name.
    public let roomName: Int64

    /// The power level required to change the room topic.
    public let roomTopic: Int64

    /// The power level required to change the room avatar.
    public let roomAvatar: Int64

    /// Creates a new ``RoomPowerLevelSettings`` value.
    nonisolated public init(
        ban: Int64 = 50,
        kick: Int64 = 50,
        invite: Int64 = 0,
        redact: Int64 = 50,
        eventsDefault: Int64 = 0,
        stateDefault: Int64 = 50,
        usersDefault: Int64 = 0,
        roomName: Int64 = 50,
        roomTopic: Int64 = 50,
        roomAvatar: Int64 = 50
    ) {
        self.ban = ban
        self.kick = kick
        self.invite = invite
        self.redact = redact
        self.eventsDefault = eventsDefault
        self.stateDefault = stateDefault
        self.usersDefault = usersDefault
        self.roomName = roomName
        self.roomTopic = roomTopic
        self.roomAvatar = roomAvatar
    }
}
