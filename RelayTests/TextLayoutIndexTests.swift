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

/// Covers the arithmetic behind hit-testing links in message text.
///
/// Moving the mouse over a message crashed the app with an arithmetic
/// overflow: the code added a fragment offset to a fragment-local index and
/// bounds-checked the result on the next line, but TextKit 2 reports "no such
/// location" as `NSNotFound`, which is `Int.max`, so the addition trapped
/// before any check could run.
struct TextLayoutIndexTests {

    @Test("A normal index resolves")
    func resolvesOrdinaryIndex() {
        #expect(TextLayoutIndex.resolve(fragmentOffset: 10, localIndex: 5, textLength: 100) == 15)
    }

    @Test("Index zero is valid")
    func resolvesZero() {
        #expect(TextLayoutIndex.resolve(fragmentOffset: 0, localIndex: 0, textLength: 1) == 0)
    }

    @Test("NSNotFound as the fragment offset yields nil rather than trapping")
    func rejectsNotFoundOffset() {
        // NSTextContentManager.offset(from:to:) returns this when the two
        // locations cannot be compared. This is the crash: Int.max + 5.
        #expect(TextLayoutIndex.resolve(fragmentOffset: NSNotFound, localIndex: 5, textLength: 100) == nil)
    }

    @Test("NSNotFound as the local index yields nil rather than trapping")
    func rejectsNotFoundLocalIndex() {
        // NSTextLineFragment.characterIndex(for:) returns this for a point the
        // fragment does not cover — a mouse position between or beside lines.
        #expect(TextLayoutIndex.resolve(fragmentOffset: 10, localIndex: NSNotFound, textLength: 100) == nil)
    }

    @Test("A sum that would overflow yields nil")
    func rejectsOverflow() {
        #expect(TextLayoutIndex.resolve(fragmentOffset: Int.max - 1, localIndex: 2, textLength: 100) == nil)
    }

    @Test("Negative inputs yield nil")
    func rejectsNegatives() {
        #expect(TextLayoutIndex.resolve(fragmentOffset: -1, localIndex: 5, textLength: 100) == nil)
        #expect(TextLayoutIndex.resolve(fragmentOffset: 5, localIndex: -1, textLength: 100) == nil)
    }

    @Test("An index past the end of the storage yields nil")
    func rejectsOutOfBounds() {
        // The original guard's job, kept: attribute(at:) traps on an index
        // outside the storage just as surely as the addition did.
        #expect(TextLayoutIndex.resolve(fragmentOffset: 90, localIndex: 10, textLength: 100) == nil)
        #expect(TextLayoutIndex.resolve(fragmentOffset: 90, localIndex: 9, textLength: 100) == 99)
    }

    @Test("Empty storage has no valid index")
    func rejectsEmptyStorage() {
        #expect(TextLayoutIndex.resolve(fragmentOffset: 0, localIndex: 0, textLength: 0) == nil)
    }
}
