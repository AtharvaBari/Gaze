import AVFoundation
import Combine
import Foundation

enum AmbientMood: Equatable {
    case off
    case focus
    case relax

    var fileBase: String? {
        switch self {
        case .off:   return nil
        case .focus: return "focus_loop"
        case .relax: return "relax_loop"
        }
    }
}

final class AmbientSoundService: ObservableObject {
    @Published private(set) var currentMood: AmbientMood = .off
    @Published private(set) var isPlaying: Bool = false

    private weak var settings: SettingsStore?
    private var settingsCancellables = Set<AnyCancellable>()

    private var activePlayer: AVAudioPlayer?
    private var outgoingPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?

    init(settings: SettingsStore? = nil) {
        self.settings = settings
        observeSettings()
    }

    func setMood(_ mood: AmbientMood) {
        guard mood != currentMood else { return }
        currentMood = mood

        guard settings?.enableAmbient == true else {
            fadeOutActive()
            return
        }

        switch mood {
        case .off:
            fadeOutActive()
        case .focus, .relax:
            startLoop(for: mood)
        }
    }

    func applyVolume() {
        let target = currentTargetVolume()
        activePlayer?.volume = target
    }

    func cleanup() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        activePlayer?.stop()
        outgoingPlayer?.stop()
        activePlayer = nil
        outgoingPlayer = nil
        isPlaying = false
    }

    // MARK: - Private

    private func observeSettings() {
        guard let settings else { return }

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if settings.enableAmbient {
                    self.applyVolume()
                    if self.activePlayer == nil, self.currentMood != .off {
                        self.startLoop(for: self.currentMood)
                    }
                } else {
                    self.fadeOutActive()
                }
            }
            .store(in: &settingsCancellables)
    }

    private func currentTargetVolume() -> Float {
        guard settings?.enableAmbient == true else { return 0 }
        return Float(max(0, min(1, settings?.ambientVolume ?? 0.5)))
    }

    private func startLoop(for mood: AmbientMood) {
        guard let base = mood.fileBase, let url = locateAudio(named: base) else {
            isPlaying = false
            return
        }

        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            isPlaying = false
            return
        }
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        player.play()

        if let outgoing = activePlayer {
            outgoingPlayer?.stop()
            outgoingPlayer = outgoing
        }
        activePlayer = player
        isPlaying = true
        crossfade(duration: 1.5)
    }

    private func fadeOutActive() {
        guard activePlayer != nil else {
            isPlaying = false
            return
        }
        outgoingPlayer?.stop()
        outgoingPlayer = activePlayer
        activePlayer = nil
        crossfade(duration: 0.8)
    }

    private func crossfade(duration: TimeInterval) {
        fadeTimer?.invalidate()
        let target = currentTargetVolume()
        let start = Date()
        let outgoing = outgoingPlayer
        let incoming = activePlayer

        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] timer in
            let elapsed = Date().timeIntervalSince(start)
            let progress = Float(min(1.0, elapsed / duration))
            incoming?.volume = progress * target
            outgoing?.volume = max(0, (1 - progress)) * target

            if progress >= 1.0 {
                outgoing?.stop()
                if self?.outgoingPlayer === outgoing { self?.outgoingPlayer = nil }
                timer.invalidate()
                self?.fadeTimer = nil
                if incoming == nil { self?.isPlaying = false }
            }
        }
    }

    private func locateAudio(named base: String) -> URL? {
        let exts = ["m4a", "mp3", "wav", "caf", "aiff"]
        for ext in exts {
            if let url = Bundle.main.url(forResource: base, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
