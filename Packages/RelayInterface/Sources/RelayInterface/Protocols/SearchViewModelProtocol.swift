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

/// The view model protocol for the sidebar search interface.
///
/// ``SearchViewModelProtocol`` defines the observable state and actions needed
/// to drive the sidebar search field and inline search results list. When
/// ``isActive`` is true the room list is replaced by search results showing
/// matching rooms and messages.
///
/// Concrete implementations include ``SearchViewModel`` (app layer) and
/// ``PreviewSearchViewModel`` (for SwiftUI previews).
@MainActor
public protocol SearchViewModelProtocol: AnyObject, Observable {
    /// The text content of the sidebar search field.
    var searchText: String { get set }

    /// Whether the search results list is visible (non-empty search text).
    var isActive: Bool { get }

    /// Message search results from the local index, as far as they have been
    /// loaded.
    var messageResults: [MessageSearchResult] { get set }

    /// Whether the index holds results beyond ``messageResults``.
    ///
    /// Results arrive in batches. Without this the list could only ever show
    /// the first one, however many matches existed.
    var hasMoreMessages: Bool { get set }

    /// Whether a message search request is currently in flight.
    var isSearchingMessages: Bool { get set }

    /// The room ID that was selected before the user started searching.
    /// Restored when the user dismisses search.
    var previousSelectedRoomId: String? { get set }

    /// Filters joined rooms by the current search text, respecting the
    /// active space filter.
    ///
    /// - Parameters:
    ///   - rooms: All joined rooms from the Matrix service.
    ///   - spaceId: The currently selected space, or `nil` for all rooms.
    /// - Returns: Rooms matching the search text by name or topic.
    func filteredRooms(from rooms: [RoomSummary], spaceId: String?) -> [RoomSummary]

    /// Clears all search state.
    func dismiss()
}
