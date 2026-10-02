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
import UniformTypeIdentifiers

/// The Account tab of the Settings window, displaying the user's profile avatar,
/// display name, user ID, account info, and logout/cache actions.
struct SettingsAccountTab: View {
    @Environment(\.matrixService) private var matrixService
    @Environment(\.errorReporter) private var errorReporter

    @State private var displayName = ""
    @State private var savedDisplayName = ""
    @State private var avatarURL: String?
    @State private var isEditingDisplayName = false
    @State private var editedDisplayName = ""
    @State private var showImagePicker = false
    @State private var showLogoutConfirmation = false
    @State private var showClearCacheConfirmation = false
    @State private var profileURL: URL?
    @State private var deactivateURL: URL?

    private var userId: String? { matrixService.userId() }

    private var resolvedDisplayName: String {
        displayName.isEmpty ? (userId ?? "?") : displayName
    }

    /// Links out to the homeserver's own account pages, including deletion.
    ///
    /// App Store guideline 5.1.1(v) requires an app that offers account
    /// creation to offer deletion. On Matrix the account belongs to the
    /// homeserver, not to Plic, so the honest implementation sends the user
    /// where the account actually lives — the approach Element X takes.
    ///
    /// Only servers using next-generation auth publish these URLs. On a legacy
    /// password server the section stays hidden rather than offering a link
    /// that goes nowhere.
    @ViewBuilder
    private var manageAccountSection: some View {
        if profileURL != nil || deactivateURL != nil {
            Section {
                if let profileURL {
                    Link(destination: profileURL) {
                        Label("Account Settings", systemImage: "person.crop.circle")
                    }
                }
                if let deactivateURL {
                    Link(destination: deactivateURL) {
                        Label("Delete Account", systemImage: "trash")
                    }
                    .tint(.red)
                }
            } header: {
                Text("Manage Account")
            } footer: {
                Text("These pages are hosted by your homeserver, and open in your browser.")
            }
        }
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    AvatarView(
                        name: resolvedDisplayName,
                        mxcURL: avatarURL,
                        size: 80,
                        colorID: userId
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Button { showImagePicker = true } label: {
                            Image(systemName: "camera.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(.tint, in: .circle)
                        }
                        .buttonStyle(.plain)
                        .help("Change photo")
                    }
                    .overlay(alignment: .bottomLeading) {
                        if avatarURL != nil {
                            Button {
                                Task { await removeAvatar() }
                            } label: {
                                Image(systemName: "trash.fill")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(.red, in: .circle)
                            }
                            .buttonStyle(.plain)
                            .help("Remove photo")
                        }
                    }

                    VStack(spacing: 2) {
                        Text(displayName.isEmpty ? "Not set" : displayName)
                            .font(.title2)
                            .bold()

                        if let userId {
                            Text(userId)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Account Info") {
                LabeledContent("Display Name") {
                    if isEditingDisplayName {
                        HStack(spacing: 6) {
                            TextField("Display Name", text: $editedDisplayName)
                                .textFieldStyle(.roundedBorder)
                                .labelsHidden()
                                .onSubmit { saveDisplayName() }

                            Button("Save Display Name", systemImage: "checkmark.circle.fill") {
                                saveDisplayName()
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.tint)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text(displayName.isEmpty ? "Not set" : displayName)
                                .foregroundStyle(displayName.isEmpty ? .secondary : .primary)

                            Button("Edit Display Name", systemImage: "pencil") {
                                editedDisplayName = displayName
                                isEditingDisplayName = true
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                if let userId {
                    CopyableLabeledContent("User ID", value: userId)
                }
                if let homeserver = matrixService.homeserverAddress() {
                    CopyableLabeledContent("Homeserver", value: homeserver)
                }
                if let deviceId = matrixService.deviceId() {
                    CopyableLabeledContent("Device ID", value: deviceId)
                }
            }

            Section {
                HStack {
                    Button("Clear Cache…") {
                        showClearCacheConfirmation = true
                    }
                    Spacer()
                    Button("Log Out…", role: .destructive) {
                        showLogoutConfirmation = true
                    }
                    .tint(.red)
                }

            }

            manageAccountSection
        }
        .formStyle(.grouped)
        .task(id: matrixService.syncState) {
            guard matrixService.syncState == .running else { return }
            let name = await matrixService.userDisplayName() ?? ""
            displayName = name
            savedDisplayName = name
            avatarURL = await matrixService.userAvatarURL()

            // Resolved once the session is live: the URLs come from the
            // homeserver's OIDC metadata, which is unavailable before sync.
            profileURL = await accountURL(for: .profile)
            deactivateURL = await accountURL(for: .deactivate)
        }
        .fileImporter(
            isPresented: $showImagePicker,
            allowedContentTypes: [.png, .jpeg, .gif],
            allowsMultipleSelection: false
        ) { result in
            handleImageSelection(result)
        }
        .alert("Log Out", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                Task { await matrixService.logout() }
            }
        } message: {
            Text("Are you sure you want to log out? You will need to sign in again.")
        }
        .alert("Clear Cache", isPresented: $showClearCacheConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Cache", role: .destructive) {
                Task { await matrixService.clearLocalData() }
            }
        } message: {
            Text(
                "This will delete all locally cached data and resync from the server. You will remain logged in."
            )
        }
    }

    // MARK: - Actions

    private func saveDisplayName() {
        let trimmed = editedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != savedDisplayName else {
            isEditingDisplayName = false
            return
        }
        Task {
            do {
                try await matrixService.setDisplayName(trimmed)
                displayName = trimmed
                savedDisplayName = trimmed
            } catch {
                errorReporter.report(.displayNameUpdateFailed(error.localizedDescription))
            }
            isEditingDisplayName = false
        }
    }

    /// Asks the homeserver for one of its account pages.
    ///
    /// Failures are swallowed on purpose: a server that publishes no such URL
    /// is the normal case on legacy auth, not an error worth interrupting the
    /// user over. The section simply does not appear.
    private func accountURL(for action: AccountAction) async -> URL? {
        guard let string = try? await matrixService.accountManagementURL(action: action) else {
            return nil
        }
        return URL(string: string)
    }

    private func handleImageSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url) else { return }
        let ext = url.pathExtension.lowercased()
        let mimeType: String = switch ext {
        case "png": "image/png"
        case "gif": "image/gif"
        default: "image/jpeg"
        }
        Task {
            do {
                try await matrixService.uploadUserAvatar(mimeType: mimeType, data: data)
                avatarURL = await matrixService.userAvatarURL()
            } catch {
                errorReporter.report(.avatarUpdateFailed(error.localizedDescription))
            }
        }
    }

    private func removeAvatar() async {
        do {
            try await matrixService.removeUserAvatar()
            avatarURL = nil
        } catch {
            errorReporter.report(.avatarUpdateFailed(error.localizedDescription))
        }
    }
}

// MARK: - Copyable Labeled Content

/// A read-only labeled row with a copy button, used for account info fields.
private struct CopyableLabeledContent: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        LabeledContent(label) {
            HStack(spacing: 6) {
                Text(value)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Button("Copy \(label)", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TabView {
        SettingsAccountTab()
            .tabItem { Label("Account", systemImage: "person.crop.circle") }
    }
    .environment(\.matrixService, PreviewMatrixService())
    .frame(width: 480)
}
