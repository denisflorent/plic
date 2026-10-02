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

/// How Plic identifies itself when it registers as an OAuth client.
///
/// The authorization server shows these on its consent screen, so every URL
/// here must be on a domain the publisher actually owns. Matrix's reference
/// server (MAS) also requires the redirect scheme to be that domain in reverse
/// DNS order, and the logo and policy pages to sit on the same host — but it
/// never checks ownership. Advertising a domain nobody holds would let whoever
/// registers it choose the logo and the link shown to every user signing in.
///
/// **Forks must change all of these** to a domain of their own, together with
/// the `CFBundleURLSchemes` entry for the OAuth callback in `Info.plist`.
public enum OAuthClientIdentity {
    /// Reverse-DNS of ``clientURI``'s host, plus the app. MAS accepts a scheme
    /// whose leading labels are the client host reversed.
    public static let redirectScheme = "group.denisflorent.plic"

    /// The redirect URI registered with the authorization server.
    public static let redirectURI = "\(redirectScheme):/"

    public static let clientURI = "https://denisflorent.group/plic/"
    public static let logoURI = "https://denisflorent.group/plic/icon-256.png"
    public static let policyURI = "https://denisflorent.group/plic/privacy/"
}
