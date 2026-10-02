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

import Foundation
import MatrixRustSDK

/// Classifies SDK errors as transient connectivity / homeserver-reachability
/// problems vs. permanent authentication failures.
///
/// We pattern-match the SDK's typed error enums (`ClientBuildError`,
/// `ClientError.MatrixApi`) directly — no string sniffing.
enum NetworkErrorClassifier {
    /// True when an SDK error looks like a transient connectivity /
    /// homeserver-reachability problem. From the user's perspective both
    /// "Wi-Fi off" and "homeserver down" feel the same — both produce the
    /// same offline UX (banner + cached data + auto-retry).
    static func isOfflineShaped(_ error: Error) -> Bool {
        if let build = error as? ClientBuildError {
            switch build {
            case .ServerUnreachable, .WellKnownLookupFailed:
                return true
            default:
                return false
            }
        }

        if let client = error as? ClientError,
           case .MatrixApi(let kind, _, _, _) = client {
            switch kind {
            case .connectionFailed, .connectionTimeout:
                return true
            default:
                return false
            }
        }

        return false
    }

    /// True when an SDK error indicates that the session's access or
    /// refresh token has been invalidated by the homeserver.
    ///
    /// This covers the `M_UNKNOWN_TOKEN` error code returned when a
    /// refresh token expires (e.g. during an extended sleep) and the
    /// `M_UNAUTHORIZED` error code for other authentication failures.
    /// These errors are unrecoverable without re-authentication and
    /// should trigger a logout-and-return-to-login flow rather than
    /// retrying or showing an offline banner.
    static func isAuthenticationError(_ error: Error) -> Bool {
        guard let client = error as? ClientError,
              case .MatrixApi(let kind, _, _, _) = client else {
            return false
        }
        switch kind {
        case .unknownToken:
            return true
        case .unauthorized:
            return true
        default:
            return false
        }
    }
}
