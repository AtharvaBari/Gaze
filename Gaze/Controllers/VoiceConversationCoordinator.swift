import AVFoundation
import Combine
import Foundation

final class VoiceConversationCoordinator: NSObject, ObservableObject {
    @Published private(set) var transcript: String = ""
    @Published private(set) var response: String?
    @Published private(set) var isThinking: Bool = false
    @Published private(set) var isSpeaking: Bool = false
    @Published private(set) var speechBeat: Int = 0
    @Published private(set) var executedAction: VoiceAction?

    private weak var voice: VoiceService?
    private weak var settings: SettingsStore?
    private let actionRunner: ActionRunner
    private let synthesizer = AVSpeechSynthesizer()

    private var cancellables = Set<AnyCancellable>()
    private var currentTask: Task<Void, Never>?
    private var autoDismissWork: DispatchWorkItem?
    private let autoDismissAfter: TimeInterval = 5.0

    init(voice: VoiceService, settings: SettingsStore, actionRunner: ActionRunner) {
        self.voice = voice
        self.settings = settings
        self.actionRunner = actionRunner
        super.init()
        synthesizer.delegate = self
        observeVoice()
    }

    deinit {
        currentTask?.cancel()
        autoDismissWork?.cancel()
        synthesizer.stopSpeaking(at: .immediate)
    }

    var isActive: Bool {
        return !transcript.isEmpty || response != nil || isThinking || isSpeaking
    }

    func dismiss() {
        autoDismissWork?.cancel()
        autoDismissWork = nil
        currentTask?.cancel()
        currentTask = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        transcript = ""
        response = nil
        isThinking = false
        isSpeaking = false
        executedAction = nil
    }

    // MARK: - Private

    private func observeVoice() {
        guard let voice else { return }

        voice.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recording in
                guard let self else { return }
                if recording {
                    self.dismiss()
                }
            }
            .store(in: &cancellables)

        voice.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.transcript = text
            }
            .store(in: &cancellables)

        voice.$finalTranscript
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] finalText in
                let trimmed = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                self?.handle(transcript: trimmed)
            }
            .store(in: &cancellables)
    }

    private func handle(transcript text: String) {
        currentTask?.cancel()
        autoDismissWork?.cancel()
        isThinking = true
        response = nil
        executedAction = nil

        let prompt = buildPrompt(userText: text)
        guard let settings = settings else {
            isThinking = false
            response = AIError.missingKey.errorDescription
            scheduleAutoDismiss()
            return
        }

        currentTask = Task { [weak self] in
            do {
                let raw = try await AIRouter.generateText(prompt: prompt, settings: settings, maxTokens: 160)
                try Task.checkCancellation()
                let parsed = Self.parse(rawResponse: raw)
                await MainActor.run {
                    guard let self else { return }
                    self.isThinking = false
                    self.response = parsed.spoken
                    if let action = parsed.action {
                        self.executedAction = action
                        self.actionRunner.execute(action)
                    }
                    self.speak(parsed.spoken)
                    self.scheduleAutoDismiss()
                }
            } catch is CancellationError {
                return
            } catch let error as AIError {
                await MainActor.run {
                    self?.isThinking = false
                    self?.response = error.errorDescription ?? "Gemini error"
                    self?.scheduleAutoDismiss()
                }
            } catch {
                await MainActor.run {
                    self?.isThinking = false
                    self?.response = "Network error"
                    self?.scheduleAutoDismiss()
                }
            }
        }
    }

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        synthesizer.speak(utterance)
    }

    private func scheduleAutoDismiss() {
        autoDismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        autoDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissAfter, execute: work)
    }

    private func buildPrompt(userText: String) -> String {
        return """
        You are Gaze, a quiet macOS assistant living in the menu-bar notch.
        Reply in at most one short sentence (under 120 characters).

        If the user asks you to perform an action on the computer, output exactly two lines:
        Line 1: a single JSON object on one line: {"action":"<id>","target":"<value>"}
        Line 2: a short spoken confirmation of the action.

        Supported action ids:
        - open_app  (target: macOS app name, e.g. "Safari")
        - open_url  (target: a full https URL)
        - notify    (target: notification body text)
        - run_applescript (target: AppleScript source)

        For chit-chat, questions, or status, reply with one short sentence and no JSON.
        Never use markdown or code fences. Output plain text only.

        User said: "\(userText)"
        """
    }

    static func parse(rawResponse raw: String) -> (spoken: String, action: VoiceAction?) {
        let stripped = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")

        var action: VoiceAction?
        var spokenLines: [String] = []

        for line in stripped.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if action == nil, trimmed.hasPrefix("{"), trimmed.hasSuffix("}"),
               let parsed = parseJSONLine(trimmed) {
                action = parsed
                continue
            }
            spokenLines.append(String(line))
        }

        let spoken = spokenLines
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (spoken.isEmpty ? raw.trimmingCharacters(in: .whitespacesAndNewlines) : spoken, action)
    }

    private static func parseJSONLine(_ line: String) -> VoiceAction? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = obj["action"] as? String,
              let target = obj["target"] as? String,
              !action.isEmpty else { return nil }
        return VoiceAction(action: action, target: target)
    }
}

extension VoiceConversationCoordinator: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = true
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.speechBeat &+= 1
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.scheduleAutoDismiss()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
        }
    }
}
