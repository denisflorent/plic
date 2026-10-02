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

import AppKit
import ImageIO

/// Decodes received images at the size they are shown, never at the size the
/// sender chose.
///
/// `NSImage(data:)` decodes the full bitmap as soon as the image is drawn. In
/// an encrypted room the server cannot make a thumbnail — it holds only
/// ciphertext — so the pixel size is entirely the sender's. Measured: a
/// 660 KB PNG of 12,000 × 12,000 pixels cost 160 MB drawn at 300 points,
/// against 3 MB decoded here. In colour, or at 30,000 pixels a side, one
/// message would take gigabytes. ImageIO's thumbnail path subsamples while
/// decoding and never allocates the full-size bitmap.
public enum ImageDecoding {
    /// An animated image is only animated below this many pixels per frame:
    /// each frame is decoded at full size.
    public static let maximumAnimatedPixels = 2_048 * 2_048

    /// The image, scaled so its longest side is at most `maxPixelSize`, with
    /// its orientation applied. `nil` if the data is not an image.
    public static func thumbnail(from data: Data, maxPixelSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up))),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    /// Width and height in pixels, read from the header without decoding.
    public static func pixelSize(of data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return CGSize(width: width, height: height)
    }

    /// Whether the data holds more than one frame — an animated GIF, PNG or
    /// HEIC sequence.
    public static func isAnimated(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        return CGImageSourceGetCount(source) > 1
    }

    /// Whether an animated image is small enough to play at full size.
    public static func canAnimate(_ data: Data) -> Bool {
        guard let size = pixelSize(of: data) else { return false }
        return size.width * size.height <= CGFloat(maximumAnimatedPixels)
    }
}
