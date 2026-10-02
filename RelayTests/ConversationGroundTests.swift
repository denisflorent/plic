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

/// Pins the conversation background setting's contract.
///
/// The timeline and the Appearance tab each read this through `@AppStorage`,
/// and a setting whose two halves disagree on the key or the default is a
/// control that appears to do nothing.
@MainActor
struct ConversationGroundTests {

    @Test("The default is inside the offered range")
    func defaultIsInRange() {
        #expect(ConversationGround.Depth.range.contains(ConversationGround.Depth.standard))
    }

    @Test("The range starts at plain white and stops short of the full dark ground")
    func rangeBounds() {
        // Zero restores the white background this replaced, on purpose. The top
        // stops below 1 because the undiluted darker ground is too heavy behind
        // a page of text.
        #expect(ConversationGround.Depth.range.lowerBound == 0)
        #expect(ConversationGround.Depth.range.upperBound < 1)
    }

    @Test("The default is the shade that shipped")
    func defaultMatchesShippedShade() {
        // Changing this changes every existing user's window, since @AppStorage
        // falls back to it whenever nothing was stored.
        #expect(ConversationGround.Depth.standard == 0.35)
    }

    @Test("The storage key is namespaced to appearance settings")
    func keyIsNamespaced() {
        #expect(ConversationGround.Depth.key.hasPrefix("appearance."))
        #expect(ConversationGround.FieldDepth.key.hasPrefix("appearance."))
    }

    @Test("The two shades are stored separately")
    func theTwoSettingsDoNotShareAKey() {
        // Sharing a key would make each slider move the other, which is the
        // one behaviour the pair exists to avoid.
        #expect(ConversationGround.Depth.key != ConversationGround.FieldDepth.key)
    }

    @Test("The message field defaults to untouched glass")
    func fieldDefaultsToNoTint() {
        // Zero means the glass material shows through as it always has, so
        // nobody's compose bar changes appearance until they ask.
        #expect(ConversationGround.FieldDepth.standard == 0)
        #expect(ConversationGround.FieldDepth.range.contains(ConversationGround.FieldDepth.standard))
    }

    @Test("The bar shadow has its own key and a visible default")
    func barShadowContract() {
        #expect(ConversationGround.BarShadow.key.hasPrefix("appearance."))
        #expect(ConversationGround.BarShadow.key != ConversationGround.Depth.key)
        #expect(ConversationGround.BarShadow.key != ConversationGround.FieldDepth.key)
        // Non-zero on purpose: the bar cast no shadow before this, and a
        // control sitting at the bottom of its range looks broken.
        #expect(ConversationGround.BarShadow.standard > 0)
        #expect(ConversationGround.BarShadow.range.contains(ConversationGround.BarShadow.standard))
    }

    @Test("The shadow stays a bar resting on a page, not a floating sheet")
    func barShadowStaysSubtle() {
        #expect(ConversationGround.BarShadow.range.upperBound <= 0.5)
        #expect(ConversationGround.BarShadow.radius > 0)
    }
}
