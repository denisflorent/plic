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
import Foundation
import RelayInterface
import Testing

/// Pins that a received image is decoded at display size, whatever size the
/// sender gave it.
struct ImageDecodingTests {

    /// A flat grey PNG: tiny to send, large once decoded.
    private func png(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0
        ))
        context.setFillColor(gray: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        return try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    }

    @Test("An oversized image is decoded no larger than it is shown")
    func boundedDecode() throws {
        let data = try png(width: 6_000, height: 3_000)
        let image = try #require(ImageDecoding.thumbnail(from: data, maxPixelSize: 600))
        // The bitmap actually held. NSImage's representation reports pixel
        // counts at the screen's backing scale, which says nothing about memory.
        let bitmap = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(max(bitmap.width, bitmap.height) <= 600)
        #expect(bitmap.width == 2 * bitmap.height, "the aspect ratio survives")
    }

    @Test("Dimensions are read from the header, without decoding")
    func headerSize() throws {
        #expect(ImageDecoding.pixelSize(of: try png(width: 640, height: 480)) == CGSize(width: 640, height: 480))
        #expect(ImageDecoding.pixelSize(of: Data("not an image".utf8)) == nil)
    }

    @Test("Only reasonably sized images are animated at full size")
    func animationBound() throws {
        #expect(ImageDecoding.canAnimate(try png(width: 480, height: 270)))
        #expect(!ImageDecoding.canAnimate(try png(width: 4_000, height: 4_000)))
        #expect(!ImageDecoding.canAnimate(Data("not an image".utf8)))
    }

    @Test("Garbage is not an image")
    func garbage() {
        #expect(ImageDecoding.thumbnail(from: Data(repeating: 0xAB, count: 4_096), maxPixelSize: 300) == nil)
    }
}
