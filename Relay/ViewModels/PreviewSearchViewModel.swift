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

/// A mock implementation of ``SearchViewModelProtocol`` for use in SwiftUI previews.
///
/// Returns static data. Filtering is a no-op; callers pre-configure
/// ``messageResults`` and ``isSearchingMessages`` before passing to views.
@Observable
final class PreviewSearchViewModel: SearchViewModelProtocol {
    var searchText = ""
    var isActive: Bool { !searchText.isEmpty }
    var messageResults: [MessageSearchResult] = []
    var hasMoreMessages = false
    var isSearchingMessages = false
    var previousSelectedRoomId: String?

    func filteredRooms(from rooms: [RoomSummary], spaceId: String?) -> [RoomSummary] {
        rooms.filter { !$0.isInvited }
    }

    func dismiss() {
        searchText = ""
        messageResults = []
        hasMoreMessages = false
        isSearchingMessages = false
    }
}
