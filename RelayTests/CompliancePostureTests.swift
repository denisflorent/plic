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

/// Asserts that the bundle keeps the promises its paperwork makes.
///
/// These run against `Bundle.main`, which in this test target is the built
/// `Plic.app` itself — so they check what actually ships, not what the source
/// tree intends.
struct CompliancePostureTests {

    // MARK: - Privacy manifest

    private func privacyManifest() throws -> [String: Any] {
        let url = try #require(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "PrivacyInfo.xcprivacy missing from the bundle — App Store Connect rejects the binary"
        )
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(plist as? [String: Any])
    }

    @Test("The privacy manifest ships and declares no tracking")
    func manifestDeclaresNoTracking() throws {
        let manifest = try privacyManifest()
        // The manifest states Plic collects nothing and tracks nobody. If
        // analytics or a crash reporter is ever added, this test failing is
        // the reminder that the claim has to change with the code — a stale
        // privacy manifest is worse than none, because it is a claim.
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
    }

    @Test("The declared API reasons are present")
    func manifestDeclaresRequiredReasonAPIs() throws {
        let manifest = try privacyManifest()
        let accessed = try #require(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let categories = accessed.compactMap { $0["NSPrivacyAccessedAPIType"] as? String }
        // UserDefaults is reached from 20+ files via @AppStorage; dropping its
        // declaration while still using it is an automatic rejection.
        #expect(categories.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
    }

    // MARK: - Licence documents

    /// The documents the app is legally required to ship: Apache 2.0 §4(a)
    /// for the licence text, §4(d) for LiveKit's NOTICE, and the BSD 3-Clause
    /// binary-attribution clause for WebRTC, libopus and libogg.
    nonisolated private static let requiredDocuments: [String] = [
        "Apache-2.0",
        "LiveKit-NOTICE",
        "WebRTC-LICENSE",
        "libopus-LICENSE",
        "libogg-LICENSE",
    ]

    @Test("Every required licence document ships, non-empty", arguments: requiredDocuments)
    func licenceShips(name: String) throws {
        // Same lookup the Acknowledgements tab uses: subdirectory first, then
        // flat, because the build may flatten the Licenses folder.
        let url = Bundle.main.url(forResource: name, withExtension: "txt", subdirectory: "Licenses")
            ?? Bundle.main.url(forResource: name, withExtension: "txt")
        let resolved = try #require(url, "\(name).txt missing — a legally required document")
        let contents = try String(contentsOf: resolved, encoding: .utf8)
        #expect(contents.count > 200, "\(name).txt is present but suspiciously short")
    }

    // MARK: - Bundle identity

    @Test("The copyright notice survives into the built Info.plist")
    func copyrightIsPresent() throws {
        // An empty INFOPLIST_KEY_NSHumanReadableCopyright makes Xcode omit the
        // key entirely — which is exactly what shipped for a while.
        let copyright = try #require(
            Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
        )
        #expect(copyright.contains("Denis Florent Media Group SRL"))
        #expect(copyright.contains("Relay contributors"))
    }
}
