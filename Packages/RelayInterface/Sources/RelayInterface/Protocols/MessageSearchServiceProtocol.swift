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

/// A service for performing server-side full-text message search.
///
/// Implementations query the Matrix homeserver's search endpoint and expose
/// paginated results as observable properties. Views program against this
/// protocol so the concrete implementation can be swapped (e.g. from a direct
/// HTTP implementation to an SDK-native one) without changing view code.
///
/// > Note: Server-side search does not include messages in encrypted rooms.
@MainActor
public protocol MessageSearchServiceProtocol: AnyObject, Observable {
    /// The current page of search results.
    var results: [MessageSearchResult] { get }

    /// Whether a search request is currently in flight.
    var isSearching: Bool { get }

    /// Whether additional pages of results are available.
    var hasMore: Bool { get }

    /// The approximate total number of matching results reported by the server.
    var totalCount: Int? { get }

    /// Performs a new search, replacing any existing results.
    ///
    /// - Parameters:
    ///   - term: The search query string.
    ///   - filter: Optional filter to narrow results by room or sender.
    func search(term: String, filter: MessageSearchFilter?) async throws

    /// Loads the next page of results for the most recent search.
    func loadMore() async throws

    /// Cancels any in-flight search request.
    func cancel()
}
