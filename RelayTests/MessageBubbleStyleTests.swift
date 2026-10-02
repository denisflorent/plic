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
import Testing

@testable import Relay

/// Covers the bubble style choice and, mostly, the migration off the Bool it
/// replaced.
///
/// A preference that silently reverts is worse than one never offered, and the
/// only way to notice is to have picked Colored and reopened the app — which
/// nobody does deliberately.
@MainActor
struct MessageBubbleStyleTests {

    private func scratchDefaults() -> UserDefaults {
        let suite = "plic.bubblestyle.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test("Three styles are offered")
    func allCasesArePresent() {
        #expect(MessageBubbleStyle.allCases.count == 3)
        #expect(MessageBubbleStyle.allCases.contains(.none))
    }

    @Test("Only None drops the fill")
    func onlyNoneSkipsTheBubble() {
        #expect(MessageBubbleStyle.grey.drawsBubble)
        #expect(MessageBubbleStyle.colored.drawsBubble)
        #expect(!MessageBubbleStyle.none.drawsBubble)
    }

    @Test("Only Colored derives the fill from the sender")
    func onlyColoredIsSenderColored() {
        #expect(MessageBubbleStyle.colored.isSenderColored)
        #expect(!MessageBubbleStyle.grey.isSenderColored)
        #expect(!MessageBubbleStyle.none.isSenderColored)
    }

    @Test("A stored Colored preference survives the move to three options")
    func migratesColored() {
        let defaults = scratchDefaults()
        defaults.set(true, forKey: "appearance.coloredBubbles")

        MessageBubbleStyle.migrateLegacySettingIfNeeded(in: defaults)

        #expect(defaults.string(forKey: MessageBubbleStyle.key) == MessageBubbleStyle.colored.rawValue)
    }

    @Test("A stored Grey preference migrates too")
    func migratesGrey() {
        let defaults = scratchDefaults()
        defaults.set(false, forKey: "appearance.coloredBubbles")

        MessageBubbleStyle.migrateLegacySettingIfNeeded(in: defaults)

        #expect(defaults.string(forKey: MessageBubbleStyle.key) == MessageBubbleStyle.grey.rawValue)
    }

    @Test("Migration never overwrites a choice made under the new setting")
    func doesNotClobberANewChoice() {
        // Someone picks None, then the migration runs again on a later launch.
        // Reading the old key at that point would drag them back to Grey.
        let defaults = scratchDefaults()
        defaults.set(true, forKey: "appearance.coloredBubbles")
        defaults.set(MessageBubbleStyle.none.rawValue, forKey: MessageBubbleStyle.key)

        MessageBubbleStyle.migrateLegacySettingIfNeeded(in: defaults)

        #expect(defaults.string(forKey: MessageBubbleStyle.key) == MessageBubbleStyle.none.rawValue)
    }

    @Test("A fresh install is left alone")
    func freshInstallWritesNothing() {
        let defaults = scratchDefaults()

        MessageBubbleStyle.migrateLegacySettingIfNeeded(in: defaults)

        // Nothing stored means @AppStorage falls back to the default, which is
        // the intent. Writing one here would just be noise in the plist.
        #expect(defaults.object(forKey: MessageBubbleStyle.key) == nil)
    }
}
