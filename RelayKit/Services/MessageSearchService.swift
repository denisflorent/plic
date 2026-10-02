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
import os
import RelayInterface

private let logger = Logger(subsystem: "im.plic", category: "MessageSearch")

/// Full-text message search over the SDK's local store of decrypted events.
///
/// This previously called `POST /_matrix/client/v3/search` directly. That
/// endpoint cannot work for an encrypted room: the homeserver holds only
/// ciphertext, so there is no plaintext body to index, and every search came
/// back empty. It is the same reason Element X ships no message search and
/// Element Web needs Seshat, a separate local index.
///
/// The Rust SDK now searches its own store, which holds events *after*
/// decryption — so encrypted rooms are searchable, and no second index has to
/// be built or kept in sync.
///
/// The trade is coverage: only what this Mac has synced can be found. Messages
/// older than the local history are invisible here, where a server-side search
/// would have seen them — but only in unencrypted rooms, where it saw anything
/// at all.
@Observable
final class MessageSearchService: MessageSearchServiceProtocol {
    private(set) var results: [MessageSearchResult] = []
    private(set) var isSearching = false
    private(set) var hasMore = false

    /// Always `nil`.
    ///
    /// The iterator reports no total — it cannot know one without walking the
    /// whole store — and a guess would be worse than admitting that.
    private(set) var totalCount: Int?

    private let client: ClientProxyProtocol
    private var iterator: GlobalSearchIterator?

    /// Results per batch. Enough to fill the sidebar without walking the store
    /// further than the user is likely to scroll.
    private static let batchSize: UInt32 = 30

    init(client: ClientProxyProtocol) {
        self.client = client
    }

    // MARK: - MessageSearchServiceProtocol

    func search(term: String, filter: MessageSearchFilter?) async throws {
        cancel()

        let query = Self.normalized(term)
        guard !query.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }

        let batch = try await withPresentableFailure {
            let iterator = try await client.searchMessages(
                query: query,
                filter: Self.roomFilter(from: filter),
                batchSize: Self.batchSize
            )
            self.iterator = iterator
            return try await iterator.nextEvents()
        }
        guard !Task.isCancelled else { return }

        results = (batch ?? []).compactMap(Self.searchResult(from:))
        // A non-nil batch means the iterator has not reached the end, even if
        // every event in it mapped to nothing displayable.
        hasMore = batch != nil

        // Counts only. The search term is what the user is looking for in their
        // own messages, and the unified log is readable by anyone with access to
        // the machine — putting it there would leak exactly what the app exists
        // to protect.
        let raw: Int = batch?.count ?? -1
        let mapped: Int = results.count
        logger.debug("Search returned rawBatch=\(raw) mapped=\(mapped)")
    }

    public func loadMore() async throws {
        guard let iterator, hasMore, !isSearching else { return }

        isSearching = true
        defer { isSearching = false }

        let batch = try await withPresentableFailure { try await iterator.nextEvents() }
        guard !Task.isCancelled else { return }

        guard let batch else {
            hasMore = false
            return
        }
        results.append(contentsOf: batch.compactMap(Self.searchResult(from:)))
    }

    /// Runs an SDK call, replacing whatever it throws with ``presentable(_:)``.
    private func withPresentableFailure<T>(_ work: () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch {
            throw Self.presentable(error)
        }
    }

    /// Turns an SDK search failure into something worth putting on screen.
    ///
    /// What the SDK throws is a Rust debug dump. The one behind this method
    /// reached the user as a full filesystem path plus the words "invalid MAC
    /// of the store key" — which explains nothing to the person searching, and
    /// explains where the index lives to anyone reading over their shoulder.
    private static func presentable(_ error: Error) -> Error {
        // Cancellation is not a failure: every keystroke supersedes the last
        // request, and the caller distinguishes the two by type.
        if error is CancellationError { return error }

        let description = String(describing: error)
        guard description.contains("IndexError") || description.contains("store key") else {
            logger.error("Search failed: \(description, privacy: .private)")
            return RelayError.searchFailed("Message search could not be completed.")
        }

        // The client holds the index open, so it cannot be replaced now.
        // Dropping the stamp makes the next launch rebuild it, which is what
        // the sentence below promises.
        AuthenticationService.invalidateSearchIndexStamp()
        logger.error("Search index unreadable; scheduled for rebuild on next launch")
        return RelayError.searchFailed(
            "The message index could not be opened. Plic will rebuild it the next time it starts, "
            + "and search will work again after that."
        )
    }

    func cancel() {
        isSearching = false
        results = []
        hasMore = false
        totalCount = nil
        // Dropping the iterator releases the SDK-side cursor.
        iterator = nil
    }

    // MARK: - Mapping

    /// Cleans up a query before it reaches the index.
    ///
    /// Signal normalises both sides — it strips punctuation and control
    /// characters from the indexed text and from the query, then wraps each
    /// token for prefix matching. We cannot follow it all the way: the SDK
    /// builds the index internally and documents neither its tokenizer nor its
    /// query syntax, so anything applied here is applied to one side only.
    ///
    /// What is left is the subset that cannot hurt:
    ///
    /// - **Canonical Unicode (NFC).** macOS dead keys produce decomposed
    ///   accents — `é` as `e` plus a combining mark — while text arriving over
    ///   the wire is composed. Without this, searching for `café` typed with a
    ///   dead key would never match the `café` in a message.
    /// - **Whitespace.** Trimmed at the ends and collapsed in the middle;
    ///   repeated spaces in a query are never intentional.
    ///
    /// Deliberately not done: stripping punctuation, which would break exact
    /// matches if the index keeps it, and appending `*` for prefix matching,
    /// which the SDK may take literally rather than as an operator. Both need
    /// the SDK to say what it does before they are safe.
    private static func normalized(_ term: String) -> String {
        term
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .precomposedStringWithCanonicalMapping
    }

    private static func roomFilter(from filter: MessageSearchFilter?) -> SearchRoomFilter {
        // The SDK filters by room category, not by explicit room IDs, so a
        // filter naming specific rooms cannot be expressed. Searching every
        // joined room and letting the caller narrow the results stays closer to
        // the intent than refusing the search.
        .rooms
    }

    private static func searchResult(from result: GlobalSearchResult) -> MessageSearchResult? {
        let event = result.result
        guard let body = body(from: event.content) else { return nil }

        var displayName: String?
        var avatarURL: String?
        if case .ready(let name, _, let avatar) = event.senderProfile {
            displayName = name
            avatarURL = avatar
        }

        return MessageSearchResult(
            eventId: event.eventId,
            roomId: result.roomId,
            roomName: nil,
            sender: event.sender,
            senderDisplayName: displayName,
            senderAvatarURL: avatarURL,
            body: body,
            // The SDK reports milliseconds since the epoch.
            timestamp: Date(timeIntervalSince1970: Double(event.timestamp) / 1000),
            rank: nil,
            highlights: []
        )
    }

    /// The displayable text of a matching event, or `nil` for events with none.
    ///
    /// Media captions count: a photo sent with a caption should be findable by
    /// that caption, which is what someone looking for it would expect.
    private static func body(from content: TimelineItemContent) -> String? {
        guard case .msgLike(let msgLike) = content,
              case .message(let message) = msgLike.kind
        else { return nil }

        switch message.msgType {
        case .text(let content):
            return content.body
        case .emote(let content):
            return content.body
        case .notice(let content):
            return content.body
        case .image(let content):
            return content.caption
        case .video(let content):
            return content.caption
        case .audio(let content):
            return content.caption
        case .file(let content):
            return content.caption
        default:
            return nil
        }
    }
}
