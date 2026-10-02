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

import AVFoundation
import UniformTypeIdentifiers

/// A video held in memory, which AVFoundation plays and inspects without a
/// file.
///
/// The asset's URL uses a scheme AVFoundation cannot fetch itself, so every
/// read comes to this object as a resource-loading request, answered from the
/// decrypted bytes Plic already holds. Keep the object alive for as long as
/// the asset is in use: the resource loader holds its delegate weakly.
nonisolated final class InMemoryAsset: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    let asset: AVURLAsset
    private let data: Data
    private let contentType: String
    /// The resource loader calls back on a dispatch queue of the caller's
    /// choosing — its API, not a preference for GCD.
    private let queue = DispatchQueue(label: "im.plic.in-memory-asset")

    static let scheme = "plic-memory"

    init(data: Data, mimeType: String?, filename: String) {
        self.data = data
        let type = mimeType.flatMap { UTType(mimeType: $0) }
            ?? UTType(filenameExtension: (filename as NSString).pathExtension)
            ?? .movie
        contentType = type.identifier
        // Built from a fixed format and a UUID: always a valid URL.
        let url = URL(string: "\(Self.scheme):///\(UUID().uuidString)")!
        asset = AVURLAsset(url: url)
        super.init()
        asset.resourceLoader.setDelegate(self, queue: queue)
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard loadingRequest.request.url?.scheme == Self.scheme else { return false }

        if let info = loadingRequest.contentInformationRequest {
            info.contentType = contentType
            info.contentLength = Int64(data.count)
            info.isByteRangeAccessSupported = true
        }
        if let request = loadingRequest.dataRequest {
            let start = Int(request.currentOffset)
            let end = request.requestsAllDataToEndOfResource
                ? data.count
                : min(data.count, Int(request.requestedOffset) + request.requestedLength)
            if start < end {
                request.respond(with: data.subdata(in: start..<end))
            }
        }
        loadingRequest.finishLoading()
        return true
    }
}
