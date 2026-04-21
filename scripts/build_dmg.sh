#!/bin/bash

# Gaze Build & Packaging Script
# This script builds the Xcode project and creates a .dmg for distribution.

set -e

# Configuration
APP_NAME="Gaze"
PROJECT_NAME="Gaze.xcodeproj"
SCHEME_NAME="Gaze"
CONFIGURATION="Release"
BUILD_DIR="./build"
APP_DIR="$BUILD_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"

# Extract version from the built app AFTER it is built
# We will set DMG_NAME inside the script logic after the build step.

echo "🚀 Starting build process for $APP_NAME..."

# 1. Clean and Build
xcodebuild -project "$PROJECT_NAME" \
           -scheme "$SCHEME_NAME" \
           -configuration "$CONFIGURATION" \
           -derivedDataPath "$BUILD_DIR" \
           clean build

if [ ! -d "$APP_DIR" ]; then
    echo "❌ Error: App bundle not found at $APP_DIR"
    exit 1
fi

# Extract version for the filename
VERSION=$(defaults read "$(pwd)/$APP_DIR/Contents/Info.plist" CFBundleShortVersionString)
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_TEMP="temp_${DMG_NAME}"

echo "📦 Creating DMG: $DMG_NAME"

# 2. Create Temporary DMG
if [ -f "$DMG_NAME" ]; then rm "$DMG_NAME"; fi
if [ -f "$DMG_TEMP" ]; then rm "$DMG_TEMP"; fi

# Ensure no existing volume is mounted
if [ -d "/Volumes/$APP_NAME" ]; then
    echo "⏏ Detaching existing volume..."
    hdiutil detach "/Volumes/$APP_NAME" || true
fi

echo "📦 Creating temporary disk image..."
hdiutil create -size 100m -fs HFS+ -volname "$APP_NAME" -ov -attach "$DMG_TEMP" -plist > dmg_info.plist

# 3. Mount and Copy
# Extract mount point using a robust method for plists
MOUNT_DIR=$(xpath -e "//key[text()='mount-point']/following-sibling::string[1]/text()" dmg_info.plist 2>/dev/null || \
           grep -A1 "mount-point" dmg_info.plist | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')

if [ -z "$MOUNT_DIR" ]; then
    # Fallback to simple grep if plist parsing fails
    MOUNT_DIR="/Volumes/$APP_NAME"
fi

echo "📂 Mounted at: $MOUNT_DIR"
cp -R "$APP_DIR" "$MOUNT_DIR/"

# Create Applications symlink
ln -s /Applications "$MOUNT_DIR/Applications"

echo "⏏ Detaching..."
hdiutil detach "$MOUNT_DIR"

# 4. Convert to compressed Read-Only DMG
echo "💿 Converting to final compressed DMG..."
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_NAME"
rm "$DMG_TEMP"
rm dmg_info.plist

echo "✅ Success! $DMG_NAME created."
echo "🔗 Next steps: Notarize the app if you have a Developer ID, then upload to GitHub Releases."
