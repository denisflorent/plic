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
import RelayInterface
import Testing

/// Pins the OAuth client identity to the rules Matrix's reference
/// authorization server (MAS) enforces at registration.
///
/// Breaking one of them does not show until someone tries to sign in with
/// OAuth — matrix.org included — and gets "invalid redirect_uri".
struct OAuthClientIdentityTests {

    private var clientHost: String { URL(string: OAuthClientIdentity.clientURI)?.host() ?? "" }

    @Test("The redirect scheme is the client's host in reverse DNS order")
    func schemeMatchesHost() {
        // MAS: the scheme's leading labels must be the client_uri host reversed.
        let reversed = clientHost.split(separator: ".").reversed().map(String.init)
        let labels = OAuthClientIdentity.redirectScheme.split(separator: ".").map(String.init)
        #expect(!reversed.isEmpty)
        #expect(Array(labels.prefix(reversed.count)) == reversed)
    }

    @Test("The redirect URI has no host, as a private-use scheme must")
    func redirectShape() {
        #expect(OAuthClientIdentity.redirectURI == "\(OAuthClientIdentity.redirectScheme):/")
    }

    @Test("Logo and policy are https, on the client's host")
    func sameHost() {
        for uri in [OAuthClientIdentity.clientURI, OAuthClientIdentity.logoURI, OAuthClientIdentity.policyURI] {
            let url = URL(string: uri)
            #expect(url?.scheme == "https", "\(uri)")
            #expect(url?.host() == clientHost, "\(uri)")
        }
    }
}
