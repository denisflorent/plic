<p align="center">
  <img src="https://denisflorent.group/plic/icon-256.png" alt="The Plic app icon: a sealed envelope with a padlock" width="128" height="128">
</p>

<h1 align="center">Plic</h1>

<p align="center">
  A native macOS client for <a href="https://matrix.org">Matrix</a>, written for the Mac rather than carried over from a phone.
</p>

<p align="center">
  <a href="https://denisflorent.group/plic/">Download</a> ·
  <a href="https://denisflorent.group/plic/privacy/">Privacy policy</a> ·
  <a href="https://denisflorent.group/plic/support/">Support</a>
</p>

Plic is a fork of [Relay](https://github.com/subpop/Relay) by Link Dupont,
Andrew Hunter and Lukas Frias Santos. It keeps Relay's SwiftUI interface over
the [Matrix Rust SDK](https://github.com/matrix-org/matrix-rust-sdk), and
develops it further with security as the first concern.

## What it does differently

- **Message keys go only to verified devices.** Room keys are shared only with
  devices signed by their owner's cross-signing identity, and there is no
  setting to turn this off. Call keys go to every device that joins the call.
- **What it keeps is encrypted.** The SDK's stores and the message search index
  are encrypted with a key held in the Keychain, readable only on this Mac and
  never backed up. If the Keychain cannot supply that key, Plic opens nothing.
- **Attachments stay in memory.** Received images, videos, PDFs and voice
  messages are decrypted in memory and shown or played by Plic itself. Nothing
  reaches the disk unless you save it.
- **Links are vetted.** One policy decides which links in a message are
  clickable, and checks again on click. Link previews are off by default.
- **You choose what notifications show.** macOS keeps notifications outside
  Plic's encryption, so they can be limited to the sender's name, or to nothing.
- **Nothing of ours in between.** No analytics, no crash reporting, no
  telemetry, and no server run by us.

[SECURITY.md](SECURITY.md) explains these choices and lists what is still open.

## Requirements

- macOS 26.5 or later, on Apple Silicon
- A Matrix account, on any homeserver

## Building

1. Copy the build settings template, then set `DEVELOPMENT_TEAM` in it to your
   Apple Developer Team ID:

   ```
   cp Secrets.xcconfig.example Secrets.xcconfig
   ```

2. Open `Relay.xcodeproj` in Xcode 27 and build the **Relay** scheme.

The Xcode project, its scheme and the `RelayKit` and `RelayInterface` modules
keep Relay's names, so that changes from upstream stay easy to bring over.
[CONTRIBUTING.md](CONTRIBUTING.md) covers the tests, a local homeserver for
development, and debugging with the Activity Log.

## Publishing your own build

Plic identifies itself to homeservers and to macOS. A build you distribute must
use identifiers of its own:

- `BUNDLE_ID_PREFIX` and `APP_DISPLAY_NAME` in `Secrets.xcconfig`;
- the app group, in both `.entitlements` files and in the two `AppGroup.swift`
  files;
- the OAuth client identity in `OAuthClientIdentity.swift`, and the matching URL
  scheme in `Relay/Info.plist`. An OAuth client must name a domain you control.

## License

Plic's code is licensed under the [Apache License 2.0](LICENSE). Artwork that
comes from Relay, such as the sample avatars in `scripts/profiles`, is licensed
under [CC BY-SA 4.0](LICENSE-CC-BY-SA). [NOTICE](NOTICE) lists the third-party
software Plic includes.
