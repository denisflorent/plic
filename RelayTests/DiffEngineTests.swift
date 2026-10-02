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

import Foundation
import Testing

@testable import RelayKit

/// Pins the diff operations that keep the room and space lists in step with
/// the SDK. A wrong one corrupts what the sidebar shows, silently.
@MainActor
struct DiffEngineTests {

    private func apply(_ operation: DiffOperation<String>, to items: [String]) -> [String] {
        DiffEngine.apply(operation, to: items)
    }

    @Test("Each operation does what the SDK means by it")
    func operations() {
        let abc = ["a", "b", "c"]
        #expect(apply(.append(["d", "e"]), to: abc) == ["a", "b", "c", "d", "e"])
        #expect(apply(.clear, to: abc) == [])
        #expect(apply(.pushFront("z"), to: abc) == ["z", "a", "b", "c"])
        #expect(apply(.pushBack("z"), to: abc) == ["a", "b", "c", "z"])
        #expect(apply(.popFront, to: abc) == ["b", "c"])
        #expect(apply(.popBack, to: abc) == ["a", "b"])
        #expect(apply(.insert(1, "z"), to: abc) == ["a", "z", "b", "c"])
        #expect(apply(.insert(3, "z"), to: abc) == ["a", "b", "c", "z"], "inserting at the end is an append")
        #expect(apply(.set(2, "z"), to: abc) == ["a", "b", "z"])
        #expect(apply(.remove(0), to: abc) == ["b", "c"])
        #expect(apply(.truncate(1), to: abc) == ["a"])
        #expect(apply(.reset(["x"]), to: abc) == ["x"])
    }

    @Test("Out-of-range operations are ignored rather than crashing")
    func outOfRange() {
        // A desynchronised SDK must not take the app down with it.
        let ab = ["a", "b"]
        #expect(apply(.insert(5, "z"), to: ab) == ab)
        #expect(apply(.set(2, "z"), to: ab) == ab)
        #expect(apply(.remove(9), to: ab) == ab)
        #expect(apply(.truncate(10), to: ab) == ab)
        #expect(apply(.popFront, to: []) == [])
        #expect(apply(.popBack, to: []) == [])
    }

    @Test("A batch applies in order")
    func batchOrder() {
        let result = DiffEngine.applyBatch([
            .reset(["a", "b", "c"]),
            .pushFront("z"),   // z a b c
            .set(1, "A"),      // z A b c
            .remove(2),        // z A c
            .append(["d"]),    // z A c d
            .truncate(3),      // z A c
        ], to: [String]())
        #expect(result == ["z", "A", "c"])
    }
}
