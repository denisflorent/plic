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

/// A mock implementation of ``MessageSearchServiceProtocol`` for use in SwiftUI previews.
///
/// Returns static sample search results. Search simulates a brief delay, and
/// pagination is a no-op.
@Observable
final class PreviewMessageSearchService: MessageSearchServiceProtocol {
    var results: [MessageSearchResult] = []
    var isSearching = false
    var hasMore = false
    var totalCount: Int?

    func search(term: String, filter: MessageSearchFilter?) async throws {
        isSearching = true
        try? await Task.sleep(for: .milliseconds(300))
        results = Self.sampleResults
        totalCount = results.count
        isSearching = false
    }

    func loadMore() async throws {}

    func cancel() {
        isSearching = false
    }

    /// Returns a service pre-populated with sample results for previews.
    static func preloaded() -> PreviewMessageSearchService {
        let service = PreviewMessageSearchService()
        service.results = sampleResults
        service.totalCount = sampleResults.count
        return service
    }

    /// Returns a service in the searching state for previews.
    static func searching() -> PreviewMessageSearchService {
        let service = PreviewMessageSearchService()
        service.isSearching = true
        return service
    }

    static let sampleResults: [MessageSearchResult] = [
        MessageSearchResult(
            eventId: "$evt1",
            roomId: "!swift:matrix.org",
            roomName: "Swift Developers",
            sender: "@alice:matrix.org",
            senderDisplayName: "Alice",
            body: "Has anyone tried the new concurrency features in Swift 6? The structured concurrency model is really impressive.",
            timestamp: Date(timeIntervalSinceNow: -3600),
            rank: 0.95,
            highlights: ["concurrency", "Swift"]
        ),
        MessageSearchResult(
            eventId: "$evt2",
            roomId: "!swift:matrix.org",
            roomName: "Swift Developers",
            sender: "@bob:matrix.org",
            senderDisplayName: "Bob",
            body: "Yes! The new task groups and async let bindings make concurrency much more approachable.",
            timestamp: Date(timeIntervalSinceNow: -3500),
            rank: 0.88,
            highlights: ["concurrency"]
        ),
        MessageSearchResult(
            eventId: "$evt3",
            roomId: "!design:matrix.org",
            roomName: "Design Team",
            sender: "@carol:matrix.org",
            senderDisplayName: "Carol",
            body: "I've been exploring how concurrency affects UI responsiveness in our app. The results are promising.",
            timestamp: Date(timeIntervalSinceNow: -86400),
            rank: 0.72,
            highlights: ["concurrency"]
        ),
        MessageSearchResult(
            eventId: "$evt4",
            roomId: "!rust:matrix.org",
            roomName: "Rust Programming",
            sender: "@dave:matrix.org",
            senderDisplayName: "Dave",
            body: "Rust's concurrency model with Send and Sync traits is quite different from Swift's approach.",
            timestamp: Date(timeIntervalSinceNow: -172800),
            rank: 0.65,
            highlights: ["concurrency", "Swift"]
        ),
    ]
}
