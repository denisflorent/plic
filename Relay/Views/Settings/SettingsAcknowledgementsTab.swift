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

import SwiftUI

/// Shows the licences of everything Plic ships.
///
/// This is not a courtesy. Apache 2.0 section 4(a) requires giving recipients a
/// copy of the License with the Work "in Source or Object form" — a binary-only
/// distribution owes it too, and the app bundle previously contained no licence
/// text at all. Section 4(d) then requires reproducing any NOTICE file that
/// comes with a distributed component: LiveKit ships one, so that attribution
/// is mandatory rather than optional. The BSD 3-Clause terms covering WebRTC,
/// libopus and libogg separately require their notice and disclaimer to appear
/// in "the documentation and/or other materials provided with the
/// distribution". This window is those materials.
struct SettingsAcknowledgementsTab: View {
    /// A bundled licence document.
    private struct Document: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String

        /// Basename of the file in `Resources/Licenses`.
        var resource: String { id }
    }

    private static let documents: [Document] = [
        Document(
            id: "Apache-2.0",
            title: "Apache License 2.0",
            subtitle: "Plic, Relay, matrix-rust-sdk, LiveKit, SwiftProtobuf"
        ),
        Document(
            id: "LiveKit-NOTICE",
            title: "LiveKit — NOTICE",
            subtitle: "Reproduced under Apache 2.0 section 4(d)"
        ),
        Document(id: "WebRTC-LICENSE", title: "WebRTC", subtitle: "BSD 3-Clause"),
        Document(id: "libopus-LICENSE", title: "libopus", subtitle: "BSD 3-Clause"),
        Document(id: "libogg-LICENSE", title: "libogg", subtitle: "BSD 3-Clause"),
    ]

    @State private var selection: Document?
    @State private var text = ""

    var body: some View {
        HSplitView {
            List(Self.documents, selection: $selection) { document in
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title)
                        .font(.body)
                    Text(document.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                .tag(document)
            }
            .frame(minWidth: 220, idealWidth: 240)

            ScrollView {
                Text(text.isEmpty ? "Select a licence." : text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minWidth: 380)
        }
        .task(id: selection) {
            text = Self.load(selection) ?? ""
        }
        .onAppear {
            if selection == nil { selection = Self.documents.first }
        }
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Plic is built on open source.")
                    .font(.headline)
                Text(
                    "Plic is a fork of Relay by Link Dupont, Andrew Hunter, "
                        + "Lukas Frias Santos and other contributors."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.bar)
        }
    }

    /// Reads a bundled licence, or returns `nil` if it is missing.
    ///
    /// A missing file means the build stopped shipping a licence it is legally
    /// required to ship, so it says so plainly rather than showing an empty
    /// pane that looks like a rendering bug.
    private static func load(_ document: Document?) -> String? {
        guard let document else { return nil }
        guard let url = Bundle.main.url(
            forResource: document.resource,
            withExtension: "txt",
            subdirectory: "Licenses"
        ) ?? Bundle.main.url(forResource: document.resource, withExtension: "txt"),
            let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "\(document.title) is missing from this build. "
                + "It must ship: see NOTICE in the repository."
        }
        return contents
    }
}
