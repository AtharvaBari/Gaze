import CoreGraphics
import Darwin
import Foundation

final class BrightnessService {
    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let handle: UnsafeMutableRawPointer?
    private let getBrightnessFn: GetBrightnessFn?
    private let setBrightnessFn: SetBrightnessFn?

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        let lib = dlopen(path, RTLD_LAZY)
        handle = lib

        if let lib, let symbol = dlsym(lib, "DisplayServicesGetBrightness") {
            getBrightnessFn = unsafeBitCast(symbol, to: GetBrightnessFn.self)
        } else {
            getBrightnessFn = nil
        }

        if let lib, let symbol = dlsym(lib, "DisplayServicesSetBrightness") {
            setBrightnessFn = unsafeBitCast(symbol, to: SetBrightnessFn.self)
        } else {
            setBrightnessFn = nil
        }
    }

    deinit {
        if let handle { dlclose(handle) }
    }

    var isAvailable: Bool {
        getBrightnessFn != nil && setBrightnessFn != nil
    }

    func currentBrightness() -> Double? {
        guard let getBrightnessFn,
              let displayID = internalDisplayID() else { return nil }
        var value: Float = 0
        let status = getBrightnessFn(displayID, &value)
        guard status == 0 else { return nil }
        return Double(max(0, min(1, value)))
    }

    @discardableResult
    func setBrightness(_ value: Double) -> Bool {
        guard let setBrightnessFn,
              let displayID = internalDisplayID() else { return false }
        let clamped = Float(max(0, min(1, value)))
        return setBrightnessFn(displayID, clamped) == 0
    }

    private func internalDisplayID() -> CGDirectDisplayID? {
        let main = CGMainDisplayID()
        if CGDisplayIsBuiltin(main) != 0 {
            return main
        }

        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else {
            return nil
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return nil }
        return ids.first(where: { CGDisplayIsBuiltin($0) != 0 })
    }
}
