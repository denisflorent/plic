// swift-tools-version: 6.0

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
import PackageDescription

// Xiph's libogg 1.3.5 and libopus 1.5.2, vendored as source rather than as a
// prebuilt binary: the app claims a security posture, and an opaque .a in the
// repository would undercut it. Both are BSD-licensed.
//
// Why they are here at all: macOS advertises an Opus encoder and an Ogg
// container writer, and cannot actually produce the combination — AVAudioFile,
// AVAudioRecorder and ExtAudioFile all fail with `pck?`. Matrix voice messages
// are Ogg/Opus by MSC3245, so Plic has to encode them itself.
let package = Package(
    name: "OpusCodec",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "OpusCodec", targets: ["OpusCodec"])
    ],
    targets: [
        .target(
            name: "COgg",
            path: "Sources/COgg",
            publicHeadersPath: "include"
        ),
        .target(
            name: "COpus",
            path: "Sources/COpus",
            // The SIMD paths under celt/arm and silk/arm need runtime CPU
            // detection wired up by the autotools build; the portable C is
            // fast enough for one voice message at a time.
            exclude: ["LICENSE"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("celt"),
                .headerSearchPath("silk"),
                .headerSearchPath("silk/float"),
                .headerSearchPath("src"),
                .define("OPUS_BUILD"),
                .define("USE_ALLOCA"),
                .define("HAVE_LRINTF"),
                .define("PACKAGE_VERSION", to: "\"1.5.2\""),
            ]
        ),
        .target(
            name: "COpusShim",
            dependencies: ["COpus"],
            path: "Sources/COpusShim",
            publicHeadersPath: "include"
        ),
        .target(
            name: "OpusCodec",
            dependencies: ["COgg", "COpus", "COpusShim"],
            path: "Sources/OpusCodec"
        ),
        .testTarget(
            name: "OpusCodecTests",
            dependencies: ["OpusCodec"],
            path: "Tests/OpusCodecTests"
        ),
    ]
)
