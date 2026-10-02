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

// NotificationModeConversions.swift
// RelayKit
//
// SPDX-License-Identifier: Apache-2.0

import RelayInterface

/// Bidirectional conversions between the app's notification mode enums
/// and the SDK's ``MatrixRustSDK.RoomNotificationMode``.
///
/// `DefaultNotificationMode` represents the account-wide default, while
/// `RoomNotificationMode` represents a per-room override. Both map to
/// the same SDK enum with identical cases.

extension DefaultNotificationMode {
    /// Converts to the SDK notification mode.
    var sdkMode: MatrixRustSDK.RoomNotificationMode {
        switch self {
        case .allMessages: .allMessages
        case .mentionsAndKeywordsOnly: .mentionsAndKeywordsOnly
        case .mute: .mute
        }
    }

    /// Creates from an SDK notification mode.
    init(sdkMode: MatrixRustSDK.RoomNotificationMode) {
        switch sdkMode {
        case .allMessages: self = .allMessages
        case .mentionsAndKeywordsOnly: self = .mentionsAndKeywordsOnly
        case .mute: self = .mute
        }
    }
}

extension RelayInterface.RoomNotificationMode {
    /// Converts to the SDK notification mode.
    var sdkMode: MatrixRustSDK.RoomNotificationMode {
        switch self {
        case .allMessages: .allMessages
        case .mentionsAndKeywordsOnly: .mentionsAndKeywordsOnly
        case .mute: .mute
        }
    }

    /// Creates from an SDK notification mode.
    init(sdkMode: MatrixRustSDK.RoomNotificationMode) {
        switch sdkMode {
        case .allMessages: self = .allMessages
        case .mentionsAndKeywordsOnly: self = .mentionsAndKeywordsOnly
        case .mute: self = .mute
        }
    }
}
