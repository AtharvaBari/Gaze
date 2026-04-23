# Gaze Distribution & Update Guide

This guide explains how to build, package, and distribute the Gaze macOS app with support for automatic updates.

## 1. Building and Packaging (.app & .dmg)

I have provided a script to automate the build process:
```bash
chmod +x scripts/build_dmg.sh
./scripts/build_dmg.sh
```
**What this does:**
1. Compiles the app in **Release** mode.
2. Creates a `Gaze.app` bundle in the `build/` directory.
3. Packages the app into a `Gaze.dmg` file, including a shortcut to the Applications folder for easy installation.

---

## 2. Setting Up Automatic Updates (Sparkle)

Gaze uses the **Sparkle** framework to provide "Push-to-Update" functionality.

### Initial Setup (One-time)
1. **Generate Keys**: You need EdDSA keys to sign your updates.
   - Download the Sparkle release from [sparkle-project.org](https://sparkle-project.org/).
   - Run the `bin/generate_keys` tool included in the Sparkle download.
2. **Configure Info.plist**:
   - Copy the **Public Key** generated above.
   - Open `Gaze/Info.plist` and paste it into the `SUPublicEdKey` field.

### Releasing an Update
1. Update the version number in `project.yml` and `Info.plist`.
2. Run `./scripts/build_dmg.sh` to generate the new `.dmg`.
3. Sign the DMG and generate the appcast item:
   ```bash
   path/to/sparkle/bin/generate_appcast .
   ```
4. Upload the new `Gaze.dmg` and the updated `appcast.xml` to your GitHub repository (GitHub Pages/Releases).

---

## 3. Apple Notarization (Highly Recommended)

To prevent users from seeing the "Developer cannot be verified" warning:
1. You must have an **Apple Developer Account**.
2. Run the following command (after building the DMG):
   ```bash
   xcrun notarytool submit Gaze.dmg --apple-id "YOUR_APPLE_ID" --password "APP_SPECIFIC_PASSWORD" --team-id "YOUR_TEAM_ID" --wait
   ```
3. Once notarized, "staple" the ticket to the DMG:
   ```bash
   xcrun stapler staple Gaze.dmg
   ```

---

## 4. Hosting on GitHub

1. **GitHub Releases**: Create a new release (e.g., `v1.0`) and upload `Gaze.dmg`.
2. **GitHub Pages**: Ensure `appcast.xml` is accessible at `https://AtharvaBari.github.io/Gaze-MacOS/appcast.xml`.
