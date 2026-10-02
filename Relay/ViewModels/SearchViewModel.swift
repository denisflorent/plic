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
import RelayInterface

/// Concrete implementation of ``SearchViewModelProtocol`` for the sidebar search.
///
/// Provides client-side room filtering and holds server-side message search
/// results. The view model is owned by ``MainView`` and passed to
/// ``SearchResultsList``.
@Observable
final class SearchViewModel: SearchViewModelProtocol {
    var searchText = ""

    var isActive: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

    var messageResults: [MessageSearchResult] = []

    var hasMoreMessages = false

    var isSearchingMessages = false

    var previousSelectedRoomId: String?

    func filteredRooms(from rooms: [RoomSummary], spaceId: String?) -> [RoomSummary] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return rooms.filter { room in
            guard !room.isInvited else { return false }
            if let spaceId {
                guard room.parentSpaceIds.contains(spaceId) else { return false }
            }
            return room.name.localizedStandardContains(query)
                || (room.topic?.localizedStandardContains(query) ?? false)
        }
    }

    func dismiss() {
        searchText = ""
        messageResults = []
        hasMoreMessages = false
        isSearchingMessages = false
    }
}
