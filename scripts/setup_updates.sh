#!/bin/bash

# Gaze Update Automation Script
# Automates key generation, DMG signing, and appcast management.

set -e

# Path to Sparkle binaries (from Swift Package artifacts)
SPARKLE_BIN="./build/SourcePackages/artifacts/sparkle/Sparkle/bin"
GENERATE_KEYS="$SPARKLE_BIN/generate_keys"
GENERATE_APPCAST="$SPARKLE_BIN/generate_appcast"
DMG_PATH="Gaze.dmg"
APPCAST_PATH="appcast.xml"

# UI Helpers
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Gaze Update Automation${NC}"
echo "--------------------------"

if [ ! -f "$GENERATE_KEYS" ]; then
    echo "❌ Error: Sparkle binaries not found. Please build the project first."
    exit 1
fi

show_help() {
    echo "Usage: ./scripts/setup_updates.sh [command]"
    echo ""
    echo "Commands:"
    echo "  keys      - Generate new EdDSA keys for signing (Run this once!)"
    echo "  release   - Update appcast.xml with the latest Gaze.dmg"
    echo "  help      - Show this help message"
}

generate_new_keys() {
    echo -e "${BLUE}🔐 Generating EdDSA Keys...${NC}"
    $GENERATE_KEYS
    echo ""
    echo -e "${GREEN}✅ Keys generated successfully!${NC}"
    echo "1. The PRIVATE KEY is shown above. Store it in a secure password manager."
    echo "2. The PUBLIC KEY must be added to your Info.plist as 'SUPublicEdKey'."
}

release_update() {
    # Find the latest versioned DMG
    VERSIONED_DMG=$(ls Gaze-*.dmg 2>/dev/null | sort -V | tail -n 1)

    if [ -z "$VERSIONED_DMG" ]; then
        echo "❌ Error: No versioned Gaze-*.dmg found. Run ./scripts/build_dmg.sh first."
        exit 1
    fi

    # Extract version from the filename (e.g., Gaze-1.0.1.dmg -> 1.0.1)
    VERSION=$(echo "$VERSIONED_DMG" | sed 's/Gaze-//' | sed 's/.dmg//')

    echo -e "${BLUE}📦 Processing update for $VERSIONED_DMG (v$VERSION)...${NC}"
    
    # Run the Sparkle generate_appcast tool
    # Points to GitHub Releases download path
    $GENERATE_APPCAST . --download-url-prefix "https://github.com/AtharvaBari/Gaze/releases/download/v${VERSION}/"

    echo -e "${GREEN}✅ appcast.xml updated with GitHub Releases URL!${NC}"
    echo "Next steps:"
    echo "1. Create a GitHub Release called 'v$VERSION'."
    echo "2. Upload $VERSIONED_DMG to that Release."
    echo "3. Commit and push appcast.xml to GitHub."
}

case "$1" in
    keys) generate_new_keys ;;
    release) release_update ;;
    *) show_help ;;
esac
