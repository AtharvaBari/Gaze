#!/bin/bash

# Gaze Build & Packaging Script (Premium DMG Version)
# This script builds the Xcode project and creates a customized .dmg for distribution.

set -e

# Configuration
APP_NAME="Gaze"
PROJECT_NAME="Gaze.xcodeproj"
SCHEME_NAME="Gaze"
CONFIGURATION="Release"
BUILD_DIR="./build"
APP_DIR="$BUILD_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
BACKGROUND_IMAGE="background.png"

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
DMG_NAME="${APP_NAME}_v${VERSION}.dmg"
DMG_TEMP="temp_${DMG_NAME}"

echo "📦 Creating DMG: $DMG_NAME"

# 2. Setup Temporary DMG
if [ -f "$DMG_NAME" ]; then rm "$DMG_NAME"; fi
if [ -f "$DMG_TEMP" ]; then rm "$DMG_TEMP"; fi

# Ensure no existing volume is mounted
if [ -d "/Volumes/$APP_NAME" ]; then
    echo "⏏ Detaching existing volume..."
    hdiutil detach "/Volumes/$APP_NAME" || true
fi

echo "📦 Creating temporary disk image..."
hdiutil create -size 200m -fs HFS+ -volname "$APP_NAME" -ov -attach "$DMG_TEMP" -plist > dmg_info.plist

# 3. Mount and Copy Files
MOUNT_DIR=$(grep -A1 "mount-point" dmg_info.plist | grep "<string>" | sed 's/.*<string>\(.*\)<\/string>.*/\1/')
if [ -z "$MOUNT_DIR" ]; then MOUNT_DIR="/Volumes/$APP_NAME"; fi

echo "📂 Mounted at: $MOUNT_DIR"

# Copy App
cp -R "$APP_DIR" "$MOUNT_DIR/"

# Create Applications symlink
ln -s /Applications "$MOUNT_DIR/Applications"

# 4. Custom Design (Background & Layout)
if [ -f "$BACKGROUND_IMAGE" ]; then
    echo "🎨 Applying custom background design..."
    mkdir "$MOUNT_DIR/.background"
    cp "$BACKGROUND_IMAGE" "$MOUNT_DIR/.background/background.png"
    
    # Run AppleScript to style the DMG window
    # Coordinates assume a background designed for roughly 600x400
    echo "✨ Running AppleScript for layout..."
    osascript <<EOF
    tell application "Finder"
        tell disk "$APP_NAME"
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {400, 100, 1235, 700}
            set viewOptions to the icon view options of container window
            set icon size of viewOptions to 144
            set arrangement of viewOptions to not arranged
            set label position of viewOptions to bottom
            set background color of viewOptions to {0, 0, 0}
            set background picture of viewOptions to file ".background:background.png"
            set position of item "$APP_NAME.app" to {210, 260}
            set position of item "Applications" to {625, 260}
            close
            open
            update without registering applications
            delay 2
        end tell
    end tell
EOF
else
    echo "⚠️ Warning: background.png not found. Skipping UI customization."
fi

echo "⏏ Detaching and finalizing..."
# Ensure changes are written
sync
# Give Finder a moment to finish its business
sleep 2
hdiutil detach "$MOUNT_DIR"

# 5. Convert to compressed Read-Only DMG
echo "💿 Converting to final compressed DMG..."
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_NAME"
rm "$DMG_TEMP"
rm dmg_info.plist

echo "✅ Success! $DMG_NAME created with custom layout."
echo "🔗 Next steps: Notarize the app then upload to GitHub Releases."
