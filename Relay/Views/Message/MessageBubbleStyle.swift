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

/// How messages are drawn in the timeline.
///
/// Replaces a `coloredBubbles` Bool, which could only ever answer one question
/// and had no room for a third answer.
enum MessageBubbleStyle: String, CaseIterable, Identifiable {
    /// Incoming messages on a neutral fill, outgoing on the accent colour.
    case grey
    /// Every message on a fill derived from its sender, so a busy room is
    /// readable by colour before it is read by name.
    case colored
    /// No fill at all. The timeline becomes a transcript rather than a chat —
    /// which is what people who read long rooms rather than converse in them
    /// tend to want, and what every terminal client has always done.
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .grey: "Grey"
        case .colored: "Colored"
        case .none: "None"
        }
    }

    /// Whether messages get a filled, rounded background.
    ///
    /// Everything else about a message — padding, alignment, the rounding on
    /// an image — stays the same in all three, so this is the only question
    /// the renderer has to ask.
    var drawsBubble: Bool { self != .none }

    /// Whether the fill comes from the sender rather than from send direction.
    var isSenderColored: Bool { self == .colored }

    // MARK: - Storage

    static let key = "appearance.bubbleStyle"
    static let standard = MessageBubbleStyle.grey

    /// The Bool this setting used to be.
    private static let legacyKey = "appearance.coloredBubbles"

    /// Carries an existing choice over to the new key, once.
    ///
    /// Without this, everyone who had picked Colored would silently land back
    /// on Grey the first time they opened a build with three options — a
    /// preference quietly discarded, which is worse than never having offered
    /// it. Runs before any view reads the setting.
    static func migrateLegacySettingIfNeeded(in defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: key) == nil,
              defaults.object(forKey: legacyKey) != nil
        else { return }
        let wasColored = defaults.bool(forKey: legacyKey)
        defaults.set((wasColored ? MessageBubbleStyle.colored : .grey).rawValue, forKey: key)
    }
}
