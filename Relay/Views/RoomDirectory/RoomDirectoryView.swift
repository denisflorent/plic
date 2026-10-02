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

/// A browsable public rooms directory presented as a sheet.
///
/// ``RoomDirectoryView`` loads popular rooms from the homeserver on appear and
/// provides a search field for finding rooms by name or alias. Joining a room
/// dismisses the sheet and selects it in the sidebar.
struct RoomDirectoryView: View {
    @Environment(\.matrixService) private var matrixService
    @Environment(\.errorReporter) private var errorReporter
    @Environment(\.dismiss) private var dismiss

    /// Bound to the sidebar's selected room ID. Set on successful join.
    @Binding var selectedRoomId: String?

    @State private var viewModel: (any RoomDirectoryViewModelProtocol)?
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var isJoining = false
    @State private var joiningRoomId: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider()
            // Every branch of directoryContent has to fill the space under the
            // header, or the VStack centres itself in the fixed 500-point frame
            // and pushes the header down the sheet. Applying it here rather
            // than per-branch means a future empty state cannot reintroduce it.
            directoryContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 540, height: 500)
        .onChange(of: query) { _, newValue in
            debounceSearch(newValue)
        }
        .onAppear {
            if viewModel == nil {
                viewModel = matrixService.makeRoomDirectoryViewModel()
            }
            searchTask = Task {
                await viewModel?.search(query: nil)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Spacer()

            Text("Public Rooms Directory")
                .fontWeight(.semibold)

            Spacer()

            // Invisible spacer button to balance the header layout.
            Button("Cancel") {}
                .hidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Search Field

    /// The directory's search box.
    ///
    /// An explicit field rather than `.searchable`, which on macOS needs a
    /// navigation container to place its box — this sheet has none, so the
    /// modifier rendered nothing and the directory could not be searched at
    /// all. It also lived on the room list, so it would have been absent
    /// exactly when a server has no rooms to browse and searching is the only
    /// thing left to do.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search public rooms by name or alias", text: $query)
                .textFieldStyle(.plain)
                .onSubmit { performSearch() }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.quaternary, in: .rect(cornerRadius: 6))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Directory Content

    @ViewBuilder
    private var directoryContent: some View {
        if let viewModel {
            if viewModel.rooms.isEmpty && viewModel.isSearching {
                ProgressView("Searching public rooms\u{2026}")
            } else if viewModel.rooms.isEmpty && !viewModel.isSearching {
                ContentUnavailableView(
                    "No Public Rooms Found",
                    systemImage: "magnifyingglass",
                    description: Text(query.isEmpty
                                      ? "No public rooms are available on this server."
                                      : "No public rooms match \"\(query)\". Try a different search.")
                )
            } else {
                roomList(viewModel)
            }
        } else {
            ContentUnavailableView(
                "Public Rooms Directory Unavailable",
                systemImage: "building.2",
                description: Text("Sign in to browse the public rooms directory.")
            )
        }
    }

    // MARK: - Room List

    private func roomList(_ viewModel: any RoomDirectoryViewModelProtocol) -> some View {
        Form {
            Section {
                ForEach(viewModel.rooms) { room in
                    DirectoryRoomRow(
                        room: room,
                        isJoining: joiningRoomId == room.roomId,
                        onJoin: { joinRoom(room) }
                    )
                }

                if !viewModel.rooms.isEmpty, !viewModel.isAtEnd, !viewModel.isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Spacer()
                    }
                    .id(viewModel.rooms.count)
                    .onAppear {
                        Task { await viewModel.loadMore() }
                    }
                }
            } header: {
                Text(query.trimmingCharacters(in: .whitespaces).isEmpty
                     ? "Popular Public Rooms"
                     : "Search Results")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Search Logic

    private func debounceSearch(_ text: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            performSearch()
        }
    }

    private func performSearch() {
        searchTask?.cancel()
        searchTask = Task {
            let trimmed = query.trimmingCharacters(in: .whitespaces)
            await viewModel?.search(query: trimmed.isEmpty ? nil : trimmed)
        }
    }

    // MARK: - Join

    private func joinRoom(_ room: DirectoryRoom) {
        guard !isJoining else { return }
        isJoining = true
        joiningRoomId = room.alias ?? room.roomId

        Task {
            do {
                let idOrAlias = room.alias ?? room.roomId
                try await matrixService.joinRoom(idOrAlias: idOrAlias)

                try? await Task.sleep(for: .milliseconds(500))
                if let joined = matrixService.rooms.first(where: {
                    $0.id == room.roomId || $0.canonicalAlias == room.alias
                }) {
                    selectedRoomId = joined.id
                }
                dismiss()
            } catch {
                errorReporter.report(.roomJoinFailed(error.localizedDescription))
            }
            isJoining = false
            joiningRoomId = nil
        }
    }
}

// MARK: - Directory Room Row

/// A single row in the directory list showing the room avatar, name, topic,
/// member count, and a join button.
private struct DirectoryRoomRow: View {
    let room: DirectoryRoom
    var isJoining: Bool = false
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name ?? room.alias ?? room.roomId)
                    .fontWeight(.medium)
                    .lineLimit(1)

                subtitle
            }

            Spacer()

            if room.memberCount > 0 {
                Label("\(room.memberCount)", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            joinButton
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatar: some View {
        if room.isSpace {
            AvatarView(
                name: room.name ?? room.roomId,
                mxcURL: room.avatarURL,
                size: 36,
                shape: AnyShape(.rect(cornerRadius: 36 * 0.22))
            )
        } else {
            AvatarView(
                name: room.name ?? room.roomId,
                mxcURL: room.avatarURL,
                size: 36
            )
        }
    }

    private var subtitle: some View {
        Group {
            if let topic = room.topic, !topic.isEmpty {
                Text(topic)
            } else if let alias = room.alias {
                Text(alias)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    @ViewBuilder
    private var joinButton: some View {
        if isJoining {
            ProgressView()
                .controlSize(.small)
        } else {
            Button("Join", action: onJoin)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}

// MARK: - Previews

#Preview("Public Rooms Directory") {
    @Previewable @State var selected: String?

    RoomDirectoryView(selectedRoomId: $selected)
        .environment(\.matrixService, PreviewMatrixService())
}
