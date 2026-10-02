// Copyright 2026 Denis Florent
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

/// Draws a voice recording as amplitude bars that fill as it plays.
///
/// Bars past the playhead are drawn in the muted colour, bars behind it in the
/// accent colour, so the waveform doubles as the progress indicator. Clicking
/// or dragging anywhere on it seeks.
struct WaveformView: View {
    /// Amplitudes on the Matrix 0–1024 scale.
    let amplitudes: [UInt16]

    /// Playback position from 0 to 1.
    let progress: Double

    /// Whether the surrounding bubble uses white text, which flips the palette.
    let usesWhiteText: Bool

    /// Called with a 0–1 fraction when the user clicks or drags.
    let onSeek: (Double) -> Void

    /// How short the quietest bar may get. A recording that dips to silence
    /// should still show a line rather than a gap, otherwise the waveform looks
    /// broken rather than quiet.
    private let minimumBarFraction: CGFloat = 0.12

    private var playedColor: Color { usesWhiteText ? .white : .accentColor }
    private var pendingColor: Color {
        usesWhiteText ? .white.opacity(0.35) : .secondary.opacity(0.35)
    }

    var body: some View {
        GeometryReader { geometry in
            let count = max(amplitudes.count, 1)
            let spacing: CGFloat = 2
            let barWidth = max(1, (geometry.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(amplitudes.enumerated()), id: \.offset) { index, amplitude in
                    let fraction = CGFloat(amplitude) / CGFloat(WaveformExtractor.maximumAmplitude)
                    let height = max(minimumBarFraction, fraction) * geometry.size.height
                    let isPlayed = Double(index) / Double(count) < progress

                    Capsule()
                        .fill(isPlayed ? playedColor : pendingColor)
                        .frame(width: barWidth, height: height)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                // minimumDistance 0 so a plain click seeks without a drag.
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard geometry.size.width > 0 else { return }
                        onSeek(value.location.x / geometry.size.width)
                    }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Waveform")
        .accessibilityValue("\(Int(progress * 100)) percent played")
    }
}
