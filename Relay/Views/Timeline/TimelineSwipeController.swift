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

import RelayInterface
import SwiftUI

/// Observable state for the swipe-to-reply gesture shared by both timeline
/// renderers. Each `TimelineRowView` reads its own message ID to check
/// whether it is being swiped.
@Observable
final class TimelineSwipeState {
    /// The message ID of the row currently being swiped, or `nil`.
    var swipingMessageId: String?
    /// The current horizontal offset of the swipe gesture.
    var offset: CGFloat = 0
    /// When `true`, the action bar is locked open and awaiting a button tap.
    var isLocked = false
}

/// Shared swipe-to-reply gesture logic used by both the `NSTableView` and
/// `LazyVStack` timeline renderers.
///
/// Each renderer detects scroll-wheel events in its own platform-specific
/// way (override `scrollWheel` vs. `NSEvent` monitor) and delegates to this
/// controller for axis locking, offset clamping, swipe-end evaluation, and
/// action bar dismissal. This eliminates the duplicated constants and
/// threshold logic that previously lived in both `BottomAnchoredTableView`
/// and `SwipeScrollHandler`.
@MainActor
enum TimelineSwipeController {

    // MARK: - Constants

    /// Minimum combined delta before the gesture axis is decided.
    static let axisLockThreshold: CGFloat = 4

    /// Offset at which the action bar locks open on swipe end.
    static let lockThreshold: CGFloat = 60

    /// Offset at which the reply action triggers immediately on swipe end.
    static let triggerThreshold: CGFloat = 100

    /// Maximum visual offset (rubber-band limit).
    static let maxOffset: CGFloat = 120

    // MARK: - Offset Clamping

    /// Applies rubber-band clamping past the trigger threshold: linear up
    /// to ``triggerThreshold``, then 30% of excess capped at ``maxOffset``.
    static func clampedOffset(_ delta: CGFloat) -> CGFloat {
        if delta <= triggerThreshold {
            return delta
        }
        let excess = delta - triggerThreshold
        return min(triggerThreshold + excess * 0.3, maxOffset)
    }

    // MARK: - Swipe End Evaluation

    /// The action to take when a horizontal swipe gesture ends.
    enum SwipeEndAction {
        /// The swipe exceeded the trigger threshold — fire the reply.
        case reply
        /// The swipe exceeded the lock threshold — lock the action bar open.
        case lock
        /// The swipe was too short — dismiss with no action.
        case dismiss
    }

    /// Evaluates the current swipe offset and returns the appropriate action.
    static func evaluateSwipeEnd(offset: CGFloat) -> SwipeEndAction {
        if offset >= triggerThreshold {
            return .reply
        } else if offset >= lockThreshold {
            return .lock
        } else {
            return .dismiss
        }
    }

    // MARK: - Action Bar Dismissal

    /// Animates the action bar closed and clears the swiping message ID
    /// after the animation completes.
    static func dismissActionBar(_ swipeState: TimelineSwipeState) {
        withAnimation(.snappy(duration: 0.25)) {
            swipeState.offset = 0
            swipeState.isLocked = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            swipeState.swipingMessageId = nil
        }
    }
}
