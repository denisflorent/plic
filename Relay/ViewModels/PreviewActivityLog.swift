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

/// A mock implementation of ``ActivityLogProtocol`` for use in SwiftUI previews.
///
/// Provides a static set of sample events demonstrating the various categories,
/// severities, and metadata shapes that the real ``ActivityLog`` produces.
@Observable
final class PreviewActivityLog: ActivityLogProtocol {
    var events: [ActivityEvent]

    init(events: [ActivityEvent] = PreviewActivityLog.sampleEvents) {
        self.events = events
    }

    func clear() {
        events.removeAll()
    }

    static let shared = PreviewActivityLog()

    static let sampleEvents: [ActivityEvent] = {
        let base = Date.now.addingTimeInterval(-60)
        return [
            ActivityEvent(
                timestamp: base,
                category: .auth, severity: .info, source: "MatrixService",
                summary: "Session restored",
                metadata: ["userId": "@alice:matrix.org"]
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(0.5),
                category: .sync, severity: .info, source: "MatrixService",
                summary: "Starting sync pipeline"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(1.0),
                category: .sync, severity: .info, source: "SyncManager",
                summary: "Starting sync"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(3.2),
                category: .sync, severity: .info, source: "SyncManager",
                summary: "Sync state: running"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(3.5),
                category: .sync, severity: .info, source: "MatrixService",
                summary: "Room list manager started"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(4.0),
                category: .roomList, severity: .debug, source: "RoomListManager",
                summary: "42 entry update(s): 0 → 42 entries",
                detail: "reset(42)"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(4.5),
                category: .roomList, severity: .debug, source: "RoomListManager",
                summary: "Room list rebuilt: 42 rooms sorted"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(5.0),
                category: .roomList, severity: .debug, source: "RoomEntry",
                summary: "Room info updated: Design Team",
                detail: "Unread: 0 → 3, mentions: 1",
                roomId: "!design:matrix.org",
                metadata: ["roomName": "Design Team"]
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(10.0),
                category: .timeline, severity: .debug, source: "TimelineViewModel",
                summary: "2 diff(s): 0 → 25 items",
                detail: "Diffs: reset(24), pushBack\nIndices: full remap",
                roomId: "!design:matrix.org"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(10.5),
                category: .timeline, severity: .debug, source: "TimelineViewModel",
                summary: "Messages updated: 20 messages (v1)",
                roomId: "!design:matrix.org"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(15.0),
                category: .network, severity: .warning, source: "NetworkMonitor",
                summary: "Network connectivity lost"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(15.5),
                category: .sync, severity: .warning, source: "SyncManager",
                summary: "Network lost — stopping sync service"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(20.0),
                category: .network, severity: .info, source: "NetworkMonitor",
                summary: "Network connectivity restored"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(20.5),
                category: .sync, severity: .info, source: "SyncManager",
                summary: "Network restored — restarting sync service",
                detail: "Reconnect attempt #0"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(22.0),
                category: .sync, severity: .info, source: "SyncManager",
                summary: "Sync state: running"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(30.0),
                category: .timeline, severity: .debug, source: "TimelineViewModel",
                summary: "1 diff(s): 25 → 26 items",
                detail: "Diffs: pushBack\nIndices: 1 changed",
                roomId: "!design:matrix.org"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(30.2),
                category: .timeline, severity: .debug, source: "TimelineViewModel",
                summary: "Messages updated: 21 messages (v2)",
                roomId: "!design:matrix.org"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(45.0),
                category: .sync, severity: .error, source: "SyncManager",
                summary: "SDK sync error",
                detail: "Transitioning to offline + backoff retry"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(45.5),
                category: .sync, severity: .info, source: "SyncManager",
                summary: "Scheduling reconnect attempt #1",
                detail: "Delay: 1.0s (slot 1/2, exponent 1)"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(50.0),
                category: .call, severity: .info, source: "MatrixService",
                summary: "Created call view model",
                detail: "E2EE: enabled",
                roomId: "!design:matrix.org"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(50.5),
                category: .call, severity: .info, source: "LiveKitCredentialService",
                summary: "Fetching call credentials",
                roomId: "!design:matrix.org"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(51.0),
                category: .call, severity: .info, source: "LiveKitCredentialService",
                summary: "Call credentials obtained",
                roomId: "!design:matrix.org"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(51.5),
                category: .call, severity: .info, source: "CallViewModel",
                summary: "Connecting to call",
                detail: "E2EE: enabled",
                roomId: "!design:matrix.org"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(53.0),
                category: .call, severity: .info, source: "CallViewModel",
                summary: "Connected to call",
                roomId: "!design:matrix.org"
            ),
            ActivityEvent(
                timestamp: base.addingTimeInterval(55.0),
                category: .call, severity: .debug, source: "CallViewModel",
                summary: "Remote participant connected",
                detail: "Identity: @bob:matrix.org:DEVICEABC",
                roomId: "!design:matrix.org"
            )
        ]
    }()
}
