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

import RelayInterface
import SwiftUI

// MARK: - Verification Sheet

/// A sheet that drives the interactive session verification flow.
///
/// Supports two verification methods:
/// - **SAS emoji comparison** — compare emoji across two devices.
/// - **Recovery key** — enter the account's security key to verify directly.
///
/// When no other verified devices are available, recovery key entry is shown
/// as the primary option. Otherwise both methods are offered side-by-side.
struct VerificationSheet: View {
    var viewModel: any SessionVerificationViewModelProtocol
    @Environment(\.dismiss) private var dismiss
    @State private var recoveryKeyInput = ""

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .idle:
                idleView
            case .requesting, .waitingForOtherDevice, .sasStarted:
                waitingView
            case .waitingForApproval:
                approvingView
            case .showingEmojis:
                emojiView
            case .enteringRecoveryKey:
                recoveryKeyView
            case .recoveringWithKey:
                recoveringView
            case .verified:
                resultView(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    title: "Verified!",
                    detail: "This session has been successfully verified."
                )
            case .cancelled:
                resultView(
                    icon: "xmark.circle.fill",
                    color: .secondary,
                    title: "Cancelled",
                    detail: "Verification was cancelled."
                )
            case .failed(let message):
                resultView(
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    title: "Verification Failed",
                    detail: message
                )
            }
        }
        .frame(width: 380, height: 340)
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Verify Session")
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.hasOtherDevices {
                Text("Choose how to verify this session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else {
                Text("Enter your security key to verify this session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()

                if viewModel.hasOtherDevices {
                    Button("Use Security Key") {
                        viewModel.startRecoveryKeyEntry()
                    }
                    Button("Another Device") {
                        Task { await viewModel.requestVerification() }
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Another Device") {
                        Task { await viewModel.requestVerification() }
                    }
                    Button("Use Security Key") {
                        viewModel.startRecoveryKeyEntry()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
    }

    // MARK: - Waiting

    private var waitingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Waiting for Other Device")
                .font(.title3)
                .fontWeight(.medium)
            Text("Accept the verification request on your other device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            HStack {
                Spacer()
                Button("Cancel") {
                    Task { await viewModel.cancelVerification() }
                }
            }
            .padding()
        }
    }

    // MARK: - Approving

    private var approvingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Completing Verification")
                .font(.title3)
                .fontWeight(.medium)
            Text("Waiting for the other device to confirm.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Recovery Key Entry

    private var recoveryKeyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("Enter Security Key")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Enter the security key you received when setting up account recovery.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            SecureField("Security Key", text: $recoveryKeyInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 32)
                .onSubmit {
                    guard !recoveryKeyInput.isEmpty else { return }
                    Task { await viewModel.submitRecoveryKey(recoveryKeyInput) }
                }

            Spacer()
            HStack {
                Button("Back") {
                    recoveryKeyInput = ""
                    viewModel.resetToIdle()
                }
                Spacer()
                Button("Verify") {
                    Task { await viewModel.submitRecoveryKey(recoveryKeyInput) }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(recoveryKeyInput.isEmpty)
            }
            .padding()
        }
    }

    // MARK: - Recovering with Key

    private var recoveringView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Verifying with Security Key")
                .font(.title3)
                .fontWeight(.medium)
            Text("Recovering encryption keys from the server.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Emoji Comparison

    private var emojiView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Compare Emoji")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Confirm that the following emoji appear on both devices, in the same order.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                let topRow = Array(viewModel.emojis.prefix(4))
                let bottomRow = Array(viewModel.emojis.dropFirst(4))
                HStack(spacing: 0) {
                    ForEach(topRow) { emoji in
                        emojiCell(emoji)
                            .frame(maxWidth: .infinity)
                    }
                }
                HStack(spacing: 0) {
                    ForEach(bottomRow) { emoji in
                        emojiCell(emoji)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Spacer()
            HStack {
                Button("They Don\u{2019}t Match", role: .destructive) {
                    Task { await viewModel.declineVerification() }
                }
                Spacer()
                Button("They Match") {
                    Task { await viewModel.approveVerification() }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

    private func emojiCell(_ emoji: VerificationEmoji) -> some View {
        VStack(spacing: 4) {
            Text(emoji.symbol)
                .font(.system(size: 32))
            Text(emoji.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Result

    private func resultView(icon: String, color: Color, title: String, detail: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(color)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }

}
