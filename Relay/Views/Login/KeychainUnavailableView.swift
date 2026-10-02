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

import RelayInterface
import SwiftUI

/// Shown when the Keychain will not supply what Plic needs to open its data.
///
/// Plic encrypts everything it stores with a key held in the Keychain, and
/// keeps the session there too. When the Keychain does not answer, the only
/// alternatives to this screen are worse: storing messages unencrypted, or
/// treating a key that may well exist as lost — whose recovery clears data
/// the key could still open. So Plic opens nothing, says why, and lets the
/// user try again. Nothing is deleted by trying.
struct KeychainUnavailableView: View {
    @Environment(\.matrixService) private var matrixService

    @State private var isRetrying = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("Plic can’t reach your Keychain")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Nothing has been lost, and nothing has been stored unprotected.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                ExplanationRow(
                    symbol: "key.horizontal",
                    text: "Plic encrypts everything it keeps on this Mac with a key held in your "
                        + "Keychain, and keeps your session there too. The Keychain didn’t "
                        + "provide them just now."
                )
                ExplanationRow(
                    symbol: "hand.raised",
                    text: "Plic won’t store your messages without that protection, so it has "
                        + "opened nothing rather than fall back to keeping them in the clear."
                )
                ExplanationRow(
                    symbol: "arrow.clockwise",
                    text: "This is usually temporary. Trying again changes nothing on disk. If it "
                        + "keeps happening, restarting your Mac normally restores access."
                )
            }
            .frame(maxWidth: 460, alignment: .leading)

            Button {
                retry()
            } label: {
                if isRetrying {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Try Again")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isRetrying)

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func retry() {
        isRetrying = true
        Task {
            await matrixService.restoreSession()
            isRetrying = false
        }
    }
}

/// One line of the explanation: a symbol and the sentence beside it.
private struct ExplanationRow: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    KeychainUnavailableView()
        .frame(width: 620, height: 560)
}
