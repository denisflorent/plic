# Security posture

What Plic does today, what it deliberately does not do, and what is still open.
Last reviewed 2026-10-02. Keep it honest — this file is worth nothing if it drifts.

## Reporting a vulnerability

Please report security problems privately, by email, rather than in a public
issue. The address is on the [support page](https://denisflorent.group/plic/support/).

## Room keys go only to signed devices

`AuthenticationService.makeBuilder()` sets:

```swift
.roomKeyRecipientStrategy(.identityBasedStrategy)
```

This is the strategy [MSC4153] recommends, and the one Element runs in its
"exclude insecure devices" mode: room keys are distributed only to devices
signed by their owner's published cross-signing identity. A user who has never
set up cross-signing receives no keys at all.

Without this call the SDK falls back to a strategy that still shares with
unsigned devices. Element switches the strict behaviour on in **October 2026**;
Plic ships with it on, so an unverified device never receives keys rather than
receiving them until a deadline passes.

There is deliberately **no setting to turn this off**. A toggle that weakens key
distribution is a toggle an attacker can talk a user into flipping.

[MSC4153]: https://github.com/matrix-org/matrix-doc/pull/4153

## Session tokens and the store key

`KeychainService` writes both the session and the store key with
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Readable only while the Mac is
unlocked, excluded from backups, and never migrated to another machine — a
Matrix session token grants full account access and should not survive a restore
onto hardware the user no longer controls.

Every query also sets **`kSecUseDataProtectionKeychain: true`**. This is not
cosmetic. Without it macOS writes to the legacy file-based keychain, which
accepts `kSecAttrAccessible` and then ignores it — the hardening above would
have been a no-op. `StoreKeyTests.storeKeyIsThisDeviceOnly()` reads the
attribute back so this cannot silently regress.

`save(_:)` updates in place and only adds when nothing exists — the previous
delete-then-add destroyed the stored session before attempting the new write,
so a transient failure during an OIDC token refresh logged the user out. A
failed update leaves the old value untouched. `loadOrCreateStoreKey` treats
`errSecDuplicateItem` as "read the existing key back", never as a reason to
hand callers `nil` — which they would interpret as "open the store
unencrypted". And `purgeLegacyItems()` runs at startup to delete session
tokens that pre-data-protection builds left in the legacy keychain, where
`ThisDeviceOnly` was silently ignored and the token rode along in backups.

## The local stores are encrypted at rest

`AuthenticationService.makeBuilder()` opens the SDK's SQLite stores through
`encryptedSqliteStore(dataPath:cachePath:key:)`, passing 256 bits of
`SecRandomCopyBytes` material held in the Keychain. The stores hold the Olm
account, Megolm sessions and device keys — the material that makes past
messages readable. Unencrypted, FileVault protects them only while the Mac is
powered off.

Encryption is value-level, not whole-file: `matrix-sdk-sqlite` uses
`StoreCipher` and links `rusqlite` without SQLCipher, so the `.sqlite3` files
keep an ordinary SQLite header and schema while their stored values are
ciphertext. Checking the file header proves nothing either way — search the
files for known message text instead. Verified 2026-08-01: no plaintext message
content appears in the state, crypto, event-cache or media stores, nor anywhere
else under the app container.

If the Keychain cannot supply the key, Plic opens nothing: it does not fall
back to an unencrypted store, and it says why instead of starting. The search
index follows the same rule — no key, no index.

## Received content is handled with suspicion

- **Attachments never reach the disk decrypted.** Images, PDFs and videos open
  in Plic's own viewer, and audio plays in place, all from memory. Any other
  file is offered for saving, and written only where the user chooses.
  Decrypted copies left by older versions are deleted at launch.
- **Images are decoded at display size.** ImageIO thumbnails replace
  `NSImage(data:)`, so a small file that expands to a huge bitmap costs a few
  megabytes instead of hundreds.
- **Message HTML is bounded.** Nesting deeper than 20 containers, or more than
  2,000 Markdown markers, is shown as plain text rather than parsed, so one
  message cannot freeze the interface.
- **One link policy.** Only `https`, `http`, `ftp`, `mailto`, `magnet` and
  `matrix` links are clickable, wherever the link comes from — HTML, Markdown
  or a bare address — and the scheme is checked again on click.
- **Link previews are off by default.** When turned on, Plic loads the linked
  page itself, so the site sees the user's IP address. Links that name a local
  address are never previewed.

## Notifications and the Share menu

macOS keeps delivered notifications in its own database, outside Plic's
encryption. By default a notification shows the sender and the message;
Settings > Notifications can limit it to the sender's name, or to nothing.

For the Share menu, Plic suggests conversations to macOS — each room's name,
and the sender's name for a message received — and writes the share
extension a list of rooms with their names and avatars. Signing out withdraws
the suggestions and deletes the list. Choosing to show nothing in
notifications stops the suggestions altogether, and withdraws those already
made.

## Calls

Calls use MatrixRTC over a LiveKit media server — the one used by whoever
started the call. In an encrypted room, media is end-to-end encrypted, and the
key goes, encrypted, only to the devices that hold a membership in the call,
whether or not they are verified. Calls in an unencrypted room are not
end-to-end encrypted.

## Already correct upstream — verified, not assumed

- Hardened runtime, App Sandbox, user-script sandboxing, dead-code stripping and
  binary stripping are all enabled.
- `autoEnableCrossSigning(true)` and `autoEnableBackups(true)`.
- `enableShareHistoryOnInvite` (MSC4268, experimental) is **not** called, so
  encrypted history is not shared when inviting someone.
- `disableSslVerification()` and `disableBuiltInRootCertificates()` are never
  called.

## Entitlements — audited, nothing removed

| Entitlement | Why it stays |
|---|---|
| `network.client` | Required for all homeserver traffic. |
| `network.server` | WebRTC/ICE binds local sockets and accepts inbound peer traffic for MatrixRTC calls. Removing it breaks calls. |
| `device.camera`, `device.audio-input` | Video and voice calls. |
| `files.user-selected.read-write` | Attachments via the file picker and drag-and-drop. |
| `application-groups` | Shared container between the app and the share extension; also the Keychain access group. |

Nothing here is removable without removing a feature. If calls are ever cut,
`network.server` should go with them.

## Open — not done, and why

- **The interactive verification flow has no test coverage.** The *posture* now
  does: `SecurityPolicyTests` reads the builder's configuration record and fails
  if `.identityBasedStrategy`, store encryption, the encrypted search index or
  the Plic user agent ever stop reaching the SDK, and
  `CompliancePostureTests` holds the privacy manifest and the shipped licence
  documents. What remains untested is the live SAS/emoji verification exchange
  itself, which needs two devices and a homeserver.
- **The store key still has no recovery path**, which is correct: a key that
  can be recovered from elsewhere is a key an attacker can recover too. What has
  changed is that the app no longer *appears* to have lost the messages.
  `AuthenticationService.restoreSession()` checks for store data with no key
  before it builds a client and returns `.localDataUnreadable`, and
  `LocalDataUnreadableView` explains what happened, why it is not recoverable,
  and what signing in again does and does not bring back. Detection is
  deterministic rather than error-string matching: `KeychainService.hasStoreKey()`
  answers without minting a key, which `loadOrCreateStoreKey()` cannot do.
- **The call key is never rotated.** It is generated once per call, so someone
  who leaves keeps the key for the rest of the call. Element Call rotates it
  when a participant leaves; doing the same needs testing with three
  participants.
- **Previews can still reach the local network.** A public name that resolves
  or redirects to a local address is fetched anyway, because LinkPresentation
  follows it without asking. This is one reason previews are off by default.
- **No independent review.** Plic has not been audited by a third party.
- **Reproducible builds with published hashes** are what separate an app that
  claims to be secure from one that demonstrates it.
