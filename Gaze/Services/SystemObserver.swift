import AppKit
import AudioToolbox
import CoreAudio
import Foundation

enum SystemHUDKind: Equatable {
    case brightness
    case volume
}

struct SystemHUDState: Equatable {
    let kind: SystemHUDKind
    let value: Double
}

final class SystemObserver: ObservableObject {
    @Published private(set) var hud: SystemHUDState?

    static let brightnessNotification = Notification.Name("com.apple.multitouchsupport.HID.B31.BrightnessChange")
    static let musicNotification = Notification.Name("com.apple.music.playerInfo")

    private let autoHideDelay: TimeInterval = 2.0
    private var hideWorkItem: DispatchWorkItem?

    private let brightnessService = BrightnessService()

    private var currentOutputDevice: AudioDeviceID = AudioDeviceID(kAudioObjectUnknown)
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?

    private static var volumePropertyAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static var defaultDeviceAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    init() {
        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(self,
                        selector: #selector(handleBrightness(_:)),
                        name: Self.brightnessNotification,
                        object: nil)
        dnc.addObserver(self,
                        selector: #selector(handleMusicInfo(_:)),
                        name: Self.musicNotification,
                        object: nil)

        startVolumeListening()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        stopVolumeListening()
        hideWorkItem?.cancel()
    }

    func simulate(_ state: SystemHUDState) {
        present(state)
    }

    @objc private func handleBrightness(_ note: Notification) {
        let value = brightnessService.currentBrightness() ?? 0.5
        present(SystemHUDState(kind: .brightness, value: value))
    }

    @objc private func handleMusicInfo(_ note: Notification) {
        publishCurrentVolume()
    }

    private func present(_ state: SystemHUDState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hud = state
            self.scheduleAutoHide()
        }
    }

    private func scheduleAutoHide() {
        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.hud = nil
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoHideDelay, execute: work)
    }

    // MARK: - CoreAudio

    private func startVolumeListening() {
        attachDefaultDeviceListener()
        rebindToDefaultOutputDevice()
    }

    private func stopVolumeListening() {
        detachVolumeListener()
        detachDefaultDeviceListener()
    }

    private func attachDefaultDeviceListener() {
        var address = Self.defaultDeviceAddress
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.rebindToDefaultOutputDevice()
        }
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
        if status == noErr {
            defaultDeviceListenerBlock = block
        }
    }

    private func detachDefaultDeviceListener() {
        guard let block = defaultDeviceListenerBlock else { return }
        var address = Self.defaultDeviceAddress
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )
        defaultDeviceListenerBlock = nil
    }

    private func rebindToDefaultOutputDevice() {
        detachVolumeListener()
        currentOutputDevice = Self.fetchDefaultOutputDevice()
        guard currentOutputDevice != AudioDeviceID(kAudioObjectUnknown) else { return }
        attachVolumeListener(to: currentOutputDevice)
    }

    private func attachVolumeListener(to deviceID: AudioDeviceID) {
        var address = Self.volumePropertyAddress
        guard AudioObjectHasProperty(deviceID, &address) else { return }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.publishCurrentVolume()
        }
        let status = AudioObjectAddPropertyListenerBlock(deviceID, &address, DispatchQueue.main, block)
        if status == noErr {
            volumeListenerBlock = block
        }
    }

    private func detachVolumeListener() {
        guard let block = volumeListenerBlock,
              currentOutputDevice != AudioDeviceID(kAudioObjectUnknown) else { return }
        var address = Self.volumePropertyAddress
        AudioObjectRemovePropertyListenerBlock(currentOutputDevice, &address, DispatchQueue.main, block)
        volumeListenerBlock = nil
    }

    private func publishCurrentVolume() {
        guard let value = Self.readVolume(for: currentOutputDevice) else { return }
        present(SystemHUDState(kind: .volume, value: value))
    }

    private static func fetchDefaultOutputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = defaultDeviceAddress
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size,
            &deviceID
        )
        return status == noErr ? deviceID : AudioDeviceID(kAudioObjectUnknown)
    }

    private static func readVolume(for deviceID: AudioDeviceID) -> Double? {
        guard deviceID != AudioDeviceID(kAudioObjectUnknown) else { return nil }
        var address = volumePropertyAddress
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        guard status == noErr else { return nil }
        return Double(max(0, min(1, volume)))
    }

}
