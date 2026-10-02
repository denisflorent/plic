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

/// Filter parameters for narrowing a server-side message search.
///
/// Wraps the filter fields accepted by the Matrix `POST /_matrix/client/v3/search`
/// endpoint. All filter fields are optional; `nil` values apply no restriction.
public struct MessageSearchFilter: Sendable, Hashable {
    /// Restrict results to specific rooms. `nil` searches all rooms.
    public let roomIds: [String]?

    /// Restrict results to specific senders. `nil` includes all senders.
    public let senderIds: [String]?

    /// How results should be ordered.
    public let orderBy: OrderBy

    /// The ordering strategy for message search results.
    public enum OrderBy: String, Sendable, Hashable {
        /// Order by relevance score (most relevant first).
        case rank
        /// Order by timestamp (most recent first).
        case recent
    }

    public nonisolated init(
        roomIds: [String]? = nil,
        senderIds: [String]? = nil,
        orderBy: OrderBy = .recent
    ) {
        self.roomIds = roomIds
        self.senderIds = senderIds
        self.orderBy = orderBy
    }
}
