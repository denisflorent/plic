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

import SwiftUI

/// The Labs tab of the Settings window, providing opt-in experimental features.
struct SettingsLabsTab: View {
    @AppStorage("labs.timelineUseLazyVStack") private var timelineUseLazyVStack = false

    var body: some View {
        Form {
            Section {
                Toggle("Use LazyVStack Timeline Renderer", isOn: $timelineUseLazyVStack)
            } header: {
                Text("Timeline Experiments")
            } footer: {
                Text(
                    "Switches timeline rendering from NSTableView to a SwiftUI LazyVStack. "
                        + "This experiment is off by default and may have performance regressions."
                )
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    TabView {
        SettingsLabsTab()
            .tabItem { Label("Labs", systemImage: "flask") }
    }
    .frame(width: 480)
}
