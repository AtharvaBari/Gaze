import SwiftUI
import Sparkle
import AppKit
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var notchPanel: NotchPanel?
    private var notchDetector = NotchDetector()
    private var settingsStore = SettingsStore()
    private lazy var timerEngine = TimerEngine(settings: settingsStore)
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        
        ShortcutManager.shared.onToggleTimer = { [weak self] in
            guard let engine = self?.timerEngine else { return }
            if engine.isRunning { engine.pause() }
            else { engine.start() }
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "Gaze")
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
        
        notchDetector.detect(for: NSScreen.main)
        
        if let geometry = notchDetector.geometry {
            notchPanel = NotchPanel(contentRect: geometry.extensionRect)
            let notchView = NotchContentView(geometry: geometry, timerEngine: timerEngine, settings: settingsStore)
            notchPanel?.setContent(notchView)
            notchPanel?.orderFrontRegardless()
        }
        
        notchDetector.startMonitoring()
        
        notchDetector.$geometry
            .compactMap { $0 }
            .sink { [weak self] newGeometry in
                self?.repositionPanel(geometry: newGeometry)
            }
            .store(in: &cancellables)
            
        let launchManager = LaunchManager()
        if launchManager.isFirstLaunch {
            showWelcomeOverlay()
        }
    }
    
    private func showWelcomeOverlay() {
        guard let screenFrame = NSScreen.main?.frame else { return }
        
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        let welcomeView = WelcomeView { [weak self, weak window] in
            // Animate window fade out on dismiss
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.8
                window?.animator().alphaValue = 0.0
            } completionHandler: {
                window?.close()
                if self?.welcomeWindow == window {
                    self?.welcomeWindow = nil
                }
                LaunchManager().markLaunched()
            }
        }
        
        window.contentView = NSHostingView(rootView: welcomeView)
        window.makeKeyAndOrderFront(nil)
        self.welcomeWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func repositionPanel(geometry: NotchGeometry) {
        notchPanel?.setFrame(geometry.extensionRect, display: true, animate: true)
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
#if canImport(Sparkle)
            // Configure Sparkle updater if available
            let updater = SparkleManager.shared.updater
            updater.automaticallyChecksForUpdates = settingsStore.autoCheckUpdates
            if let feedURL = URL(string: "https://AtharvaBari.github.io/Gaze-MacOS/appcast.xml") {
                updater.feedURL = feedURL
            }
            // Build a context menu with Check for Updates and Settings
            let menu = NSMenu()
            let checkItem = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
            checkItem.target = self
            menu.addItem(checkItem)
            menu.addItem(NSMenuItem.separator())
            let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettingsWindow), keyEquivalent: "")
            settingsItem.target = self
            menu.addItem(settingsItem)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
#else
            // Fallback: show a minimal menu without Sparkle
            let menu = NSMenu()
            let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettingsWindow), keyEquivalent: "")
            settingsItem.target = self
            menu.addItem(settingsItem)
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
#endif
        } else {
            showSettingsWindow()
        }
    }
    
    @objc func showSettingsWindow() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Gaze Settings"
            window.setFrameAutosaveName("SettingsWindow")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(store: settingsStore))
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

#if canImport(Sparkle)
    @objc private func checkForUpdates(_ sender: Any?) {
        SparkleManager.shared.updater.checkForUpdates(nil)
    }
#else
    @objc private func checkForUpdates(_ sender: Any?) {
        // Sparkle not available; you can present an alert or ignore.
        NSSound.beep()
    }
#endif
}
