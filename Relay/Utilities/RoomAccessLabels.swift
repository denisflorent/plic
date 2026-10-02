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

/// Shared display labels for room and space access settings.
///
/// Used by ``InspectorSecurityTab`` and ``InspectorGeneralTab`` to
/// show human-readable descriptions for join rules, history visibility,
/// and related access settings.
enum RoomAccessLabels {

    // MARK: - Join Rule

    static func joinRuleLabel(_ rule: String?) -> String {
        switch rule {
        case "public": "Anyone Can Join"
        case "invite": "Invite Only"
        case "knock": "Request to Join"
        case "restricted": "Restricted"
        case "knock_restricted": "Knock (Restricted)"
        default: "Unknown"
        }
    }

    static func joinRuleIcon(_ rule: String?) -> String {
        switch rule {
        case "public": "globe"
        case "invite": "envelope"
        case "knock": "hand.raised"
        default: "questionmark.circle"
        }
    }

    static func joinRuleDescription(_ rule: String?, entityName: String = "room") -> String {
        switch rule {
        case "public": "Anyone can join this \(entityName) without an invitation."
        case "invite": "Users must receive an invitation to join this \(entityName)."
        case "knock": "Users can request to join. Admins must approve each request."
        case "restricted": "Users can join if they meet specific conditions."
        default: "The join rule for this \(entityName) is not configured."
        }
    }

    // MARK: - History Visibility

    static func historyLabel(_ visibility: String?) -> String {
        switch visibility {
        case "world_readable": "Anyone (World Readable)"
        case "shared": "Full History"
        case "invited": "Since Invited"
        case "joined": "Since Joined"
        default: "Unknown"
        }
    }

    static func historyIcon(_ visibility: String?) -> String {
        switch visibility {
        case "world_readable": "globe"
        case "shared": "person.2"
        case "invited": "envelope"
        case "joined": "person.badge.key"
        default: "questionmark.circle"
        }
    }

    static func historyColor(_ visibility: String?) -> Color {
        switch visibility {
        case "world_readable": .blue
        case "shared": .green
        case "invited": .orange
        case "joined": .secondary
        default: .secondary
        }
    }

    static func historyDescription(_ visibility: String?) -> String {
        switch visibility {
        case "world_readable": "Anyone can read the history, even without joining."
        case "shared": "Members can see the full history from before they joined."
        case "invited": "Members can see history from the point they were invited."
        case "joined": "Members can only see history from the point they joined."
        default: "History visibility is not configured."
        }
    }
}
