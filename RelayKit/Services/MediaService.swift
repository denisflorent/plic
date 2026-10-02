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

import AppKit
import CryptoKit
import Foundation
import os
import RelayInterface

private let logger = Logger(subsystem: "RelayKit", category: "Media")

/// Caches and fetches Matrix media content (avatars, thumbnails, and full-resolution media).
///
/// ``MediaService`` wraps the SDK's media download APIs with a two-tier caching strategy:
///
/// 1. **In-memory** – `NSCache` for instant access to recently used images and data.
/// 2. **On-disk, avatars only** – `~/Library/Caches/Relay/avatar-cache/`, for persistence
///    across launches. Avatars are small (~2–10 KB each), rarely change, and are not
///    end-to-end encrypted. Message media persists in the SDK's own encrypted store
///    instead, and is never written to disk in the clear.
///
/// Additionally, in-flight request deduplication ensures that multiple concurrent requests
/// for the same resource share a single network download rather than firing redundant requests
/// (the "thundering herd" problem that occurs during room switches and fast scrolling).
@MainActor
final class MediaService {
    private let avatarCache = NSCache<NSString, NSImage>()
    private let mediaCache = NSCache<NSString, NSData>()

    /// In-flight avatar download tasks keyed by cache key, used to deduplicate
    /// concurrent requests for the same thumbnail.
    private var avatarInflight: [String: Task<NSImage?, Never>] = [:]

    /// In-flight media download tasks keyed by cache key.
    private var mediaInflight: [String: Task<Data?, Never>] = [:]

