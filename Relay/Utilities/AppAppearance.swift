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

/// The appearance modes: follow the system, force light, force dark, or
/// Liquid Glass — dark, on a translucent window that shows what is behind it.
///
/// Stored as a raw `String` in `@AppStorage("appearance.mode")`. The
/// ``colorScheme`` property maps each case to a `ColorScheme?` suitable
/// for `.preferredColorScheme()` — returning `nil` for system (no override).
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case glass

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        case .glass: "Liquid Glass"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark, .glass: .dark
        }
    }

    /// Whether the window is see-through, with a Liquid Glass backdrop.
    var usesGlass: Bool { self == .glass }
}
