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

/// Pins what a received link can make this Mac fetch without a click.
@MainActor
struct LinkPreviewPrivacyTests {

    @Test("Link previews are off unless the user turns them on")
    func offByDefault() {
        // On, every received link would tell its site this Mac's IP address
        // and when the message was read.
        #expect(LinkPreviewSetting.standard == false)
    }

    nonisolated static let localHosts = [
        "http://192.168.1.1/admin", "http://10.0.0.2/", "http://172.20.1.1/", "http://127.0.0.1/",
        "http://127.1/", "http://2130706433/", "http://0x7f000001/", "http://169.254.169.254/",
        "http://100.64.0.1/", "http://[::1]/", "http://[fe80::1]/", "http://[fd00::1]/",
        "http://[::ffff:192.168.0.1]/", "http://router/", "http://nas.local/", "http://printer.lan/",
        "http://localhost:8080/",
    ]

    @Test("Nothing on this Mac or its network is ever fetched", arguments: localHosts)
    func localNetworkIsNotPreviewed(url: String) {
        #expect(URLPreviewExtractor.firstPreviewURL(in: "see \(url) now") == nil, "\(url) would be fetched")
    }

    @Test("Public sites are still previewed when previews are on")
    func publicSitesAreFine() {
        #expect(URLPreviewExtractor.firstPreviewURL(in: "see https://example.com/page") != nil)
        #expect(URLPreviewExtractor.firstPreviewURL(in: "see http://93.184.216.34/") != nil)
    }
}
