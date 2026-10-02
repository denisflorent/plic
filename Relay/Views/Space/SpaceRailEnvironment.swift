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

// MARK: - Space Rail Environment

private struct HasSpaceRailKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Whether the space rail is currently visible in the sidebar.
    ///
    /// Sidebar views use this to maintain consistent compact layout
    /// thresholds regardless of whether the rail is shown. When the
    /// rail is absent, views should subtract ``SpaceRail/width`` from
    /// their measured width so they don't prematurely leave compact mode.
    var hasSpaceRail: Bool {
        get { self[HasSpaceRailKey.self] }
        set { self[HasSpaceRailKey.self] = newValue }
    }
}
