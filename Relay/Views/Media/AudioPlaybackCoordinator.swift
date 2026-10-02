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

import AVFoundation
import Observation
import SwiftUI

/// Owns the one audio player shared by the whole timeline.
///
/// Playback used to live in `@State` inside the message bubble, which tied the
/// player's life to the view's. Any new event rebuilt the timeline, SwiftUI
/// discarded and recreated the row, and the audio stopped mid-sentence — so a
/// voice message could not be listened to in a room that was still talking,
/// which is exactly the room where voice messages arrive.
///
/// Hoisting it above the timeline fixes that and settles a second question the
/// old arrangement got wrong by omission: each bubble had its own player, so
/// two could play at once. There is one output, so there is one player.
@MainActor
@Observable
final class AudioPlaybackCoordinator {

    /// The message currently loaded, or `nil` when nothing is.
    private(set) var activeMessageID: String?

    @ObservationIgnored private let controller = AudioPlaybackController()

    // MARK: - Reading state for one message

    /// State is per-message: a bubble asks about itself and gets silence
    /// unless it is the one playing, so a second bubble never shows a playhead
    /// belonging to the first.

    func isPlaying(_ messageID: String) -> Bool {
        activeMessageID == messageID && controller.isPlaying
    }

    func isLoaded(_ messageID: String) -> Bool {
        activeMessageID == messageID && controller.isLoaded
    }

    func failed(_ messageID: String) -> Bool {
        activeMessageID == messageID && controller.failed
    }

    func progress(_ messageID: String) -> Double {
        activeMessageID == messageID ? controller.progress : 0
    }

    func currentTime(_ messageID: String) -> TimeInterval {
        activeMessageID == messageID ? controller.currentTime : 0
    }

    func duration(_ messageID: String) -> TimeInterval {
        activeMessageID == messageID ? controller.duration : 0
    }

    // MARK: - Control

    /// Loads a message's decoded audio, replacing whatever was playing.
    ///
    /// - Returns: `false` when it holds no playable audio.
    @discardableResult
    func load(_ buffer: AVAudioPCMBuffer, for messageID: String) -> Bool {
        if activeMessageID != messageID {
            controller.stop()
            activeMessageID = messageID
        }
        return controller.load(buffer)
    }

    /// Plays or pauses the given message.
    ///
    /// Ignored for a message that is not the loaded one — the caller downloads
    /// and loads first, and acting here would toggle whatever else was playing.
    func togglePlayback(for messageID: String) {
        guard activeMessageID == messageID else { return }
        controller.togglePlayback()
    }

    func seek(_ fraction: Double, for messageID: String) {
        guard activeMessageID == messageID else { return }
        controller.seek(toFraction: fraction)
    }

    /// Stops playback and forgets the loaded file.
    func stop() {
        controller.stop()
        activeMessageID = nil
    }
}

// MARK: - Environment

private struct AudioPlaybackCoordinatorKey: EnvironmentKey {
    @MainActor static let defaultValue = AudioPlaybackCoordinator()
}

extension EnvironmentValues {
    /// The shared audio player. Injected once at the app level so it outlives
    /// every timeline rebuild, room switch and window.
    var audioPlayback: AudioPlaybackCoordinator {
        get { self[AudioPlaybackCoordinatorKey.self] }
        set { self[AudioPlaybackCoordinatorKey.self] = newValue }
    }
}
