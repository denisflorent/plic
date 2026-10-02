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

/// A diagnostic event log that captures service-level activity for debugging.
///
/// ``ActivityLogProtocol`` defines the read-only interface consumed by the Activity
/// Log window. The concrete implementation lives in `RelayKit` and accumulates
/// ``ActivityEvent`` entries in a ring buffer from app launch.
@MainActor
public protocol ActivityLogProtocol: AnyObject, Observable {
    /// All captured events, ordered from oldest to newest.
    ///
    /// The backing store is a ring buffer; when the capacity limit is reached,
    /// the oldest events are dropped.
    var events: [ActivityEvent] { get }

    /// Removes all captured events.
    func clear()
}

// MARK: - Environment Key

private struct ActivityLogKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: any ActivityLogProtocol = PlaceholderActivityLog()
}

/// SwiftUI environment accessor for the shared ``ActivityLogProtocol`` instance.
public extension EnvironmentValues {
    /// The activity log used for diagnostic event capture and display.
    var activityLog: any ActivityLogProtocol {
        get { self[ActivityLogKey.self] }
        set { self[ActivityLogKey.self] = newValue }
    }
}

@Observable
final class PlaceholderActivityLog: ActivityLogProtocol {
    var events: [ActivityEvent] = []
    func clear() {}
}
