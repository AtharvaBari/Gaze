import Foundation
import Combine
import SwiftUI
import AppKit

class EyeController: ObservableObject {
    @Published var state: EyeState = .idle {
        didSet {
            if state != oldValue {
                restartTimers()
            }
        }
    }
    
    @Published var isCursorTrackingEnabled: Bool = false {
        didSet {
            if isCursorTrackingEnabled != oldValue {
                restartTimers()
            }
        }
    }

    @Published var isListening: Bool = false {
        didSet {
            if isListening != oldValue {
                restartTimers()
            }
        }
    }

    @Published var isSpeaking: Bool = false {
        didSet {
            if isSpeaking != oldValue {
                restartTimers()
            }
        }
    }
    
    @Published var lookOffset: CGSize = .zero
    @Published var leftBlinkScale: CGFloat = 1.0
    @Published var rightBlinkScale: CGFloat = 1.0
    @Published var showsMagnifyingGlass: Bool = false
    @Published var isLeftEyePeeking: Bool = false
    @Published var currentEmotion: EyeEmotion = .normal
    @Published private(set) var gazeTarget: CGSize?
    
    // Limits
    private let maxLookDistance: CGFloat = 4.0
    
    private var blinkCancellable: AnyCancellable?
    private var lookCancellable: AnyCancellable?
    private var trackingCancellable: AnyCancellable?
    private var sleepPeekCancellable: AnyCancellable?
    private var listenShakeCancellable: AnyCancellable?
    
    private var cancellables = Set<AnyCancellable>()
    private var powerObserver = PowerObserver()
    
    private var emotionClearWorkItem: DispatchWorkItem?
    
