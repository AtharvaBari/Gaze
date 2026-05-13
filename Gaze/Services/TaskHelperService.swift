import AppKit
import CoreGraphics
import Foundation

final class TaskHelperService: ObservableObject {
    @Published private(set) var currentHint: String?
    @Published private(set) var isAnalyzing: Bool = false
    @Published private(set) var lastError: String?

    private weak var settings: SettingsStore?
    private var analysisTask: Task<Void, Never>?
    private var lastAnalysisAt: Date = .distantPast
    private let minAnalysisInterval: TimeInterval = 30.0
    private let maxImageDimension: CGFloat = 1024
    private let backoffOnError: TimeInterval = 60.0

    init(settings: SettingsStore? = nil) {
        self.settings = settings
    }

    func ingest(frame: ScreenAwarenessFrame) {
        let now = Date()
        guard now.timeIntervalSince(lastAnalysisAt) >= minAnalysisInterval else { return }
        lastAnalysisAt = now
        analyzeContext(image: frame.image, appName: frame.appName)
    }

    func analyzeContext(image: CGImage, appName: String? = nil) {
        guard let settings = settings else {
            publish(error: AIError.missingKey.errorDescription)
            return
        }
        guard !settings.currentProviderAPIKey.isEmpty else {
            publish(error: AIError.missingKey.errorDescription)
            return
        }

        let label = appName?.isEmpty == false ? appName! : "the active window"
        let prompt = """
        You are looking at a screenshot of the macOS app "\(label)". \
        Reply with ONE short, actionable productivity hint (under 80 characters) \
        based on what the user appears to be doing. Output the hint only — no preamble, \
        no quotes, no markdown.
        """

        guard let jpegData = encodeJPEG(image) else {
            publish(error: "Could not encode screenshot")
            return
        }

        analysisTask?.cancel()
        DispatchQueue.main.async { [weak self] in
            self?.isAnalyzing = true
            self?.lastError = nil
        }

        analysisTask = Task { [weak self] in
            do {
                let hint = try await AIRouter.generateHint(
                    prompt: prompt,
                    imageJPEG: jpegData,
                    settings: settings
                )
                try Task.checkCancellation()
                await MainActor.run {
                    guard let self else { return }
                    self.currentHint = hint
                    self.isAnalyzing = false
                    self.lastError = nil
                }
            } catch is CancellationError {
                return
            } catch let error as AIError {
                self?.handleAIError(error)
            } catch {
                self?.handleNetworkError(error)
            }
        }
    }

    func summarize(url: URL) {
        guard let settings = settings else {
            publish(error: AIError.missingKey.errorDescription)
            return
        }
        guard !settings.currentProviderAPIKey.isEmpty else {
            publish(error: AIError.missingKey.errorDescription)
            return
        }

        analysisTask?.cancel()
        DispatchQueue.main.async { [weak self] in
            self?.isAnalyzing = true
            self?.lastError = nil
        }

        let prompt = """
        Summarize the likely content of this URL in one short sentence \
        (under 100 characters). URL: \(url.absoluteString)
        """

        analysisTask = Task { [weak self] in
            do {
                let summary = try await AIRouter.generateText(prompt: prompt, settings: settings)
                try Task.checkCancellation()
                await MainActor.run {
                    guard let self else { return }
                    self.currentHint = summary
                    self.isAnalyzing = false
                }
            } catch is CancellationError {
                return
            } catch let error as AIError {
                self?.handleAIError(error)
            } catch {
                self?.handleNetworkError(error)
            }
        }
    }

    func clear() {
        analysisTask?.cancel()
        analysisTask = nil
        DispatchQueue.main.async { [weak self] in
            self?.currentHint = nil
            self?.isAnalyzing = false
            self?.lastError = nil
        }
        lastAnalysisAt = .distantPast
    }

    func cancelAll() {
        analysisTask?.cancel()
        analysisTask = nil
    }

    // MARK: - Helpers

    private func handleAIError(_ error: AIError) {
        let backoffApplied: Bool
        switch error {
        case .rateLimited, .badResponse:
            backoffApplied = true
        default:
            backoffApplied = false
        }
        if backoffApplied {
            lastAnalysisAt = Date().addingTimeInterval(backoffOnError - minAnalysisInterval)
        }
        publish(error: error.errorDescription)
    }

    private func handleNetworkError(_ error: Error) {
        lastAnalysisAt = Date().addingTimeInterval(backoffOnError - minAnalysisInterval)
        let nsError = error as NSError
        let message: String
        if nsError.domain == NSURLErrorDomain {
            message = "Network unavailable"
        } else {
            message = "Unable to reach Gemini"
        }
        publish(error: message)
    }

    private func publish(error: String?) {
        DispatchQueue.main.async { [weak self] in
            self?.lastError = error
            self?.isAnalyzing = false
        }
    }

    private func encodeJPEG(_ image: CGImage) -> Data? {
        let source = resized(image: image, maxDimension: maxImageDimension) ?? image
        let bitmap = NSBitmapImageRep(cgImage: source)
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }

    private func resized(image: CGImage, maxDimension: CGFloat) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let longest = max(width, height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newWidth = Int((width * scale).rounded())
        let newHeight = Int((height * scale).rounded())
        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }
}
