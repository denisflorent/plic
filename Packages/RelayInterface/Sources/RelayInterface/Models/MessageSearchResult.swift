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

import Foundation

/// A single result from a server-side message search.
///
/// Each result represents a matching event returned by the Matrix
/// `POST /_matrix/client/v3/search` endpoint. Encrypted rooms are
/// excluded from server-side search by the homeserver.
public struct MessageSearchResult: Identifiable, Sendable, Hashable {
    public var id: String { eventId }

    /// The Matrix event ID of the matching message.
    public let eventId: String

    /// The room in which the event was sent.
    public let roomId: String

    /// The display name of the room, if known.
    public let roomName: String?

    /// The fully-qualified Matrix user ID of the sender.
    public let sender: String

    /// The display name of the sender at the time of the event, if available.
    public let senderDisplayName: String?

    /// The `mxc://` avatar URL of the sender, if available from the event context.
    public let senderAvatarURL: String?

    /// The textual body of the matching message.
    public let body: String

    /// The timestamp when the event was sent.
    public let timestamp: Date

    /// The relevance score assigned by the homeserver (higher is more relevant).
    public let rank: Double?

    /// Words the homeserver recommends highlighting in the result.
    ///
    /// These may differ from the original search term due to stemming.
    public let highlights: [String]

    public nonisolated init(
        eventId: String,
        roomId: String,
        roomName: String? = nil,
        sender: String,
        senderDisplayName: String? = nil,
        senderAvatarURL: String? = nil,
        body: String,
        timestamp: Date,
        rank: Double? = nil,
        highlights: [String] = []
    ) {
        self.eventId = eventId
        self.roomId = roomId
        self.roomName = roomName
        self.sender = sender
        self.senderDisplayName = senderDisplayName
        self.senderAvatarURL = senderAvatarURL
        self.body = body
        self.timestamp = timestamp
        self.rank = rank
        self.highlights = highlights
    }
}
