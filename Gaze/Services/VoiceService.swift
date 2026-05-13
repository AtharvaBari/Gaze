import AVFoundation
import Foundation
import Speech

enum VoicePermissionState: Equatable {
    case unknown
    case granted
    case denied
    case partial
}

final class VoiceService: NSObject, ObservableObject {
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var transcript: String = ""
    @Published private(set) var finalTranscript: String?
    @Published private(set) var lastError: String?
    @Published private(set) var permission: VoicePermissionState = .unknown

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    override init() {
        super.init()
        refreshPermission()
    }

    deinit {
        cancel()
    }

    func refreshPermission() {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        permission = resolveState(speech: speech, mic: mic)
    }

    func requestPermissions(_ completion: ((VoicePermissionState) -> Void)? = nil) {
        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            AVCaptureDevice.requestAccess(for: .audio) { micGranted in
                let micStatus: AVAuthorizationStatus = micGranted ? .authorized : .denied
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.permission = self.resolveState(speech: speechStatus, mic: micStatus)
                    completion?(self.permission)
                }
            }
        }
    }

    func startRecording() {
        guard !isRecording else { return }

        refreshPermission()
        switch permission {
        case .granted:
            beginCapture()
        case .denied, .partial, .unknown:
            requestPermissions { [weak self] state in
                guard let self else { return }
                if state == .granted {
                    self.beginCapture()
                } else {
                    self.lastError = "Microphone or Speech permission denied"
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
        }
    }

    func cancel() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.transcript = ""
        }
    }

    // MARK: - Private

    private func resolveState(speech: SFSpeechRecognizerAuthorizationStatus,
                              mic: AVAuthorizationStatus) -> VoicePermissionState {
        let speechOK = speech == .authorized
        let micOK = mic == .authorized
        switch (speechOK, micOK) {
        case (true, true): return .granted
        case (false, false): return .denied
        case (false, _), (_, false): return .partial
        }
    }

    private func beginCapture() {
        guard let recognizer, recognizer.isAvailable else {
            lastError = "Speech recognizer unavailable"
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            recognitionRequest = nil
            lastError = "Audio engine failed: \(error.localizedDescription)"
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
            self?.transcript = ""
            self?.finalTranscript = nil
            self?.lastError = nil
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.transcript = text
                    if result.isFinal {
                        self.finalTranscript = text
                    }
                }
            }
            if error != nil || (result?.isFinal == true) {
                DispatchQueue.main.async {
                    self.isRecording = false
                }
                if self.audioEngine.isRunning {
                    self.audioEngine.stop()
                    self.audioEngine.inputNode.removeTap(onBus: 0)
                }
                self.recognitionRequest = nil
                if let error = error as NSError?, error.code != 216, error.code != 203 {
                    DispatchQueue.main.async {
                        self.lastError = error.localizedDescription
                    }
                }
            }
        }
    }
}
