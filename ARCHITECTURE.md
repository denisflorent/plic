# Architecture

Relay is a native macOS Matrix client built with SwiftUI. It wraps the
[Matrix Rust SDK](https://github.com/matrix-org/matrix-rust-sdk) via
UniFFI-generated Swift bindings, layered through `@Observable` proxy
classes that make the SDK's types suitable for reactive SwiftUI views.

## Dependency Graph

```
MatrixRustSDK              (binary xcframework, via SPM)
       |
RelayKit.framework         (Xcode framework target)
       |                   SDK proxy layer + Relay services & ViewModels
       |
Packages/RelayInterface    (local SPM package, zero dependencies)
       |                   Protocols, models, enums — the API contract
       |
Relay.app                  (SwiftUI app target)
                           Views, preview mocks, utilities
```

### RelayKit.framework

The SDK layer. Everything that touches the Rust binary lives here. It
compiles two sets of sources into a single framework module:

**Proxy layer** — `@Observable` wrappers around every major SDK type,
each paired with a protocol. SDK callback listeners are bridged to
`AsyncStream` via the generic `SDKListener<T>` adapter. List state
(room list, timeline) is maintained by applying VectorDiff operations
through a `DiffEngine`. This code has no UI dependency and no
Relay-specific logic.

**Service layer** — Relay's concrete implementations that consume the
proxies:

- `MatrixService` — the facade that coordinates authentication, sync,
  room list management, media caching, and notification settings behind
  a single `@Environment(\.matrixService)` injection point.
- `TimelineViewModel` and `SessionVerificationViewModel` — view models
  that produce view-ready state from proxy data.
- `TimelineMessageMapper` — converts raw `TimelineItem` arrays into the
  `TimelineMessage` UI model.

RelayKit re-exports the SDK via `@_exported import MatrixRustSDK`, so
consumers that import RelayKit get SDK types transitively.

### Packages/RelayInterface

The interface contract between the framework and the app. A local SPM
package with **zero external dependencies** — pure Swift types that both
RelayKit and the app target import:

- **Protocols** — `MatrixServiceProtocol`, `TimelineViewModelProtocol`,
  `SessionVerificationViewModelProtocol`
- **Enums** — `AuthState`, `SyncState`, `DefaultNotificationMode`,
  `TimelineFocusState`, `VerificationState`
- **Models** — `TimelineMessage`, `RoomSummary` (`@Observable` class
  with last-message preview), `RoomDetails`, `RoomMemberDetails`,
  `DirectoryRoom`, `DeviceInfo`, `EncryptionStatus`, `VerificationEmoji`
- **Utilities** — `KeychainService`, `BlurHash`
- **Environment key** — `@Environment(\.matrixService)`

Because this package has no SDK dependency, Xcode previews that import
only `RelayInterface` never load the Rust binary.

### Relay.app

The application target. Every view file imports `RelayInterface` and
programs against protocols and model types. Only `RelayApp.swift` imports
`RelayKit` to create the concrete `MatrixService` instance.

## Key Design Patterns

### Protocol + Environment Injection

```
MatrixServiceProtocol          (defined in RelayInterface)
    |
    +-- MatrixService          (concrete, in RelayKit, created in RelayApp)
    +-- PreviewMatrixService   (mock, in Relay app, used in #Preview)
```

Views declare `@Environment(\.matrixService) private var matrixService` and
never see the concrete type. Swapping `PreviewMatrixService` for previews
requires no conditional compilation.

### Facade over Focused Sub-Services

`MatrixService` delegates internally to:

| Sub-service              | Responsibility                                 |
|--------------------------|-------------------------------------------------|
| `AuthenticationService`  | Password login, OAuth/OIDC, session restore     |
| `SyncManager`            | `SyncService` lifecycle and state observation    |
| `RoomListManager`        | Incremental room list diffs, room info updates   |
| `MediaService`           | `NSCache`-backed avatar and media fetching       |
| `DirectorySearchService` | Public room directory search                     |

### SDK Listener Bridge

`SDKListener<T>` is a single generic class that conforms to every SDK
listener protocol via conditional extensions. The pattern for consuming
it is:

```swift
let (stream, continuation) = AsyncStream<[TimelineDiff]>.makeStream()
let listener = SDKListener<[TimelineDiff]> { diffs in
    continuation.yield(diffs)
}
let handle = await timeline.addListener(listener: listener)

for await diffs in stream {
    applyDiffs(diffs)
}
```

The `TaskHandle` returned by the SDK subscription must be retained for
the listener to remain active.

### Timeline Message Mapping

The SDK delivers timeline state as an array of `TimelineItem` values.
`TimelineMessageMapper` is a pure function that converts `[TimelineItem]`
into `[TimelineMessage]`, extracting:

- Message kind (text, image, video, audio, file, emote, redacted, ...)
- Media metadata (mxc URL, dimensions, duration, blurhash)
- Aggregated reactions with current-user highlight
- Reply-to context with resolved sender names
- Mention-based highlight detection

The mapper also tracks event IDs whose reply details are still pending
so the view model can call `fetchDetailsForEvent` lazily.

### Room List Enrichment

The SDK's `RoomInfo` does not include a last-message preview or
timestamp. `RoomListManager` enriches each room by:

1. Subscribing to `subscribeToRoomInfoUpdates` for metadata changes.
2. Calling `room.latestEvent()` on each update to extract the latest
   message body (as `AttributedString`) and timestamp.
3. Sorting rooms by `lastMessageTimestamp` descending, with
   timestamp-less rooms sorted alphabetically at the bottom.

The enriched data lives in `RelayInterface.RoomSummary`, an `@Observable`
class distinct from the proxy layer's lightweight `RoomSummary` struct.

## Concurrency Model

- The project uses Swift 6 strict concurrency with
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- All view models and service classes are `@MainActor`-isolated.
- Model structs (`TimelineMessage`, `DeviceInfo`, etc.) mark their inits
  and pure computed properties `nonisolated` so they can be constructed
  from any isolation domain.
- SDK listener callbacks arrive on arbitrary Tokio runtime threads. They
  are bridged to `AsyncStream` and consumed in `Task` blocks on the main
  actor. Proxy properties mutated from listener closures use
  `MainActor.assumeIsolated` where necessary.

## File Overview

```
RelayKit/
  RelayKit.swift              @_exported import MatrixRustSDK
  Documentation.docc/         Framework documentation catalog
  Core/                       SDKListener, DiffEngine, AsyncStreamBridge
  Protocols/                  18 proxy protocol files
  Client/                     ClientProxy, ClientBuilderProxy
  Room/                       JoinedRoomProxy, InvitedRoomProxy, ...
  RoomList/                   RoomSummaryProvider, RoomSummary (struct)
  Sync/                       SyncServiceProxy, RoomListProxy, ...
  Timeline/                   TimelineProxy, TimelineItemProvider
  Encryption/                 EncryptionProxy, UserIdentityProxy
  Verification/               SessionVerificationControllerProxy
  Notifications/              NotificationSettingsProxy, NotificationClientProxy
  Media/                      MediaProxy
  RoomDirectory/              RoomDirectorySearchProxy
  RoomPreview/                RoomPreviewProxy
  Spaces/                     SpaceServiceProxy
  Threads/                    ThreadListServiceProxy
  QRCode/                     QRCodeLoginProxy
  Widget/                     WidgetProxy
  Services/
    MatrixService.swift       Concrete facade implementation
    AuthenticationService.swift
    SyncManager.swift         SyncService lifecycle
    RoomListManager.swift     Reactive room list with enrichment
    TimelineViewModel.swift   Timeline ViewModel
    SessionVerificationViewModel.swift
    TimelineMessageMapper.swift
    MediaService.swift        NSCache media layer
    DirectorySearchService.swift

Packages/RelayInterface/
  Sources/RelayInterface/
    MatrixServiceProtocol.swift   Protocol + AuthState/SyncState + @Environment key
    TimelineViewModelProtocol.swift
    SessionVerificationViewModelProtocol.swift
    TimelineMessage.swift         UI message model (13 content kinds)
    RoomSummary.swift             Enriched room summary (@Observable class)
    RoomDetails.swift             Room metadata + RoomMemberDetails
    DirectoryRoom.swift           Directory search result
    DeviceInfo.swift              Device/session info
    EncryptionStatus.swift        Backup/recovery state
    KeychainService.swift         Keychain read/write
    BlurHash.swift                Image hashing for attachments

Relay/
  RelayApp.swift              App entry point (imports RelayKit)
  ContentView.swift           Routes on AuthState
  Views/                      All SwiftUI views (imports RelayInterface)
  ViewModels/                 Preview mock ViewModels
  Services/                   PreviewMatrixService
  Utilities/                  MatrixHTMLParser, EmojiDetection
```
