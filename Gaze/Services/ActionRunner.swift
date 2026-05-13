import AppKit
import Foundation

struct VoiceAction: Equatable {
    let action: String
    let target: String
}

final class ActionRunner {
    @discardableResult
    func execute(_ action: VoiceAction) -> Bool {
        switch action.action.lowercased() {
        case "open_app", "open-app", "openapp":
            return openApp(named: action.target)
        case "open_url", "open-url", "openurl":
            return openURL(action.target)
        case "notify", "show_notification", "shownotification":
            return notify(action.target)
        case "run_applescript", "applescript":
            return runAppleScript(action.target)
        default:
            return false
        }
    }

    private func openApp(named name: String) -> Bool {
        let escaped = name.replacingOccurrences(of: "\"", with: "\\\"")
        return runAppleScript("tell application \"\(escaped)\" to activate")
    }

    private func openURL(_ raw: String) -> Bool {
        guard let url = URL(string: raw), url.scheme != nil else { return false }
        return NSWorkspace.shared.open(url)
    }

    private func notify(_ message: String) -> Bool {
        let escaped = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return runAppleScript("display notification \"\(escaped)\" with title \"Gaze\"")
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> Bool {
        var success = false
        let work = {
            guard let script = NSAppleScript(source: source) else { return }
            var errorInfo: NSDictionary?
            _ = script.executeAndReturnError(&errorInfo)
            success = (errorInfo == nil)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }
        return success
    }
}
