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
    private var portalCoordinator = PortalCoordinator()
    private lazy var systemObserver = SystemObserver()
    private var screenAwareness = ScreenAwarenessService()
    private lazy var taskHelper = TaskHelperService(settings: settingsStore)
    private lazy var ambientSound = AmbientSoundService(settings: settingsStore)
    private var voiceService = VoiceService()
    private var hotkeyManager = HotkeyManager()
    private var actionRunner = ActionRunner()
    private lazy var voiceCoordinator = VoiceConversationCoordinator(
        voice: voiceService,
        settings: settingsStore,
        actionRunner: actionRunner
    )
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
            notchPanel = NotchPanel(contentRect: geometry.extensionRect, notchAnchorX: geometry.notchRect.midX)
            let notchView = NotchContentView(
                geometry: geometry,
                timerEngine: timerEngine,
                settings: settingsStore,
                portal: portalCoordinator,
                systemObserver: systemObserver,
                screenAwareness: screenAwareness,
                taskHelper: taskHelper,
                voice: voiceService,
                voiceCoordinator: voiceCoordinator
            )
            notchPanel?.setContent(notchView)
            installPortalHandlers(for: geometry)
            notchPanel?.orderFrontRegardless()
        }

        _ = systemObserver
        
        notchDetector.startMonitoring()
        
        notchDetector.$geometry
            .compactMap { $0 }
            .sink { [weak self] newGeometry in
                self?.repositionPanel(geometry: newGeometry)
            }
            .store(in: &cancellables)

        systemObserver.$hud
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hud in
                self?.handleHUDChange(hud)
            }
            .store(in: &cancellables)

        screenAwareness.delegate = self

        timerEngine.$mode
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.handleTimerModeChange(mode)
            }
            .store(in: &cancellables)

        _ = ambientSound
        _ = voiceCoordinator

        installVoiceHotkey()
        observeVoiceCoordinator()

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
        notchPanel?.updateBaseFrame(geometry.extensionRect, anchorX: geometry.notchRect.midX, animated: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        taskHelper.cancelAll()
        screenAwareness.setWorkMode(false)
        ambientSound.cleanup()
        hotkeyManager.stop()
        voiceCoordinator.dismiss()
        voiceService.cancel()
        cancellables.removeAll()
    }

    private func installVoiceHotkey() {
        hotkeyManager.onPushDown = { [weak self] in
            self?.voiceService.startRecording()
        }
        hotkeyManager.onPushUp = { [weak self] in
            self?.voiceService.stopRecording()
        }
        hotkeyManager.start()
    }

    private func observeVoiceCoordinator() {
        let activePublisher = Publishers.CombineLatest4(
            voiceCoordinator.$response,
            voiceCoordinator.$isThinking,
            voiceCoordinator.$isSpeaking,
            voiceCoordinator.$transcript
        )
        .map { response, thinking, speaking, transcript in
            return response != nil || thinking || speaking || !transcript.isEmpty
        }
        .removeDuplicates()

        activePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in
                self?.handleVoiceActiveChange(active)
            }
            .store(in: &cancellables)
    }

    private func handleVoiceActiveChange(_ active: Bool) {
        guard let panel = notchPanel else { return }
        if active {
            let target = panel.baseFrame.height + 64
            panel.resizeHeight(to: target, animated: true)
        } else {
            panel.restoreHeight(animated: true)
        }
    }

    private func handleTimerModeChange(_ mode: TimerMode) {
        let isWork = (mode == .work)
        screenAwareness.setWorkMode(isWork)
        if !isWork {
            taskHelper.clear()
        }

        switch mode {
        case .work:
            ambientSound.setMood(.focus)
        case .break:
            ambientSound.setMood(.relax)
        case .idle, .countdown, .completed:
            ambientSound.setMood(.off)
        }
    }

    private func handleHUDChange(_ hud: SystemHUDState?) {
        guard let panel = notchPanel else { return }
        if hud != nil {
            let target = max(panel.baseFrame.width, 380)
            panel.resizeWidth(to: target, animated: true)
        } else if !portalCoordinator.isHovering {
            panel.restoreBaseFrame(animated: true)
        }
    }

    private func installPortalHandlers(for geometry: NotchGeometry) {
        let hoverWidth: CGFloat = max(geometry.extensionRect.width, 320)

        notchPanel?.setPortalHandlers(
            onEnter: { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.portalCoordinator.beginHover()
                    self.notchPanel?.resizeWidth(to: hoverWidth, animated: true)
                }
            },
            onExit: { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.portalCoordinator.endHover()
                    self.notchPanel?.restoreBaseFrame(animated: true)
                }
            },
            onDrop: { [weak self] raw in
                guard let self else { return false }
                guard let capture = PortalParser.parse(raw) else {
                    DispatchQueue.main.async {
                        self.portalCoordinator.endHover()
                        self.notchPanel?.restoreBaseFrame(animated: true)
                    }
                    return false
                }
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(capture.copyable, forType: .string)
                DispatchQueue.main.async {
                    self.portalCoordinator.swallow(capture)
                    if case .url(let url) = capture {
                        self.taskHelper.summarize(url: url)
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                    self?.notchPanel?.restoreBaseFrame(animated: true)
                }
                return true
            }
        )
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

extension AppDelegate: ScreenAwarenessDelegate {
    func screenAwareness(_ service: ScreenAwarenessService, didCapture frame: ScreenAwarenessFrame) {
        taskHelper.ingest(frame: frame)
    }
}
