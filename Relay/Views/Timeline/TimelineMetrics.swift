// Copyright 2026 Denis Florent
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

import CoreGraphics

/// The timeline's vertical rhythm, in points.
///
/// Gathered here because these values only make sense relative to one another —
/// the gap between two messages from one sender has to read as tighter than the
/// gap at a change of sender, or the grouping stops communicating anything.
/// They were previously spread across three files, which made tuning the rhythm
/// a matter of hunting rather than reading.
nonisolated enum TimelineMetrics {

    /// Gap between consecutive messages, applied as the table's intercell
    /// spacing.
    ///
    /// Deliberately small so a run from one sender reads as a single block.
    /// Raising it much past this starts to dissolve the group; if the timeline
    /// feels cramped, this is nonetheless the first value to try.
    static let messageSpacing: CGFloat = 4

    /// Extra gap inserted when the sender changes, on top of
    /// ``messageSpacing``.
    ///
    /// Keep the total here several times ``messageSpacing`` — that ratio is
    /// what makes a change of speaker visible at a glance.
    static let senderChangeSpacing: CGFloat = 10

    /// Room held above every bubble for reaction badges, which are drawn
    /// overlapping the top edge.
    ///
    /// Reserved unconditionally, not just where reactions exist. The timeline
    /// is an `NSTableView` with cached row heights, so growing a row the moment
    /// a reaction arrives invalidates its measurement and reflows the table —
    /// the content jumps, worst of all when the reaction comes from someone
    /// else while you are reading. Holding the space always means the height
    /// never changes and nothing moves.
    ///
    /// Bound to the badge geometry, not to taste: it must match the badges'
    /// vertical offset in `MessageView`. Adjust the rhythm elsewhere.
    static let reactionOverlay: CGFloat = 11

    /// Gap between the last message and the compose bar.
    ///
    /// Without it the timeline runs straight into the input field and the last
    /// bubble looks stuck to it.
    static let composeBarSpacing: CGFloat = 10

    /// Space above a date header, and the tighter value used when the header is
    /// the very first row and has nothing to separate from.
    static let dateHeaderTopSpacing: CGFloat = 12
    static let dateHeaderFirstTopSpacing: CGFloat = 4

    /// Space below a date header, before the first message of that day.
    static let dateHeaderBottomSpacing: CGFloat = 4
}
