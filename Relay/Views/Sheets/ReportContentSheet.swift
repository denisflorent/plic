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

/// Reports a message to the moderators of the sender's homeserver, optionally
/// blocking the sender at the same time.
///
/// App Store guideline 1.2 requires a reporting path for user-generated
/// content, and a client that federates with arbitrary servers needs one on its
/// own merits.
///
/// The sheet states plainly that moderators cannot read encrypted content. That
/// sentence is the whole ethical weight of this screen: someone reporting abuse
/// is entitled to know that the admin will see an event ID and their reason,
/// not the message. Hiding that would let them believe an intervention is
/// coming that cannot come.
struct ReportContentSheet: View {
    let message: TimelineMessage
    let roomId: String

    @Environment(\.matrixService) private var matrixService
    @Environment(\.errorReporter) private var errorReporter
    @Environment(\.dismiss) private var dismiss

    @State private var reason = ""
    @State private var blockSender = false
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    reasonField
                    blockToggle
                }
                .padding(20)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: 420, height: 380)
        .background(.regularMaterial)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .disabled(isSending)

            Spacer()

            Text("Report Content")
                .font(.headline)

            Spacer()

            Button("Send") {
                Task { await send() }
            }
            .buttonStyle(.borderedProminent)
            // A report with no reason tells a moderator nothing they can act
            // on, and in an encrypted room it is all they will ever have.
            .disabled(isSending || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay {
            if isSending {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var reasonField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $reason)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 110)
                .background(.quinary, in: .rect(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if reason.isEmpty {
                        Text("Reason for reporting this content")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            Text(
                "This message will be reported to your homeserver's administrator. "
                    + "They will not be able to read any encrypted message."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var blockToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Block user", isOn: $blockSender)
                .toggleStyle(.switch)

            Text("Check if you would like to hide all current and future messages from this user.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func send() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await matrixService.reportContent(
                roomId: roomId,
                eventId: message.eventID,
                reason: trimmed
            )
        } catch {
            errorReporter.report(.reportFailed(error.localizedDescription))
            return
        }

        // Blocking is attempted only after the report lands. Reversing the
        // order would leave the user blocked with nothing filed if the report
        // failed — the opposite of what they asked for.
        if blockSender {
            do {
                try await matrixService.ignoreUser(userId: message.senderID)
            } catch {
                errorReporter.report(.reportFailed(error.localizedDescription))
                return
            }
        }

        dismiss()
    }
}
