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

/// Shown when the key that encrypted the local data is gone from the Keychain.
///
/// This state is not an error, and presenting it as one would be a lie in the
/// user's disfavour. Plic encrypts everything it caches — the Olm account, the
/// message keys, the search index — with a key held only in this Mac's
/// Keychain and never backed up anywhere. Losing that key is what makes the
/// data unreadable to anyone who takes the disk, and it makes it unreadable to
/// Plic on exactly the same terms. The design worked; the user is simply on
/// the wrong side of it now.
///
/// So the screen says what happened, why it is not recoverable, and what
/// signing in again does and does not bring back. Anything vaguer would leave
/// someone believing their messages were deleted.
struct LocalDataUnreadableView: View {
    let userId: String

    @Environment(\.matrixService) private var matrixService

    @State private var isResetting = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.trianglebadge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: 10) {
                Text("This Mac can no longer read its saved messages")
                    .font(.title2)
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Your messages have not been deleted, and nothing has been exposed.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                explanation(
                    "key.slash",
                    "Plic encrypts everything it stores on this Mac with a key kept in your "
                        + "Keychain. That key is gone — most often after a Keychain reset, a "
                        + "migration to new hardware, or restoring the app from a backup."
                )
                explanation(
                    "lock.shield",
                    "Without it the cached data cannot be decrypted, by Plic or by anyone else. "
                        + "That is the protection working as intended, not a fault."
                )
                explanation(
                    "arrow.clockwise",
                    "Signing in again clears the unreadable cache and downloads your rooms and "
                        + "recent messages from \(homeserverName) afresh."
                )
                explanation(
                    "exclamationmark.triangle",
                    "Older encrypted messages stay unreadable on this Mac unless you restore "
                        + "them from key backup, or verify this device from another one that "
                        + "still has the keys."
                )
            }
            .frame(maxWidth: 460, alignment: .leading)

            VStack(spacing: 8) {
                Button {
                    resetAndSignIn()
                } label: {
                    if isResetting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Clear Local Data and Sign In Again")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isResetting)

                Text(userId)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The homeserver from the user ID, so the text names a place the user
    /// recognises rather than saying "the server".
    private var homeserverName: String {
        userId.split(separator: ":").dropFirst().first.map(String.init) ?? "your homeserver"
    }

    private func explanation(_ symbol: String, _ text: String) -> some View {
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

    private func resetAndSignIn() {
        isResetting = true
        Task {
            await matrixService.signOutAndResetLocalData()
            isResetting = false
        }
    }
}

#Preview {
    LocalDataUnreadableView(userId: "@alice:matrix.org")
        .frame(width: 620, height: 640)
}
