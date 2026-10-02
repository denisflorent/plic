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

/// Inline search results displayed in the sidebar, replacing the room list.
///
/// Shows two sections: matching rooms (client-side filtered) and matching
/// messages (from the local index, encrypted rooms included). Each section
/// previews a few results with a "Show More" button to expand; messages
/// arrive in batches, fetched further with "Load More Results".
struct SearchResultsList: View {
    let rooms: [RoomSummary]
    let searchModel: any SearchViewModelProtocol
    @Binding var selectedRoomId: String?
    let onLoadMoreMessages: () -> Void
    let onMessageSelected: (_ roomId: String, _ eventId: String) -> Void

    private let previewLimit = 3

    @State private var showAllRooms = false
    @State private var showAllMessages = false

    var body: some View {
        List(selection: $selectedRoomId) {
            roomsSection
            messagesSection
        }
    }

    // MARK: - Rooms Section

    @ViewBuilder
    private var roomsSection: some View {
        if !rooms.isEmpty {
            Section {
                let visible = showAllRooms ? rooms : Array(rooms.prefix(previewLimit))
                ForEach(visible) { room in
                    RoomListRow(room: room)
                        .tag(room.id)
                }
                if rooms.count > previewLimit {
                    Button {
                        withAnimation { showAllRooms.toggle() }
                    } label: {
                        Text(showAllRooms
                             ? "Show Less"
                             : "Show \(rooms.count - previewLimit) More")
                            .font(.callout)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Label("Rooms", systemImage: "bubble.left.and.bubble.right")
            }
        }
    }

    // MARK: - Messages Section

    @ViewBuilder
    private var messagesSection: some View {
        Section {
            if searchModel.isSearchingMessages {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching\u{2026}")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            if !searchModel.messageResults.isEmpty {
                let visible = showAllMessages
                    ? searchModel.messageResults
                    : Array(searchModel.messageResults.prefix(previewLimit))
                ForEach(visible) { result in
                    MessageSearchRow(result: result) {
                        onMessageSelected(result.roomId, result.eventId)
                    }
                }
                if searchModel.hasMoreMessages,
                   showAllMessages || searchModel.messageResults.count <= previewLimit {
                    Button {
                        onLoadMoreMessages()
                    } label: {
                        Text("Load More Results")
                            .font(.callout)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(searchModel.isSearchingMessages)
                }
                if searchModel.messageResults.count > previewLimit {
                    Button {
                        withAnimation { showAllMessages.toggle() }
                    } label: {
                        Text(showAllMessages
                             ? "Show Less"
                             : "Show \(searchModel.messageResults.count - previewLimit) More")
                            .font(.callout)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }
            } else if !searchModel.isSearchingMessages {
                Text("No messages found.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("Messages", systemImage: "text.magnifyingglass")
        } footer: {
            if !searchModel.messageResults.isEmpty || searchModel.isSearchingMessages {
                Text("Only messages this Mac has received are searched.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Previews

#Preview("With Results") {
    @Previewable @State var selected: String?

    SearchResultsList(
        rooms: Array(PreviewMatrixService.sampleRooms.prefix(5)),
        searchModel: {
            let m = PreviewSearchViewModel()
            m.searchText = "test"
            m.messageResults = PreviewMessageSearchService.sampleResults
            return m
        }(),
        selectedRoomId: $selected,
        onLoadMoreMessages: {},
        onMessageSelected: { _, _ in }
    )
    .environment(\.matrixService, PreviewMatrixService())
    .frame(width: 300, height: 500)
}

#Preview("Searching") {
    @Previewable @State var selected: String?

    SearchResultsList(
        rooms: Array(PreviewMatrixService.sampleRooms.prefix(2)),
        searchModel: {
            let m = PreviewSearchViewModel()
            m.searchText = "test"
            m.isSearchingMessages = true
            return m
        }(),
        selectedRoomId: $selected,
        onLoadMoreMessages: {},
        onMessageSelected: { _, _ in }
    )
    .environment(\.matrixService, PreviewMatrixService())
    .frame(width: 300, height: 500)
}

#Preview("No Results") {
    @Previewable @State var selected: String?

    SearchResultsList(
        rooms: [],
        searchModel: {
            let m = PreviewSearchViewModel()
            m.searchText = "zzzzz"
            return m
        }(),
        selectedRoomId: $selected,
        onLoadMoreMessages: {},
        onMessageSelected: { _, _ in }
    )
    .frame(width: 300, height: 500)
}
