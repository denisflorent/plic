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

/// A vertical icon rail on the leading edge of the sidebar for switching between spaces.
///
/// Each top-level space is represented by a rounded-rectangle avatar. When a space is
/// selected, any joined sub-spaces expand out below it with smaller icons, pushing
/// other spaces down. Clicking Home or a different space collapses the previous group.
struct SpaceRail: View {
    /// The fixed width of the space rail column.
    static let width: CGFloat = 52

    @Environment(\.matrixService) private var matrixService
    @Binding var selectedSpaceId: String?
    var onSpaceTapped: (() -> Void)?
    var onCreateSpace: (() -> Void)?
    var onLeaveSpace: ((RoomSummary) -> Void)?
    var onOpenSettings: ((RoomSummary) -> Void)?
    var onInvite: ((RoomSummary) -> Void)?

    /// Top-level spaces (those not nested inside another joined space).
    private var topLevelSpaces: [RoomSummary] {
        matrixService.spaces.filter { $0.parentSpaceIds.isEmpty }
    }

    /// All joined sub-spaces that belong to the given top-level space, at any depth.
    ///
    /// This flattens the hierarchy so that a chain like Work → Engineering → Backend
    /// shows Engineering and Backend as peers under Work in the rail.
    private func subSpaces(of parentId: String) -> [RoomSummary] {
        matrixService.spaces.filter {
            !$0.parentSpaceIds.isEmpty && $0.parentSpaceIds.contains(parentId)
        }
    }

    /// Whether a top-level space should show its sub-spaces (the space itself or any
    /// of its sub-spaces at any depth is currently selected).
    private func isExpanded(_ spaceId: String) -> Bool {
        guard let selectedSpaceId else { return false }
        if selectedSpaceId == spaceId { return true }
        // Check if the selected space is a sub-space of this top-level space
        return subSpaces(of: spaceId).contains(where: { $0.id == selectedSpaceId })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                homeButton

                if !matrixService.spaces.isEmpty {
                    SpaceRailDivider()
                }

                ForEach(topLevelSpaces) { space in
                    spaceButton(space)

                    // Expanded sub-spaces
                    if isExpanded(space.id) {
                        let children = subSpaces(of: space.id)
                        if !children.isEmpty {
                            ForEach(children) { child in
                                subSpaceButton(child)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                                        removal: .scale(scale: 0.5).combined(with: .opacity)
                                    ))
                            }
                        }
                    }
                }

                SpaceRailDivider()

                Button {
                    onCreateSpace?()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(.fill.tertiary, in: .rect(cornerRadius: 10))
                        .contentShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create Space")
            }
            // Top inset is larger than the bottom on purpose: it drops the home
            // button until its centre lines up with the centre of the first row
            // in the room list, which sits lower because of the list's own row
            // insets. Tuned by eye against that alignment — if the room row's
            // padding changes, this needs revisiting.
            .padding(.top, 14)
            .padding(.bottom, 8)
            .animation(.easeInOut(duration: 0.25), value: selectedSpaceId)
        }
        .scrollIndicators(.hidden)
        .frame(width: Self.width)
        .accessibilityLabel("Spaces")
    }

    // MARK: - Buttons

    private var homeButton: some View {
        SpaceRailButton(
            isSelected: selectedSpaceId == nil
        ) {
            onSpaceTapped?()
            selectedSpaceId = nil
        } label: {
            Image(systemName: "house.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(selectedSpaceId == nil ? .white : .secondary)
                .frame(width: 36, height: 36)
                .background(
                    selectedSpaceId == nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary),
                    in: .rect(cornerRadius: 10)
                )
                .animation(.easeInOut(duration: 0.15), value: selectedSpaceId == nil)
        }
        .accessibilityLabel("All Rooms")
    }

    private func spaceButton(_ space: RoomSummary) -> some View {
        SpaceRailButton(
            isSelected: selectedSpaceId == space.id
        ) {
            onSpaceTapped?()
            selectedSpaceId = space.id
        } label: {
            AvatarView(name: space.name, mxcURL: space.avatarURL, size: 36, shape: AnyShape(.rect(cornerRadius: 36 * 0.22)))
        }
        .overlay(alignment: .topTrailing) {
            spaceUnreadBadge(for: space)
                .offset(x: -2, y: 2)
        }
        .contextMenu {
            Button("Space Settings\u{2026}", systemImage: "gearshape") {
                onOpenSettings?(space)
            }
            Button("Invite to Space\u{2026}", systemImage: "person.badge.plus") {
                onInvite?(space)
            }
            Divider()
            Button("Leave Space", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                onLeaveSpace?(space)
            }
        }
    }

    private func subSpaceButton(_ space: RoomSummary) -> some View {
        SpaceRailButton(
            isSelected: selectedSpaceId == space.id
        ) {
            onSpaceTapped?()
            selectedSpaceId = space.id
        } label: {
            AvatarView(name: space.name, mxcURL: space.avatarURL, size: 26, shape: AnyShape(.rect(cornerRadius: 26 * 0.22)))
        }
        .overlay(alignment: .topTrailing) {
            spaceUnreadBadge(for: space)
                .offset(x: -2, y: 2)
        }
        .contextMenu {
            Button("Space Settings\u{2026}", systemImage: "gearshape") {
                onOpenSettings?(space)
            }
            Button("Invite to Space\u{2026}", systemImage: "person.badge.plus") {
                onInvite?(space)
            }
            Divider()
            Button("Leave Space", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                onLeaveSpace?(space)
            }
        }
    }

    // MARK: - Helpers

    /// A colored dot badge for the space icon, or nothing when there are no unreads.
    @ViewBuilder
    private func spaceUnreadBadge(for space: RoomSummary) -> some View {
        if let color = spaceUnreadColor(space) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
    }

    /// The badge color for unread activity in a space, or `nil` when there are no unreads.
    ///
    /// Returns red when any child room has unread mentions, keyword highlights, or is a
    /// DM with unread messages. Returns accent color for plain unread messages in group rooms.
    private func spaceUnreadColor(_ space: RoomSummary) -> Color? {
        var hasUnread = false
        var hasHighPriority = false

        for room in matrixService.rooms where room.parentSpaceIds.contains(space.id) && !room.isMuted {
            if room.highlightCount > 0 || (room.isDirect && room.notificationCount > 0) {
                hasHighPriority = true
                break
            }
            if room.notificationCount > 0 {
                hasUnread = true
            }
        }

        if hasHighPriority { return .red }
        if hasUnread { return .accentColor }
        return nil
    }
}

/// A single button in the space rail with selection indicator and unread badge.
struct SpaceRailButton<Label: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .scaleEffect(isSelected ? 1.08 : 1.0)
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? AnyShapeStyle(.tint.opacity(0.5)) : AnyShapeStyle(.clear))
                }
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A short horizontal line separating the Home button from space icons.
struct SpaceRailDivider: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(.quaternary)
            .frame(width: 24, height: 2)
    }
}

// MARK: - Previews

#Preview("With Spaces") {
    @Previewable @State var selectedSpace: String?
    SpaceRail(selectedSpaceId: $selectedSpace)
        .environment(\.matrixService, PreviewMatrixService())
        .frame(height: 400)
        .background(.background)
}

#Preview("No Spaces") {
    @Previewable @State var selectedSpace: String?
    SpaceRail(selectedSpaceId: $selectedSpace)
        .frame(height: 300)
        .background(.background)
}
