#!/bin/bash
# index-help-book.sh
#
# Generates the full-text search index and context-sensitive help index
# for the Relay help book inside the built product.
# Called as a Run Script build phase after resources are copied.
#
# Build settings consumed:
#   TARGET_BUILD_DIR – directory holding this target's product.
#     Not BUILT_PRODUCTS_DIR: during an archive the two diverge, and the app
#     that ends up in the .xcarchive is the one under TARGET_BUILD_DIR. Using
#     BUILT_PRODUCTS_DIR indexed a copy that was then thrown away, so every
#     release shipped a help book with no search index and rendered blank.
#   FULL_PRODUCT_NAME  – e.g. "Relay.app"

set -euo pipefail

HELP_DIR="${TARGET_BUILD_DIR}/${FULL_PRODUCT_NAME}/Contents/Resources/Relay.help"
LPROJ_DIR="${HELP_DIR}/Contents/Resources/en.lproj"

# --- Generate full-text search index ---

/usr/bin/hiutil -Caf "${LPROJ_DIR}/Plic.helpindex" "${LPROJ_DIR}"
echo "note: Generated Plic.helpindex"

# --- Generate context-sensitive help index ---

/usr/bin/hiutil -Caf "${LPROJ_DIR}/Plic.cshelpindex" -s en "${LPROJ_DIR}"
echo "note: Generated Plic.cshelpindex"
