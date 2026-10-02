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

// RoomDirectorySearchProxy.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0

import Foundation
import Observation

/// A proxy that wraps the Matrix SDK `RoomDirectorySearch`.
///
/// Provides paginated search of the homeserver's public room directory
/// with observable results updated via SDK listener callbacks.
///
/// Call ``startListening()`` after initialization to begin receiving
/// results updates from the SDK. Use ``waitForNextUpdate(after:)`` to
/// suspend until the SDK delivers the next batch of results.
@Observable
final class RoomDirectorySearchProxy: RoomDirectorySearchProxyProtocol, @unchecked Sendable {
    private let search: RoomDirectorySearch
    @ObservationIgnored nonisolated(unsafe) private var resultsHandle: TaskHandle?
    private let lock = NSLock()
    @ObservationIgnored nonisolated(unsafe) private var _storage: [RoomDescription] = []

    /// Monotonically increasing counter bumped on every non-empty listener delivery.
    @ObservationIgnored nonisolated(unsafe) private var _updateCounter: UInt64 = 0

    /// A pending continuation installed by ``waitForNextUpdate(after:)``.
    /// The listener resumes it when ``_updateCounter`` advances past the
    /// caller's recorded value.
    @ObservationIgnored nonisolated(unsafe) private var pendingContinuation: CheckedContinuation<[RoomDescription], Never>?
    @ObservationIgnored nonisolated(unsafe) private var pendingAfterCounter: UInt64 = 0

    /// The current list of room descriptions from the search.
    private(set) var results: [RoomDescription] = []

    /// Creates a room directory search proxy.
    ///
    /// - Parameter search: The SDK room directory search instance.
    init(search: RoomDirectorySearch) {
        self.search = search
    }

    deinit {
        resultsHandle?.cancel()
    }

    /// Subscribes to search result updates from the SDK.
    ///
    /// Call this once after initialization to begin receiving results.
    func startListening() async { // swiftlint:disable:this cyclomatic_complexity
        let listener = SDKListener<[RoomDirectorySearchEntryUpdate]> { [weak self] updates in
            guard let self else { return }
            lock.lock()
            for update in updates {
                switch update {
                case .append(let values):
                    _storage.append(contentsOf: values)
                case .clear:
                    _storage.removeAll()
                case .pushFront(let value):
                    _storage.insert(value, at: 0)
                case .pushBack(let value):
                    _storage.append(value)
                case .popFront:
                    if !_storage.isEmpty { _storage.removeFirst() }
                case .popBack:
                    if !_storage.isEmpty { _storage.removeLast() }
                case .insert(let index, let value):
                    _storage.insert(value, at: Int(index))
                case .set(let index, let value):
                    _storage[Int(index)] = value
                case .remove(let index):
                    _storage.remove(at: Int(index))
                case .truncate(let length):
                    _storage = Array(_storage.prefix(Int(length)))
                case .reset(let values):
                    _storage = values
                }
            }
            let snapshot = _storage
            // Bump the counter on every non-empty delivery so waiters can
            // distinguish new results from stale data or intermediate clears.
            if !snapshot.isEmpty {
                _updateCounter += 1
            }
            let waiter: CheckedContinuation<[RoomDescription], Never>?
            if !snapshot.isEmpty, let pending = pendingContinuation, _updateCounter > pendingAfterCounter {
                waiter = pending
                pendingContinuation = nil
            } else {
                waiter = nil
            }
            lock.unlock()
            waiter?.resume(returning: snapshot)
            Task { @MainActor [weak self] in
                self?.results = snapshot
            }
        }
        resultsHandle = await search.results(listener: listener)
    }

    /// Returns the current update counter.
    ///
    /// Record this value before calling ``search(filter:batchSize:viaServerName:)``
    /// or ``nextPage()``, then pass it to ``waitForNextUpdate(after:)`` to wait for
    /// results that arrive after the operation.
    var updateCounter: UInt64 {
        lock.lock()
        let value = _updateCounter
        lock.unlock()
        return value
    }

    /// Suspends until the SDK listener delivers a non-empty results snapshot
    /// with an update counter greater than `previousCounter`.
    ///
    /// This ensures the caller receives genuinely new results rather than
    /// stale data that was already present before the operation.
    ///
    /// - Parameter previousCounter: The counter value recorded before the
    ///   search or pagination operation.
    /// - Returns: The latest results snapshot from the SDK.
    /// How long to wait for the listener before answering with what we have.
    ///
    /// Callers await the search call itself first, so the network round trip
    /// is already done and this only covers local listener delivery.
    private static let updateDeliveryTimeout: Duration = .seconds(3)

    /// Takes the pending continuation, if any, together with the current
    /// snapshot.
    ///
    /// Synchronous on purpose: `NSLock` cannot be used from an async context,
    /// and whichever path gets here first clears the continuation, so it can
    /// never be resumed twice.
    private func takePendingWaiter() -> (CheckedContinuation<[RoomDescription], Never>?, [RoomDescription]) {
        lock.lock()
        let waiter = pendingContinuation
        pendingContinuation = nil
        let snapshot = _storage
        lock.unlock()
        return (waiter, snapshot)
    }

    func waitForNextUpdate(after previousCounter: UInt64) async -> [RoomDescription] {
        await withCheckedContinuation { continuation in
            lock.lock()
            if _updateCounter > previousCounter, !_storage.isEmpty {
                let snapshot = _storage
                lock.unlock()
                continuation.resume(returning: snapshot)
            } else {
                pendingContinuation = continuation
                pendingAfterCounter = previousCounter
                lock.unlock()

                // Both the listener and the check above ignore empty
                // snapshots, so a homeserver that publishes no rooms at all
                // resumes nothing and the caller waits forever — the directory
                // sheet spun its spinner indefinitely rather than saying there
                // was nothing to show. "No rooms" is an answer, not a missing
                // one.
                Task { [weak self] in
                    try? await Task.sleep(for: Self.updateDeliveryTimeout)
                    guard let self else { return }
                    let (waiter, snapshot) = self.takePendingWaiter()
                    waiter?.resume(returning: snapshot)
                }
            }
        }
    }

    func search(filter: String?, batchSize: UInt32, viaServerName: String?) async throws {
        try await search.search(filter: filter, batchSize: batchSize, viaServerName: viaServerName)
    }

    func nextPage() async throws {
        try await search.nextPage()
    }

    func isAtLastPage() async throws -> Bool {
        try await search.isAtLastPage()
    }

    public func loadedPages() async throws -> UInt32 {
        try await search.loadedPages()
    }
}
