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

/// A single diagnostic event captured from the service layer for debugging.
///
/// ``ActivityEvent`` provides an "under the hood" view into the sync pipeline, room
/// list management, timeline diff processing, and network state. Events are stored
/// in a ring buffer by ``ActivityLogProtocol`` and displayed in the Activity Log window.
public struct ActivityEvent: Identifiable, Sendable, Codable {
    /// The subsystem that produced the event.
    public enum Category: String, Sendable, CaseIterable, Identifiable, Codable {
        case sync
        case roomList
        case timeline
        case network
        case auth
        case media
        case call

        public var id: String { rawValue }

        /// A human-readable label for display in the UI.
        nonisolated public var label: String {
            switch self {
            case .sync: "Sync"
            case .roomList: "Room List"
            case .timeline: "Timeline"
            case .network: "Network"
            case .auth: "Auth"
            case .media: "Media"
            case .call: "Call"
            }
        }

        /// An SF Symbol icon name for this category.
        nonisolated public var icon: String {
            switch self {
            case .sync: "arrow.triangle.2.circlepath"
            case .roomList: "list.bullet"
            case .timeline: "text.bubble"
            case .network: "network"
            case .auth: "person.badge.key"
            case .media: "photo"
            case .call: "phone.fill"
            }
        }
    }

    /// The severity level of the event.
    public enum Severity: String, Sendable, CaseIterable, Identifiable, Comparable, Codable {
        case debug
        case info
        case warning
        case error

        public var id: String { rawValue }

        /// A human-readable label for display in the UI.
        nonisolated public var label: String {
            switch self {
            case .debug: "Debug"
            case .info: "Info"
            case .warning: "Warning"
            case .error: "Error"
            }
        }

        public static func < (lhs: Severity, rhs: Severity) -> Bool {
            let order: [Severity] = [.debug, .info, .warning, .error]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }

    /// A stable, unique identifier for this event.
    public let id: UUID

    /// The time at which the event was captured.
    public let timestamp: Date

    /// The subsystem that produced the event.
    public let category: Category

    /// The severity level of the event.
    public let severity: Severity

    /// The specific component that produced the event (e.g. ``"SyncManager"``, ``"RoomListManager"``).
    public let source: String

    /// A one-line summary of what happened.
    public let summary: String

    /// An optional multi-line description with additional context.
    public let detail: String?

    /// The Matrix room ID this event relates to, if applicable.
    public let roomId: String?

    /// Arbitrary key-value metadata for filtering and search.
    public let metadata: [String: String]

    /// Creates a new ``ActivityEvent``.
    nonisolated public init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        category: Category,
        severity: Severity,
        source: String,
        summary: String,
        detail: String? = nil,
        roomId: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.severity = severity
        self.source = source
        self.summary = summary
        self.detail = detail
        self.roomId = roomId
        self.metadata = metadata
    }

    /// The timestamp formatted with millisecond precision (e.g. ``"14:30:05.123"``).
    nonisolated public var formattedTimestamp: String {
        timestamp.formatted(
            .dateTime
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .secondFraction(.fractional(3))
        )
    }
}
