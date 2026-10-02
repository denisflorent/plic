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

/// The "Show URL Previews" setting, shared by every place that reads it so
/// they cannot disagree on its default.
enum LinkPreviewSetting {
    static let key = "behavior.showURLPreviews"

    /// Off. A preview is fetched by this Mac, straight from the linked site:
    /// whoever controls it learns this Mac's IP address and the moment the
    /// message was displayed — a read receipt nobody agreed to, sent even
    /// with read receipts off, from a message nobody had to click. Turning it
    /// on is a choice to make knowingly, not a default.
    static let standard = false
}
