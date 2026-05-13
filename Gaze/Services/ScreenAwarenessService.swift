import AppKit
import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import ScreenCaptureKit

struct ScreenAwarenessFrame {
    let image: CGImage
    let appName: String?
    let bundleID: String?
    let timestamp: Date
}

protocol ScreenAwarenessDelegate: AnyObject {
    func screenAwareness(_ service: ScreenAwarenessService, didCapture frame: ScreenAwarenessFrame)
}

final class ScreenAwarenessService: NSObject, ObservableObject {
    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var hasPermission: Bool = ScreenRecordingPermission.isGranted
    @Published private(set) var frontmostAppName: String?
    @Published private(set) var frontmostBundleID: String?

    weak var delegate: ScreenAwarenessDelegate?

    private let sampleQueue = DispatchQueue(label: "com.gaze.screenAwareness.samples", qos: .userInitiated)
    private let ciContext = CIContext(options: nil)

    private var stream: SCStream?
    private var streamOutput: ScreenStreamOutput?
    private var workspaceObserver: NSObjectProtocol?
    private var isWorkMode: Bool = false
    private var startInFlight: Bool = false

    override init() {
        super.init()
        captureFrontmostApp(NSWorkspace.shared.frontmostApplication)
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.handleFrontmostChange(app)
        }
    }

    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        Task { [stream] in
            try? await stream?.stopCapture()
        }
    }

    func setWorkMode(_ active: Bool) {
        guard isWorkMode != active else { return }
        isWorkMode = active
        Task { await reconcile() }
    }

    func requestOneShotAnalysis() async {
        guard isWorkMode else { return }
        await startIfPossible()
    }

    private func handleFrontmostChange(_ app: NSRunningApplication?) {
        let ownBundle = Bundle.main.bundleIdentifier
        if let bundleID = app?.bundleIdentifier, bundleID == ownBundle {
            return
        }
        captureFrontmostApp(app)
        Task { await reconcile() }
    }

    private func captureFrontmostApp(_ app: NSRunningApplication?) {
        DispatchQueue.main.async { [weak self] in
            self?.frontmostAppName = app?.localizedName
            self?.frontmostBundleID = app?.bundleIdentifier
        }
    }

    @MainActor
    private func setCapturing(_ value: Bool) {
        isCapturing = value
    }

    @MainActor
    private func setPermission(_ value: Bool) {
        hasPermission = value
    }

    private func reconcile() async {
        if isWorkMode, let bundleID = frontmostBundleID, bundleID != Bundle.main.bundleIdentifier {
            await startIfPossible()
        } else {
            await stopCapture()
        }
    }

    private func startIfPossible() async {
        guard !startInFlight else { return }
        startInFlight = true
        defer { startInFlight = false }

        let granted = ScreenRecordingPermission.isGranted
        await setPermission(granted)
        guard granted else {
            _ = ScreenRecordingPermission.request()
            return
        }

        await stopCapture()

        guard let bundleID = frontmostBundleID else { return }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else { return }

            let filter: SCContentFilter
            if let scApp = content.applications.first(where: { $0.bundleIdentifier == bundleID }) {
                filter = SCContentFilter(display: display, including: [scApp], exceptingWindows: [])
            } else {
                filter = SCContentFilter(display: display, excludingWindows: [])
            }

            let config = SCStreamConfiguration()
            config.width = Int(display.width)
            config.height = Int(display.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            config.queueDepth = 2
            config.showsCursor = false
            config.scalesToFit = true

            let output = ScreenStreamOutput()
            output.frameHandler = { [weak self] cgImage in
                self?.deliverFrame(cgImage)
            }
            output.imageBuilder = { [weak self] buffer in
                self?.buildCGImage(from: buffer)
            }

            let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
            try newStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: sampleQueue)
            try await newStream.startCapture()

            stream = newStream
            streamOutput = output
            await setCapturing(true)
        } catch {
            await setCapturing(false)
        }
    }

    private func stopCapture() async {
        guard let active = stream else {
            await setCapturing(false)
            return
        }
        do {
            try await active.stopCapture()
        } catch {
        }
        stream = nil
        streamOutput = nil
        await setCapturing(false)
    }

    private func deliverFrame(_ image: CGImage) {
        let name = frontmostAppName
        let bundle = frontmostBundleID
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let frame = ScreenAwarenessFrame(
                image: image,
                appName: name,
                bundleID: bundle,
                timestamp: Date()
            )
            self.delegate?.screenAwareness(self, didCapture: frame)
        }
    }

    private func buildCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
}

private final class ScreenStreamOutput: NSObject, SCStreamOutput {
    var frameHandler: ((CGImage) -> Void)?
    var imageBuilder: ((CVPixelBuffer) -> CGImage?)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first,
              let rawStatus = attachments[.status] as? Int,
              let status = SCFrameStatus(rawValue: rawStatus),
              status == .complete,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        guard let cgImage = imageBuilder?(pixelBuffer) else { return }
        frameHandler?(cgImage)
    }
}
