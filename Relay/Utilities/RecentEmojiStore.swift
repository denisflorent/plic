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
import SwiftUI

/// Tracks recently and frequently used emoji for the reaction picker.
///
/// Persists up to 10 entries in `UserDefaults` as JSON. Entries are sorted
/// by usage count (descending), with recency as a tiebreaker. When the store
/// is empty, a sensible default set is returned.
@Observable
final class RecentEmojiStore {
    /// Shared singleton instance.
    static let shared = RecentEmojiStore()

    /// The maximum number of emoji to persist and display.
    private static let maxEntries = 8

    /// Default emoji seeded on first launch before the user has any history.
    private static let defaults = ["👍", "👎", "❤️", "🤣"]

    private static let storageKey = "recentEmoji"

    /// The sorted list of recent emoji, ready for display.
    private(set) var recentEmoji: [String] = []

    private var entries: [Entry] = [] {
        didSet { recentEmoji = entries.map(\.emoji) }
    }

    private init() {
        loadFromDisk()
    }

    /// Records a usage of the given emoji, creating or updating its entry.
    func recordUsage(_ emoji: String) {
        if let index = entries.firstIndex(where: { $0.emoji == emoji }) {
            entries[index].usageCount += 1
            entries[index].lastUsed = .now
        } else {
            entries.append(Entry(emoji: emoji, usageCount: 1, lastUsed: .now))
        }
        // Sort: highest usage first, most recent as tiebreaker.
        entries.sort { lhs, rhs in
            if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
            return lhs.lastUsed > rhs.lastUsed
        }
        // Evict least-used entries beyond the cap.
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
        saveToDisk()
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data)
        else {
            seedDefaults()
            return
        }
        entries = decoded
    }

    /// Seeds the store with the default emoji set so the picker is fully
    /// populated on first launch. All defaults start with a usage count of
    /// zero so any actual usage immediately sorts above them.
    private func seedDefaults() {
        let now = Date.now
        entries = Self.defaults.enumerated().map { index, emoji in
            // Stagger lastUsed slightly so the default order is preserved
            // when all counts are equal.
            Entry(emoji: emoji, usageCount: 0, lastUsed: now.addingTimeInterval(Double(-index)))
        }
        saveToDisk()
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    // MARK: - Entry Model

    private struct Entry: Codable {
        let emoji: String
        var usageCount: Int
        var lastUsed: Date
    }
}

// MARK: - Environment Key

private struct RecentEmojiStoreKey: EnvironmentKey {
    @MainActor static let defaultValue = RecentEmojiStore.shared
}

extension EnvironmentValues {
    /// The shared recent emoji store for the reaction picker.
    var recentEmojiStore: RecentEmojiStore {
        get { self[RecentEmojiStoreKey.self] }
        set { self[RecentEmojiStoreKey.self] = newValue }
    }
}
