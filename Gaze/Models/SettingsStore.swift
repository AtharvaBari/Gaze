import SwiftUI

class SettingsStore: ObservableObject {
    @AppStorage("workDurationMinutes") var workDurationMinutes: Int = 25
    @AppStorage("breakDurationMinutes") var breakDurationMinutes: Int = 5
    @AppStorage("maxCycles") var maxCycles: Int = 4
    @AppStorage("isPeriodicPeekEnabled") var isPeriodicPeekEnabled: Bool = false
    @AppStorage("peekIntervalMinutes") var peekIntervalMinutes: Int = 5
    @AppStorage("trackCursor") var trackCursor: Bool = false
    @AppStorage("autoCheckUpdates") var autoCheckUpdates: Bool = true
    @AppStorage("enableSounds") var enableSounds: Bool = true
    @AppStorage("hideOnInactivity") var hideOnInactivity: Bool = false

    @AppStorage("aiProvider") var aiProvider: String = "gemini"
    @AppStorage("geminiAPIKey") var geminiAPIKey: String = ""
    @AppStorage("openRouterAPIKey") var openRouterAPIKey: String = ""
    @AppStorage("enableAmbient") var enableAmbient: Bool = false
    @AppStorage("ambientVolume") var ambientVolume: Double = 0.5

    var aiProviderEnum: AIProvider {
        get { AIProvider(rawValue: aiProvider) ?? .gemini }
        set {
            objectWillChange.send()
            aiProvider = newValue.rawValue
        }
    }

    var currentProviderAPIKey: String {
        switch aiProviderEnum {
        case .gemini:     return geminiAPIKey
        case .openrouter: return openRouterAPIKey
        }
    }

    private let mascotStyleKey = "mascotStyle"

    var mascotStyle: MascotStyle {
        get {
            let raw = UserDefaults.standard.string(forKey: mascotStyleKey) ?? MascotStyle.default.rawValue
            return MascotStyle(rawValue: raw) ?? .default
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue.rawValue, forKey: mascotStyleKey)
        }
    }

    var workDurationSeconds: Int { workDurationMinutes * 60 }
    var breakDurationSeconds: Int { breakDurationMinutes * 60 }

    func playSound(_ name: NSSound.Name) {
        guard enableSounds else { return }
        if let sound = NSSound(named: name) {
            sound.volume = 0.4
            sound.play()
        }
    }
}
