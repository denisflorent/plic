# Contributing to Plic

## Building from Source

Plic is a native macOS app built with SwiftUI and Xcode.

### Requirements

- macOS 26.5 or later
- Xcode 27

### Steps

1. Clone the repository:

   ```
   git clone https://github.com/denisflorent/plic.git
   cd plic
   ```

2. Create your local build settings from the template:

   ```
   cp Secrets.xcconfig.example Secrets.xcconfig
   ```

   Set **`DEVELOPMENT_TEAM`** to your Apple Developer Team ID. Find it in
   Xcode under **Settings > Accounts**, or at
   <https://developer.apple.com/account>. `Secrets.xcconfig` is gitignored and
   will not be committed.

3. Open `Relay.xcodeproj` in Xcode. It resolves the Swift package dependencies
   on its own.
4. Select the **Relay** scheme and build (`Cmd+B`) or run (`Cmd+R`).

Run the tests with `Cmd+U`, or from the command line:

```
xcodebuild test -project Relay.xcodeproj -scheme Relay -destination 'platform=macOS'
```

## Project Structure

| Directory | Description |
|---|---|
| `Relay/` | App target -- SwiftUI views and app entry point |
| `RelayKit/` | Framework target -- Matrix Rust SDK integration, services, and view models |
| `Packages/RelayInterface/` | Local Swift package -- shared protocols and model types |
| `RelayShareExtension/` | The Share menu extension |
| `RelayTests/` | Unit tests |

[ARCHITECTURE.md](ARCHITECTURE.md) explains how these fit together.

## Local Homeserver for Screenshots

A seed script is included to spin up a local Matrix homeserver populated with
realistic data. This is useful for taking screenshots, testing UI with real
room/message data, or working on features without connecting to a live server.

### Requirements