    init() {
        startTimers()
        
        powerObserver.$isLowPower.combineLatest(powerObserver.$isCharging)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                // Maintain passive observer, but omit emojis 
            }
            .store(in: &cancellables)
            
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.performContextGlance()
        }
    }
    
    private func performContextGlance() {
        guard state != .sleeping && state != .focused else { return }
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            // Glance to the top-right corner where menu/app icons shift natively
            self.lookOffset = CGSize(width: 3.5, height: -2.5)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self = self, self.lookCancellable != nil else { return }
            self.scheduleNextLook()
        }
    }
    
    private func restartTimers() {
        stopTimers()
        
        // Retain native resting `.normal` eyes overriding temporal emojis
        self.setTempEmotion(.normal)
        
        if state == .sleeping {
            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                self.leftBlinkScale = 0.1
                self.rightBlinkScale = 0.1
                self.lookOffset = .zero
            }
        } else {
            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                self.leftBlinkScale = 1.0
                self.rightBlinkScale = 1.0
            }
        }
        startTimers()
    }
    
    private func stopTimers() {
        blinkCancellable?.cancel()
        lookCancellable?.cancel()
        trackingCancellable?.cancel()
        sleepPeekCancellable?.cancel()
        listenShakeCancellable?.cancel()
    }
    
    private func startTimers() {
        if state == .sleeping {
            scheduleSleepPeek()
            return
        }

        scheduleNextBlink()

        if isListening {
            startListenShake()
            return
        }

        if isSpeaking {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                lookOffset = .zero
            }
            return
        }

        if gazeTarget != nil {
            return
        }

        if isCursorTrackingEnabled {
            startTrackingCursor()
        } else {
            scheduleNextLook()
        }
    }

    private func startListenShake() {
        listenShakeCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let dx = CGFloat.random(in: -1.8...1.8)
                let dy = CGFloat.random(in: -1.2...1.2)
                withAnimation(.linear(duration: 0.05)) {
                    self.lookOffset = CGSize(width: dx, height: dy)
                }
            }
    }

    func pulse() {
        guard state != .sleeping else { return }
        withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.6)) {
            leftBlinkScale = 0.3
            rightBlinkScale = 0.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) { [weak self] in
            guard let self else { return }
            withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.75)) {
                self.leftBlinkScale = 1.0
                self.rightBlinkScale = 1.0
            }
        }
    }

    func setGazeTarget(_ target: CGSize?) {
        guard target != gazeTarget else { return }
        let wasPinned = gazeTarget != nil
        gazeTarget = target

        if let target = target {
            lookCancellable?.cancel()
            trackingCancellable?.cancel()
            if !wasPinned {
                scheduleNextBlink()
            }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                lookOffset = target
            }
        } else {
            restartTimers()
        }
    }
    
    private func startTrackingCursor() {
        trackingCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateLookTargetForCursor()
            }
    }
    
    private func updateLookTargetForCursor() {
        guard state != .sleeping else { return }
        
        let mouseLoc = NSEvent.mouseLocation
        if let screen = NSScreen.main {
            let eyeCenterX = screen.frame.midX
            let eyeCenterY = screen.frame.maxY - 16
            
            let dx = mouseLoc.x - eyeCenterX
            let dy = mouseLoc.y - eyeCenterY
            
            let maxDistance: CGFloat = 800
            
            let mappedX = (dx / maxDistance) * maxLookDistance
            let mappedY = (dy / maxDistance) * maxLookDistance
            
            let clampedX = max(-maxLookDistance, min(maxLookDistance, mappedX))
            let invertedMappedY = -mappedY 
            let clampedY = max(-maxLookDistance/2, min(maxLookDistance/2, invertedMappedY))
            
            withAnimation(.linear(duration: 0.05)) {
                self.lookOffset = CGSize(width: clampedX, height: clampedY)
            }
        }
    }
    
    private func scheduleNextBlink() {
        let interval = TimeInterval.random(in: state.blinkInterval)
        blinkCancellable = Just(())
            .delay(for: .seconds(interval), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.performBlink()
            }
    }
    
    private func performBlink() {
        guard state != .sleeping else { return }
        
        withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
            self.leftBlinkScale = 0.1
            self.rightBlinkScale = 0.1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self, self.state != .sleeping else { return }
            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                self.leftBlinkScale = 1.0
                self.rightBlinkScale = 1.0
            }
            self.scheduleNextBlink()
        }
    }
    
    private func scheduleSleepPeek() {
        sleepPeekCancellable = Just(())
            .delay(for: .seconds(15.0), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.performSleepPeek()
            }
    }
    
    private func performSleepPeek() {
        guard state == .sleeping else { return }
        
        let peekLeft = Bool.random()
        let hasMagnifier = Int.random(in: 1...3) == 1
        
        // Initial crack open
        withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.5)) {
            if peekLeft { self.leftBlinkScale = 1.0 }
            else { self.rightBlinkScale = 1.0 }
            
            self.showsMagnifyingGlass = hasMagnifier
            self.isLeftEyePeeking = peekLeft
            self.lookOffset = CGSize(width: CGFloat.random(in: -2...2), height: CGFloat.random(in: -1...1))
        }
        
        // Choreograph detective looks
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self, self.state == .sleeping else { return }
            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.6)) { self.lookOffset = CGSize(width: -2.5, height: 0) }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self, self.state == .sleeping else { return }
            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.6)) { self.lookOffset = CGSize(width: 2.5, height: 0) }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self = self, self.state == .sleeping else { return }
            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.6)) { self.lookOffset = CGSize(width: 0, height: -1.5) }
        }
        
        // Return to sleep after peek sequence finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self, self.state == .sleeping else { return }
            withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
                self.leftBlinkScale = 0.1
                self.rightBlinkScale = 0.1
                self.lookOffset = .zero
                self.showsMagnifyingGlass = false
            }
            self.scheduleSleepPeek()
        }
    }
    
    private func scheduleNextLook() {
        let interval = TimeInterval.random(in: state.lookInterval)
        lookCancellable = Just(())
            .delay(for: .seconds(interval), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.performLook()
            }
    }
    
    private func performLook() {
        guard state != .sleeping else { return }
        
        if state == .focused {
            // High frequency erratic shaking
            let dx = CGFloat.random(in: -2...2)
            let dy = CGFloat.random(in: -1.5...1.5)
            
            withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
                self.lookOffset = CGSize(width: dx, height: dy)
            }
            
            // 20% chance to squint erratically
            if Int.random(in: 1...5) == 1 {
                withAnimation(.interactiveSpring(response: 0.1)) {
                    self.leftBlinkScale = 0.5
                    self.rightBlinkScale = 0.5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self = self, self.state == .focused else { return }
                    withAnimation(.interactiveSpring(response: 0.1)) {
                        self.leftBlinkScale = 1.0
                        self.rightBlinkScale = 1.0
                    }
                }
            }
        } else {
            // Random look around
            let isCentered = Int.random(in: 1...3) == 1
            if isCentered {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.lookOffset = .zero
                }
            } else {
                let dx = CGFloat.random(in: -maxLookDistance...maxLookDistance)
                let dy = CGFloat.random(in: -(maxLookDistance/2)...(maxLookDistance/2))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.lookOffset = CGSize(width: dx, height: dy)
                }
            }
        }
        
        scheduleNextLook()
    }
    
    func setEmotion(_ emotion: EyeEmotion) {
        setTempEmotion(emotion)
    }

    private func setTempEmotion(_ emotion: EyeEmotion) {
        self.currentEmotion = emotion
        
        emotionClearWorkItem?.cancel()
        
        guard emotion != .normal else { return }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.currentEmotion == emotion else { return }
            self.restartTimers() // Re-evaluates state and restores native Focus/Relax emotes!
        }
        
        emotionClearWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: workItem)
    }
}
