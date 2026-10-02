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

/// Pre-flight permission gate for calls.
///
/// The system shows its own permission dialog when LiveKit first accesses
/// the microphone or camera. This helper only checks whether the user has
/// *previously denied* access so we can direct them to System Settings
/// instead of starting a call that will immediately fail.
enum MediaPermissions {

    /// Whether the microphone or camera has been explicitly denied or
    /// restricted by the user.
    static var isDenied: Bool {
        isDenied(video: true)
    }

    /// Whether the permissions a call actually needs have been denied.
    ///
    /// An audio-only call never touches the camera, so a user who has refused
    /// camera access should still be able to place one. Checking both regardless
    /// would block them for a device the call will not open.
    ///
    /// - Parameter video: Whether the call will publish video.
    static func isDenied(video: Bool) -> Bool {
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        if mic == .denied || mic == .restricted { return true }
        guard video else { return false }
        let camera = AVCaptureDevice.authorizationStatus(for: .video)
        return camera == .denied || camera == .restricted
    }
}