- A container runtime ([Docker](https://www.docker.com/),
  [Podman](https://podman.io/), or
  [Apple Containers](https://developer.apple.com/documentation/apple-containers))
- `curl`
- `jq` (`brew install jq`)

### Running the Script

```
./scripts/seed-homeserver.sh
```

To use a different container runtime:

```
CONTAINER_RUNTIME=podman ./scripts/seed-homeserver.sh
```

The script starts a [continuwuity](https://github.com/continuwuity/continuwuity)
homeserver in a container and seeds it with users, spaces, rooms, and messages
for a fictional software company called "Pebble". It takes about 30 seconds to
complete.

### Signing In

After the script finishes, open Plic (Debug build) and sign in on the sign-in
page:

| Field | Value |
|---|---|
| Matrix ID | `@alex:pebble.dev` |
| Password | `pebble123` |
| Homeserver URL | `http://localhost:8008` |

The "Homeserver URL" field is only available in Debug builds.

### User Avatars

Place avatar images in `scripts/profiles/`, named by username (e.g.
`morgan.png`, `priya.jpg`). The script uploads any images it finds and skips
users without one.

### Managing the Server

```
# Stop the server
docker stop relay-homeserver

# Start it again
docker start relay-homeserver

# Delete everything and start fresh
docker rm -v relay-homeserver && docker volume rm relay-homeserver-data
```

Replace `docker` with your container runtime if different.

## Debugging with the Activity Log

Plic includes a built-in Activity Log window for debugging sync and connection
issues. Open it from **Window > Activity Log** (Opt+Cmd+A).

The log captures real-time diagnostic events from the service layer as they
happen, providing an "under the hood" view into the sync pipeline, room list
management, and timeline diff processing. Events accumulate in a 10,000-entry
ring buffer from app launch — the window is purely a viewer, so you won't miss
events that occurred before opening it. The log lives in memory only;
**Export** saves the events currently shown as JSON, to attach to a bug report.

### Event Categories

| Category | Icon | What it captures |
|---|---|---|
| **Sync** | `arrow.triangle.2.circlepath` | Sync service state transitions (idle, syncing, running, offline, error), sleep/wake handling, reconnect scheduling with backoff delays. |
| **Room List** | `list.bullet` | SDK room list diff batches (append, set, remove, reset, etc.) with before/after entry counts, room info updates with unread count deltas, and room list re-sorts. |
| **Timeline** | `text.bubble` | Per-room timeline diff batches with type breakdown and changed-index tracking, message rebuild results, stale generation discards, and pagination status changes. |
| **Network** | `network` | Network path changes from `NWPathMonitor` (connectivity lost/restored). |
| **Auth** | `person.badge.key` | Session restore results (success, offline with saved session, failure) and login state changes. |
| **Call** | `phone.fill` | Call credentials and media server discovery, call membership, connection state, and the exchange of call encryption keys. |
| **Media** | `photo` | Reserved for future media loading instrumentation. |

### Severity Levels

| Level | Meaning |
|---|---|
| **Debug** | Routine operational detail — diff batches, room info updates, pagination events. High volume during normal operation. |
| **Info** | Significant lifecycle milestones — sync started/running, network restored, session restored. |
| **Warning** | Conditions that may indicate problems — network lost, SDK reported offline, sync did not reach running state. |
| **Error** | Failures — sync service terminated, SDK sync error, session restore failure. |

### Interpreting Common Event Sequences

**Normal startup:**
```
[Auth/Info]      Session restored
[Sync/Info]      Starting sync pipeline
[Sync/Info]      Starting sync
[Sync/Info]      Sync state: running
[Sync/Info]      Initial sync reached running state
[Sync/Info]      Sync manager started, starting client observation
[Sync/Info]      Room list manager started
[RoomList/Debug] 42 entry update(s): 0 → 42 entries    (detail: "reset(42)")
[RoomList/Debug] Room list rebuilt: 42 rooms sorted
[Sync/Info]      Space list manager started — sync pipeline complete
```

**Incoming message (timeline active):**
```
[Timeline/Debug] 1 diff(s) in #room:server: 25 → 26 items    (detail: "pushBack")
[Timeline/Debug] Messages updated in #room:server: 21 messages (v5)
```

**Network interruption and recovery:**
```
[Network/Warning]  Network connectivity lost
[Sync/Warning]     Network lost — stopping sync service
[Network/Info]     Network connectivity restored
[Sync/Info]        Network restored — restarting sync service
[Sync/Info]        Sync state: running
[RoomList/Info]    Room list restarted with new sync service
```

**Reconnect with backoff (homeserver unreachable):**
```
[Sync/Error]    SDK sync error
[Sync/Info]     Scheduling reconnect attempt #1    (detail: "Delay: 1.0s ...")
[Sync/Info]     Scheduling reconnect attempt #2    (detail: "Delay: 3.0s ...")
```

**Sleep/wake cycle:**
```
[Sync/Info]     System sleep — tearing down sync service
[Sync/Info]     System wake — rebuilding sync service
[Sync/Info]     Sync state: running
```

### Debugging Missing Messages

The Activity Log is designed to help pinpoint where messages are lost in the
pipeline. When investigating a missing message:

1. **Filter by room** — use the Room toolbar menu to scope events to the
   affected room.
2. **Check timeline diffs** — look for `Timeline/Debug` events showing diff
   batches. Each incoming message should produce a `pushBack` diff and a
   subsequent "Messages updated" event. If the diff arrives but the message
   count doesn't increase, the message mapper may have filtered it (e.g. a
   state event or date divider, not a user message).
3. **Check for stale generation discards** — a "Rebuild discarded (stale
   generation)" event means a mapping result was thrown away because a newer
   diff batch superseded it. This is normal under heavy load but could cause
   a brief delay in message appearance.
4. **Check room list updates** — `RoomList/Debug` events show unread count
   transitions. If the SDK reports an unread count increase but the timeline
   shows no new diff, the message may not yet have been delivered to the
   timeline listener.
5. **Check sync state** — any `Sync/Warning` or `Sync/Error` events around
   the time of the missing message may indicate that sync was interrupted.

### Toolbar Controls

- **Auto-scroll** — when enabled (filled arrow icon), the list follows new
  events. When disabled (slash icon), the list stays at your scroll position.
- **Categories** — toggle which event categories are visible.
- **Severity** — set the minimum severity level to display.
- **Room** — filter events to a specific room.
- **Clear** — empty the event buffer.
- **Inspector** — toggle the detail panel showing full event metadata.

## Submitting Changes

1. Fork the repository and create a branch from `main`.
2. Make your changes. Try to keep commits focused and atomic.
3. Use imperative mood, sentence-case commit messages (e.g. "Add thread support
   to timeline view").
4. Open a pull request against `main` with a clear description of what your
   change does and why.

## Reporting Issues

Open an issue on the [GitHub issue tracker](https://github.com/denisflorent/plic/issues).
Include steps to reproduce the problem, what you expected to happen, and what
actually happened. Screenshots or logs are always helpful.

Report security problems privately instead, as [SECURITY.md](SECURITY.md)
explains.

## License

By contributing to Plic, you agree that your contributions will be licensed
under the [Apache License 2.0](LICENSE).
