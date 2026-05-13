import SwiftUI

struct NotchContentView: View {
    var geometry: NotchGeometry
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var settings: SettingsStore
    @ObservedObject var portal: PortalCoordinator
    @ObservedObject var systemObserver: SystemObserver
    @ObservedObject var screenAwareness: ScreenAwarenessService
    @ObservedObject var taskHelper: TaskHelperService
    @ObservedObject var voice: VoiceService
    @ObservedObject var voiceCoordinator: VoiceConversationCoordinator
    @State private var isHovered = false

    @State private var isRevealed = false
    @State private var swallowScale: CGFloat = 1.0
    @State private var portalGlow: Double = 0.0
    
    var shouldRetract: Bool {
        if isHovered { return false }
        
        if settings.isPeriodicPeekEnabled && !timerEngine.isPeeking {
            return true
        }
        
        if settings.hideOnInactivity && timerEngine.mode == .idle {
            return true
        }
        
        return false
    }
    
    private let hudExtraWidth: CGFloat = 180
    private let hintExtraWidth: CGFloat = 160
    private let voiceExtraHeight: CGFloat = 64
    private let voiceMinWidth: CGFloat = 360

    private var isHUDActive: Bool { systemObserver.hud != nil }
    private var isHintActive: Bool { taskHelper.currentHint != nil || taskHelper.isAnalyzing }
    private var hintText: String { taskHelper.currentHint ?? "Analyzing…" }
    private var isVoiceActive: Bool { voiceCoordinator.isActive }

    var currentWidth: CGFloat {
        if !isRevealed || shouldRetract {
            return geometry.notchRect.width
        }
        var width = geometry.extensionRect.width
        if isHUDActive { width += hudExtraWidth }
        if isHintActive && !isHUDActive { width += hintExtraWidth }
        if isVoiceActive { width = max(width, voiceMinWidth) }
        return width
    }

    var currentHeight: CGFloat {
        let base = geometry.notchRect.height
        return isVoiceActive ? base + voiceExtraHeight : base
    }

    private var rightZoneWidth: CGFloat {
        guard isRevealed && !shouldRetract else { return 0 }
        if isHUDActive { return 100 + hudExtraWidth }
        if isHintActive { return 100 + hintExtraWidth }
        return 100
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
                .contentShape(Rectangle())

            VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left area: Eyes or Play/Pause Button
                ZStack {
                    CompanionView(timerEngine: timerEngine, settings: settings, portal: portal, systemObserver: systemObserver, screenAwareness: screenAwareness, taskHelper: taskHelper, voice: voice, voiceCoordinator: voiceCoordinator)
                        .opacity(isHovered ? 0 : 1)
                        .opacity(isRevealed && !shouldRetract ? 1 : 0) // Fade eyes on expansion
                    
                    Button(action: {
                        if timerEngine.isRunning { timerEngine.pause() }
                        else { timerEngine.start() }
                    }) {
                        Image(systemName: timerEngine.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .opacity(isHovered && isRevealed && !shouldRetract ? 1 : 0)
                }
                .frame(width: isRevealed && !shouldRetract ? 80 : 0)
                .clipped()
                
                // Center area: Notch gap
                Spacer()
                    .frame(width: geometry.notchRect.width)
                
                // Right area: HUD / AI Hint / Timer
                ZStack {
                    if let hud = systemObserver.hud {
                        SystemHUDView(state: hud)
                            .padding(.horizontal, 8)
                    } else if isHintActive {
                        AIHintView(hint: hintText, isAnalyzing: taskHelper.isAnalyzing)
                            .padding(.horizontal, 8)
                    } else {
                        TimerDisplayView(engine: timerEngine)
                            .opacity(isHovered ? 0 : 1)
                            .opacity(isRevealed && !shouldRetract ? 1 : 0)

                        Button(action: {
                            timerEngine.reset()
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .opacity(isHovered && isRevealed && !shouldRetract ? 1 : 0)
                    }
                }
                .frame(width: rightZoneWidth)
                .clipped()
            }
            .frame(width: currentWidth, height: geometry.notchRect.height)

            if isVoiceActive {
                VoiceResponseView(
                    transcript: voiceCoordinator.transcript,
                    response: voiceCoordinator.response,
                    isThinking: voiceCoordinator.isThinking,
                    isSpeaking: voiceCoordinator.isSpeaking
                )
                .frame(width: currentWidth, height: voiceExtraHeight)
            }
            }
            .frame(width: currentWidth, height: currentHeight)
            .background(Color.black)
            .clipShape(NotchShape(flareRadius: 8, bottomRadius: 12))
            .overlay(
                NotchShape(flareRadius: 8, bottomRadius: 12)
                    .stroke(Color.cyan.opacity(portalGlow), lineWidth: 1.2)
                    .shadow(color: Color.cyan.opacity(portalGlow * 0.7), radius: 6)
                    .allowsHitTesting(false)
            )
            .scaleEffect(swallowScale)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: shouldRetract)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isRevealed)
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isHUDActive)
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isHintActive)
            .animation(.spring(response: 0.5, dampingFraction: 0.78), value: isVoiceActive)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    isRevealed = true
                }
            }
        }
        .onChange(of: portal.isHovering) { hovering in
            withAnimation(.easeInOut(duration: 0.25)) {
                portalGlow = hovering ? 0.9 : 0.0
            }
        }
        .onChange(of: portal.swallowPulse) { _ in
            performSwallowAnimation()
        }
    }

    private func performSwallowAnimation() {
        withAnimation(.easeIn(duration: 0.12)) {
            swallowScale = 0.82
            portalGlow = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                swallowScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                portalGlow = 0.0
            }
        }
    }
}
