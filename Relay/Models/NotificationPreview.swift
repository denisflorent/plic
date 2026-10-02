// Copyright 2026 Denis Florent Media Group SRL
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

/// What a message notification may reveal.
///
/// A banner's text leaves Plic: macOS shows it on screen, and keeps it in its
/// own notification database — unencrypted by Plic, out of its reach, and
/// still there after signing out. For a message from an encrypted room that
/// is the decrypted text. This lets the user decide how much of it goes.
enum NotificationPreview: String, CaseIterable, Identifiable {
    case nameAndMessage
    case nameOnly
    case nothing

    static let key = "notifications.preview"

    /// Unchanged from before the setting existed, so nobody's notifications
    /// change without them asking.
    static let standard = NotificationPreview.nameAndMessage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nameAndMessage: "Name and Message"
        case .nameOnly: "Name Only"
        case .nothing: "No Name or Message"
        }
    }

    /// The banner's title and body for a message under this setting.
    func banner(roomName: String, author: String?, message: String?, isDirect: Bool) -> (title: String, body: String) {
        let who = isDirect ? roomName : "\(author ?? "Unknown sender") in \(roomName)"
        switch self {
        case .nameAndMessage: return (who, message ?? "New message")
        case .nameOnly: return (who, "New message")
        case .nothing: return ("Plic", "New message")
        }
    }
}