    /// The on-disk cache directory, which holds avatar thumbnails only.
    ///
    /// Avatars are not end-to-end encrypted in Matrix — the homeserver and every
    /// room member see them — so a plain copy on disk exposes nothing new.
    /// Message media is the opposite, and is kept in memory here and in the
    /// SDK's encrypted store, never in this directory.
    private let diskCacheURL: URL = {
        #if DEBUG
        let subdirectory = "Relay/avatar-cache-debug"
        let legacy = "Relay/media-cache-debug"
        #else
        let subdirectory = "Relay/avatar-cache"
        let legacy = "Relay/media-cache"
        #endif
        // The directory this replaced held decrypted message media in the
        // clear. It is removed outright rather than migrated: nothing in it is
        // worth keeping that the SDK's store and a re-fetch do not provide.
        try? FileManager.default.removeItem(
            at: URL.cachesDirectory.appending(path: legacy, directoryHint: .isDirectory)
        )
        let url = URL.cachesDirectory.appending(path: subdirectory, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// Returns a SHA-256 hex digest of the cache key, safe for use as a filename.
    nonisolated private func diskFileName(for cacheKey: String) -> String {
        let digest = SHA256.hash(data: Data(cacheKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Reads data from the on-disk cache, returning `nil` on miss.
    @concurrent
    private func readDiskCache(key: String) async -> Data? {
        let path = diskCacheURL.appending(path: diskFileName(for: key))
        return try? Data(contentsOf: path)
    }

    /// Writes data to the on-disk cache. Errors are silently ignored.
    @concurrent
    private func writeDiskCache(key: String, data: Data) async {
        let path = diskCacheURL.appending(path: diskFileName(for: key))
        try? data.write(to: path, options: .atomic)
    }

    /// Returns cached avatar image data from the on-disk cache, if available.
    ///
    /// Does not trigger a network download. Used by the room cache writer to
    /// include avatar data in the share extension's room list without blocking.
    ///
    /// - Parameters:
    ///   - mxcURL: The `mxc://` URL of the avatar.
    ///   - size: The display size in points (the cache key uses 2x scale).
    /// - Returns: The cached image data, or `nil` if not cached.
    func cachedAvatarData(mxcURL: String, size: CGFloat) async -> Data? {
        let px = UInt64(size * 2.0)
        let cacheKey = "\(mxcURL)_\(px)"
        return await readDiskCache(key: cacheKey)
    }

    // MARK: - Avatar Thumbnails

    /// Downloads and returns a thumbnail of a Matrix media URL as an `NSImage`.
    ///
    /// Uses a three-tier lookup: in-memory cache → on-disk cache → network download.
    /// Concurrent requests for the same thumbnail are deduplicated so only one network
    /// request is made.
    ///
    /// - Parameters:
    ///   - mxcURL: The `mxc://` URL of the media.
    ///   - size: The desired display size in points (the actual download is at 2x scale).
    ///   - client: The authenticated client proxy.
    /// - Returns: The thumbnail image, or `nil` if the download failed.
    func avatarThumbnail(mxcURL: String, size: CGFloat, client: any ClientProxyProtocol) async -> NSImage? {
        let scale = 2.0
        // swiftlint:disable:next identifier_name
        let px = UInt64(size * scale)
        let cacheKey = "\(mxcURL)_\(px)"

        // 1. In-memory cache hit.
        if let cached = avatarCache.object(forKey: cacheKey as NSString) {
            PerformanceSignposts.media.emitEvent(
                PerformanceSignposts.MediaName.avatarThumbnail,
                "memory hit: \(size)pt"
            )
            return cached
        }

        // 2. Join an in-flight request if one exists for this key.
        if let inflight = avatarInflight[cacheKey] {
            PerformanceSignposts.media.emitEvent(
                PerformanceSignposts.MediaName.avatarThumbnail,
                "joined inflight: \(size)pt"
            )
            return await inflight.value
        }

        // 3. Start a new download task (covers disk check + network).
        let task = Task<NSImage?, Never> { [weak self] in
            guard let self else { return nil }

            let state = PerformanceSignposts.media.beginInterval(
                PerformanceSignposts.MediaName.avatarThumbnail,
                "loading: \(size)pt"
            )

            // 3a. Check on-disk cache (runs off main actor).
            if let diskData = await self.readDiskCache(key: cacheKey),
               let image = ImageDecoding.thumbnail(from: diskData, maxPixelSize: CGFloat(px)) {
                self.avatarCache.setObject(image, forKey: cacheKey as NSString)
                PerformanceSignposts.media.endInterval(
                    PerformanceSignposts.MediaName.avatarThumbnail,
                    state,
                    "disk hit: \(diskData.count) bytes"
                )
                return image
            }

            // 3b. Download from the network.
            do {
                let source = try MediaSource.fromUrl(url: mxcURL)
                let data = try await client.getMediaThumbnail(mediaSource: source, width: px, height: px)
                guard !Task.isCancelled else {
                    PerformanceSignposts.media.endInterval(
                        PerformanceSignposts.MediaName.avatarThumbnail, state, "cancelled"
                    )
                    return nil
                }
                // The hosting server chooses the size — for someone's own
                // avatar, that can be their server. Decode no larger than shown.
                guard let image = ImageDecoding.thumbnail(from: data, maxPixelSize: CGFloat(px)) else {
                    PerformanceSignposts.media.endInterval(
                        PerformanceSignposts.MediaName.avatarThumbnail,
                        state,
                        "failed: invalid image data"
                    )
                    return nil
                }
                self.avatarCache.setObject(image, forKey: cacheKey as NSString)

                // Write to disk cache in the background.
                await self.writeDiskCache(key: cacheKey, data: data)

                PerformanceSignposts.media.endInterval(
                    PerformanceSignposts.MediaName.avatarThumbnail,
                    state,
                    "downloaded \(data.count) bytes"
                )
                return image
            } catch {
                PerformanceSignposts.media.endInterval(
                    PerformanceSignposts.MediaName.avatarThumbnail,
                    state,
                    "error: \(error.localizedDescription)"
                )
                return nil
            }
        }

        avatarInflight[cacheKey] = task
        let result = await task.value
        avatarInflight[cacheKey] = nil
        return result
    }

    // MARK: - Full Media Content

    /// Downloads the full-resolution content of a Matrix media URL.
    ///
    /// Results are cached in memory and on disk. Concurrent requests are deduplicated.
    ///
    /// - Parameters:
    ///   - mxcURL: The `mxc://` URL of the media.
    ///   - mediaSourceJSON: Optional JSON-serialized media source with encryption metadata.
    ///   - client: The authenticated client proxy.
    /// - Returns: The raw media data, or `nil` if the download failed.
    func mediaContent(mxcURL: String, mediaSourceJSON: String? = nil, client: any ClientProxyProtocol) async -> Data? {
        let cacheKey = mxcURL

        // 1. In-memory cache hit.
        if let cached = mediaCache.object(forKey: cacheKey as NSString) {
            PerformanceSignposts.media.emitEvent(
                PerformanceSignposts.MediaName.mediaContent,
                "memory hit: \(cached.count) bytes"
            )
            return cached as Data
        }

        // 2. Join in-flight request.
        if let inflight = mediaInflight[cacheKey] {
            return await inflight.value
        }

        // 3. Start a new download task.
        let task = Task<Data?, Never> { [weak self] in
            guard let self else { return nil }

            let state = PerformanceSignposts.media.beginInterval(
                PerformanceSignposts.MediaName.mediaContent,
                "loading"
            )

            // 3a. Fetch through the SDK, which keeps its own media store
            //     encrypted with the store key — persistence is covered there.
            //     Nothing is written to disk here: a second copy would be the
            //     same content decrypted, in the clear.
            do {
                let source = try Self.makeMediaSource(mxcURL: mxcURL, json: mediaSourceJSON)
                let data = try await client.getMediaContent(mediaSource: source)
                // A logout cancels in-flight fetches. One finishing afterwards
                // must not put the previous session's media back in memory.
                guard !Task.isCancelled else {
                    PerformanceSignposts.media.endInterval(
                        PerformanceSignposts.MediaName.mediaContent, state, "cancelled"
                    )
                    return nil
                }
                self.mediaCache.setObject(data as NSData, forKey: cacheKey as NSString)

                PerformanceSignposts.media.endInterval(
                    PerformanceSignposts.MediaName.mediaContent,
                    state,
                    "downloaded \(data.count) bytes"
                )
                return data
            } catch {
                PerformanceSignposts.media.endInterval(
                    PerformanceSignposts.MediaName.mediaContent,
                    state,
                    "error"
                )
                return nil
            }
        }

        mediaInflight[cacheKey] = task
        let result = await task.value
        mediaInflight[cacheKey] = nil
        return result
    }

    // MARK: - Media Thumbnails

    /// Downloads a thumbnail of a Matrix media URL at the specified pixel dimensions.
    ///
    /// Results are cached in memory only.
    ///
    /// - Parameters:
    ///   - mxcURL: The `mxc://` URL of the media.
    ///   - mediaSourceJSON: Optional JSON-serialized media source with encryption metadata.
    ///   - width: The desired thumbnail width in pixels.
    ///   - height: The desired thumbnail height in pixels.
    ///   - client: The authenticated client proxy.
    /// - Returns: The thumbnail data, or `nil` if the download failed.
    func mediaThumbnail(mxcURL: String, mediaSourceJSON: String? = nil, width: UInt64, height: UInt64, client: any ClientProxyProtocol) async -> Data? {
        let cacheKey = "\(mxcURL)_thumb_\(width)x\(height)"

        if let cached = mediaCache.object(forKey: cacheKey as NSString) {
            PerformanceSignposts.media.emitEvent(
                PerformanceSignposts.MediaName.avatarThumbnail,
                "thumb memory hit: \(width)x\(height)"
            )
            return cached as Data
        }

        // Join in-flight request.
        if let inflight = mediaInflight[cacheKey] {
            return await inflight.value
        }

        let task = Task<Data?, Never> { [weak self] in
            guard let self else { return nil }

            let state = PerformanceSignposts.media.beginInterval(
                PerformanceSignposts.MediaName.avatarThumbnail,
                "thumb loading: \(width)x\(height)"
            )

            // Fetched through the SDK's encrypted media store, like
            // ``mediaContent(mxcURL:mediaSourceJSON:client:)``, and for the same
            // reason never written to disk here: a thumbnail of an encrypted
            // image is that image, decrypted.
            do {
                let source = try Self.makeMediaSource(mxcURL: mxcURL, json: mediaSourceJSON)
                let data = try await client.getMediaThumbnail(mediaSource: source, width: width, height: height)
                guard !Task.isCancelled else {
                    PerformanceSignposts.media.endInterval(
                        PerformanceSignposts.MediaName.avatarThumbnail, state, "thumb cancelled"
                    )
                    return nil
                }
                self.mediaCache.setObject(data as NSData, forKey: cacheKey as NSString)

                PerformanceSignposts.media.endInterval(
                    PerformanceSignposts.MediaName.avatarThumbnail,
                    state,
                    "thumb downloaded \(data.count) bytes"
                )
                return data
            } catch {
                PerformanceSignposts.media.endInterval(
                    PerformanceSignposts.MediaName.avatarThumbnail,
                    state,
                    "thumb error"
                )
                return nil
            }
        }

        mediaInflight[cacheKey] = task
        let result = await task.value
        mediaInflight[cacheKey] = nil
        return result
    }

    // MARK: - Media Source Construction

    /// Creates a ``MediaSource`` from either a JSON-serialized source (preserving encryption
    /// metadata) or a plain `mxc://` URL.
    ///
    /// Encrypted media requires the full JSON representation (containing keys, IV, and hashes)
    /// to be decrypted after download. When `json` is `nil`, falls back to constructing a
    /// plain source from the URL alone.
    nonisolated private static func makeMediaSource(mxcURL: String, json: String?) throws -> MediaSource {
        if let json {
            return try MediaSource.fromJson(json: json)
        }
        return try MediaSource.fromUrl(url: mxcURL)
    }

    // MARK: - Cache Management

    /// Removes all cached avatars and media data (in-memory and on disk).
    ///
    /// Called during logout to ensure stale media from the previous session
    /// is not served after the next login.
    func reset() {
        // Cancelled rather than merely forgotten: a fetch still running would
        // otherwise complete after this and repopulate the caches with the
        // session being signed out of.
        avatarInflight.values.forEach { $0.cancel() }
        mediaInflight.values.forEach { $0.cancel() }
        avatarCache.removeAllObjects()
        mediaCache.removeAllObjects()
        avatarInflight.removeAll()
        mediaInflight.removeAll()

        // Remove disk cache contents.
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: nil
        ) {
            for fileURL in contents {
                try? fm.removeItem(at: fileURL)
            }
        }
    }
}
