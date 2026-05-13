import AppKit

final class HotkeyManager {
    var onPushDown: (() -> Void)?
    var onPushUp: (() -> Void)?

    private(set) var isHeld: Bool = false

    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        guard globalMonitor == nil else { return }

        if !AccessibilityPermission.isGranted {
            AccessibilityPermission.request()
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event: event)
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if isHeld {
            isHeld = false
            DispatchQueue.main.async { [weak self] in
                self?.onPushUp?()
            }
        }
    }

    private func handle(event: NSEvent) {
        let flags = event.modifierFlags
        let bothHeld = flags.contains(.command) && flags.contains(.function)

        if bothHeld, !isHeld {
            isHeld = true
            DispatchQueue.main.async { [weak self] in
                self?.onPushDown?()
            }
        } else if !bothHeld, isHeld {
            isHeld = false
            DispatchQueue.main.async { [weak self] in
                self?.onPushUp?()
            }
        }
    }
}
