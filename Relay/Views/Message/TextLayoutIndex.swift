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

/// Turns a TextKit 2 fragment offset plus a fragment-local index into a
/// document-wide character index, or `nil` when the inputs do not describe one.
enum TextLayoutIndex {

    /// Resolves a character index into the text storage.
    ///
    /// Both inputs come from TextKit 2 APIs that signal failure by returning
    /// `NSNotFound` rather than `nil` — `NSTextContentManager.offset(from:to:)`
    /// when the two locations are not comparable, and
    /// `NSTextLineFragment.characterIndex(for:)` for a point the fragment does
    /// not cover. On a 64-bit platform `NSNotFound` is `Int.max`, so adding
    /// anything at all to it traps on overflow.
    ///
    /// That is not hypothetical: hovering the mouse over message text crashed
    /// the app on `fragOffset + localCharIndex`. The bounds check that was
    /// supposed to catch a nonsense index sat on the line *after* the addition,
    /// so it never ran.
    ///
    /// - Returns: The index, or `nil` if either input is a sentinel or
    ///   negative, if the sum overflows, or if the result falls outside the
    ///   storage. Every one of those means "there is no character here", which
    ///   callers already handle.
    static func resolve(fragmentOffset: Int, localIndex: Int, textLength: Int) -> Int? {
        guard fragmentOffset != NSNotFound, fragmentOffset >= 0,
              localIndex != NSNotFound, localIndex >= 0
        else { return nil }

        let (index, overflowed) = fragmentOffset.addingReportingOverflow(localIndex)
        guard !overflowed, index >= 0, index < textLength else { return nil }
        return index
    }
}
