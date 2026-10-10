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

import AppKit
import SwiftUI

/// The Liquid Glass backdrop, for a window whose background is clear.
///
/// A vibrancy layer samples what sits behind the window, and a clear glass
/// pane refracts it. Content drawn over this must leave it visible: an
/// opaque fill anywhere hides the glass under it.
struct LiquidGlassBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        let backdrop = NSVisualEffectView()
        backdrop.material = .underWindowBackground
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        let glass = NSGlassEffectView()
        glass.style = .clear
        glass.cornerRadius = 24
        glass.contentView = NSView()
        for layer in [backdrop, glass] {
            layer.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(layer)
            NSLayoutConstraint.activate([
                layer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                layer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                layer.topAnchor.constraint(equalTo: container.topAnchor),
                layer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
        return container
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

/// Makes the hosting window see-through for Liquid Glass, and solid again
/// for the other appearances.
struct GlassWindowConfigurator: NSViewRepresentable {
    var usesGlass: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in configure(view.window) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        Task { @MainActor in configure(view.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = !usesGlass
        window.backgroundColor = usesGlass ? .clear : .windowBackgroundColor
    }
}
