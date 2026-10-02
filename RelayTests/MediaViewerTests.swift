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
import AVKit
import Foundation
import PDFKit
import Testing

@testable import Relay

/// Pins the viewer that replaced Quick Look: what it shows, that it never
/// becomes restorable state, and that it lets go of what it showed.
@MainActor
struct MediaViewerTests {

    private func png(width: Int, height: Int) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        return try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
    }

    private func pdf(pages: Int) throws -> Data {
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let consumer = try #require(CGDataConsumer(data: data))
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        for _ in 0..<pages {
            context.beginPDFPage(nil)
            context.fill(CGRect(x: 72, y: 72, width: 200, height: 100))
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    private func window(titled title: String) -> NSWindow? {
        NSApp.windows.first { $0.title == title && $0.isVisible }
    }

    @Test("An image opens in a viewer that is never restorable")
    func imageOpens() throws {
        let title = "photo-\(UUID().uuidString).png"
        #expect(MediaViewer.show(.image(try png(width: 4_000, height: 3_000)), title: title))
        let viewer = try #require(window(titled: title))
        defer { viewer.close() }

        // Restoration would write what the window shows to disk.
        #expect(viewer.isRestorable == false)
        let scroll = try #require(viewer.contentView as? NSScrollView)
        #expect(scroll.magnification < 1, "a large image is shrunk to fit")
    }

    @Test("A small image is shown at its size, never blown up")
    func smallImageIsNotEnlarged() throws {
        let title = "icon-\(UUID().uuidString).png"
        #expect(MediaViewer.show(.image(try png(width: 120, height: 80)), title: title))
        let viewer = try #require(window(titled: title))
        defer { viewer.close() }
        #expect((viewer.contentView as? NSScrollView)?.magnification == 1)
    }

    @Test("Something that is not an image opens nothing")
    func garbageIsRefused() {
        let title = "junk-\(UUID().uuidString).png"
        #expect(MediaViewer.show(.image(Data(repeating: 0x42, count: 2_048)), title: title) == false)
        #expect(window(titled: title) == nil)
    }

    @Test("A PDF opens from memory")
    func pdfOpens() throws {
        let document = try #require(PDFDocument(data: try pdf(pages: 3)))
        let title = "report-\(UUID().uuidString).pdf"
        #expect(MediaViewer.show(.pdf(document), title: title))
        let viewer = try #require(window(titled: title))
        defer { viewer.close() }
        #expect((viewer.contentView as? PDFView)?.document?.pageCount == 3)
    }

    @Test("Closing a video viewer stops and releases the player")
    func videoStopsOnClose() throws {
        let source = InMemoryAsset(data: Data(repeating: 0, count: 16), mimeType: "video/mp4", filename: "clip.mp4")
        let title = "clip-\(UUID().uuidString).mp4"
        #expect(MediaViewer.show(.video(source), title: title))
        let viewer = try #require(window(titled: title))
        let player = try #require((viewer.contentView as? AVPlayerView)?.player)

        viewer.close()

        #expect(player.currentItem == nil, "the player must let go of the decrypted video")
        #expect(window(titled: title) == nil)
    }
}
