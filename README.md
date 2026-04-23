# 👁️ Gaze

<p align="center">
  <img src="https://raw.githubusercontent.com/huddlecode0/Huddle-Asserts/refs/heads/main/icon.png" width="128" height="128" alt="Gaze Icon">
  <br>
  <b>The Premium Productivity Companion for your MacBook Notch.</b>
  <br>
  <i>Transforming the gap into a dynamic, watchful focus experience.</i>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014.0+-black?style=for-the-badge&logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-6.0-orange?style=for-the-badge&logo=swift" alt="Swift">
  <img src="https://img.shields.io/github/v/release/AtharvaBari/Gaze-MacOS?style=for-the-badge&color=blue" alt="Release">
  <img src="https://img.shields.io/github/license/AtharvaBari/Gaze-MacOS?style=for-the-badge&color=lightgrey" alt="License">
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/huddlecode0/Huddle-Asserts/refs/heads/main/0421.gif" alt="macOS">
  
---

## ✨ Overview

**Gaze** is more than just a Pomodoro timer. It’s a native macOS utility that utilizes the hardware notch on modern MacBook Pros and Airs to create a "Dynamic Island" focus HUD. 

Featuring a procedural **Mascot** that tracks your cursor with its eyes, Gaze adds a layer of interactive life to your screen while keeping you on track with glass-morphic timers and smooth, system-native animations.

## 🌟 Key Features

- 📱 **Dynamic Notch Integration**: A persistent, non-intrusive HUD that hugs the camera notch.
- 👁️ **The Gaze Mascot**: A smooth, 2D procedural animation that watches your every move (cursor tracking).
- 🌊 **Liquid Animations**: Built with SwiftUI spring physics for that "Apple-smooth" expansion feel.
- 🛠️ **Sidebar Control Center**: A clean, modern settings interface with navigation-split views.
- ⚡ **Cinematic Intro**: Experience a stunning neon-grid welcome every time you launch the app.
- 🔄 **Sparkle Updates**: Secure, automatic software updates to keep your experience fresh.

## 🚀 Getting Started

### Installation
1. Download the latest **`Gaze.dmg`** from the [Releases](https://github.com/AtharvaBari/Gaze-MacOS/releases) page.
2. Drag **Gaze** to your Applications folder.
3. Open the app and grant **Accessibility Permissions** (required for the mascot to track your cursor).

### For Developers
Gaze is built using modern Swift standards and `xcodegen`.

```bash
# 1. Clone the repo
git clone https://github.com/AtharvaBari/Gaze-MacOS.git
cd Gaze-MacOS

# 2. Generate the Xcode Project
./xcodegen/bin/xcodegen

# 3. Open and Build
open Gaze.xcodeproj
````

## 🗺️ Upcoming Features

- 🛠️ **Custom Mascot Themes**: Unlock new skins and personalities for your digital focus companion.
- 📊 **Insight Analytics**: Track your focus sessions with beautiful, interactive heatmaps and trends.
- 🔔 **Focus Mode Sync**: Automatically toggle macOS "Do Not Disturb" during active sessions.
- 📅 **Calendar Integration**: See your upcoming meetings directly in the Notch HUD.


## 🛠️ Tech Stack

  - **UI Framework:** SwiftUI + AppKit (NSPanel)
  - **Animation:** SwiftUI Canvas & TimelineView
  - **Persistence:** SwiftData
  - **Lifecycle:** Swift 6 Concurrency
  - **Distribution:** Sparkle Framework

## 📄 License

Gaze is available under the **MIT License**. See the `LICENSE` file for more info.

-----

<p align="center"\>
Built with 🤍 by <a href="https://github.com/AtharvaBari">Atharva Bari</a>
</p\>