import SwiftUI

/// A full‑screen welcome view that displays a bottom gradient glow
/// and an animated "Welcome to Gaze" text. The view is shown only
/// on the very first launch.
struct WelcomeView: View {
    var onDismiss: () -> Void
    
    // Animation states
    @State private var showGlow = false
    @State private var showText = false
    @State private var showButton = false
    
    // Notch Cinematic Reveal States
    @State private var showMenuBar = false
    @State private var shrinkToNotch = false
    @State private var popNotch = false
    @State private var revealEye = false
    @State private var expandToPomodoro = false
    
    var body: some View {
        ZStack {
            // Semi-circle gradient light glow at the bottom
            BottomGlowBackground(isGlowing: showGlow)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // App Logo
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .purple.opacity(0.5), radius: 20, x: 0, y: 10)
                    .scaleEffect(showText ? 1.0 : 0.8)
                    .opacity(showText ? 1.0 : 0.0)
                
                // Animated welcome text
                Text("WELCOME TO GAZE")
                    .font(.system(size: 52, weight: .heavy, design: .default))
                    .tracking(6)
                    .foregroundColor(.white.opacity(0.95))
                    .shadow(color: .purple.opacity(0.7), radius: 25, x: 0, y: 0)
                    .scaleEffect(showText ? 1.0 : 0.95)
                    .opacity(showText ? 1.0 : 0.0)
                
                // Minimal Enter Button
                Button(action: onDismiss) {
                    Text("Enter")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                .background(Capsule().fill(Color.white.opacity(0.05)))
                        )
                }
                .buttonStyle(.plain)
                .opacity(showButton ? 1.0 : 0.0)
                // Add keyboard shortcut so pressing Enter also works
                .keyboardShortcut(.defaultAction)
            }
            
            // The Cinematic Notch Reveal overlay at the top edge
            MenuBarAnimationView(
                showMenuBar: showMenuBar,
                shrinkToNotch: shrinkToNotch,
                popNotch: popNotch,
                revealEye: revealEye,
                expandToPomodoro: expandToPomodoro
            )
        }
        .background(VisualEffectView(material: .fullScreenUI, blendingMode: .behindWindow))
        .onAppear {
            // Sequence the animations
            withAnimation(.easeOut(duration: 2.5)) {
                showGlow = true
            }
            
            withAnimation(.easeOut(duration: 1.5).delay(1.5)) {
                showText = true
            }
            
            withAnimation(.easeOut(duration: 1.0).delay(2.5)) {
                showButton = true
            }
            
            // Notch Transition Sequence
            // 1. Menu bar drops in
            withAnimation(.easeOut(duration: 0.6).delay(4.0)) {
                showMenuBar = true
            }
            
            // 2. Shrinks to notch dimensions
            withAnimation(.easeInOut(duration: 0.8).delay(5.0)) {
                shrinkToNotch = true
            }
            
            // 3. Pop outward
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0).delay(6.0)) {
                popNotch = true
            }
            // Retract the pop
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.3) {
                withAnimation(.easeOut(duration: 0.2)) {
                    popNotch = false
                }
            }
            
            // 4. Reveal eye inside the notch
            withAnimation(.easeIn(duration: 0.5).delay(6.5)) {
                revealEye = true
            }
            
            // 5. Expand to normal Pomodoro notch symmetrically
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(7.2)) {
                expandToPomodoro = true
            }
        }
    }
}

/// A view that draws an imaginary semi-circle at the bottom with a 
/// white-purple gradient light glow extending to half the screen.
struct BottomGlowBackground: View {
    var isGlowing: Bool
    @State private var pulse = false
    
    var body: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.9),
                            Color.purple.opacity(0.7),
                            Color.clear
                        ]),
                        center: .bottom,
                        startRadius: 0,
                        endRadius: geo.size.height * 0.6
                    )
                )
                // Stretch horizontally so the glow spreads beautifully across the wide Mac screen
                .scaleEffect(x: 2.5, y: 1.0, anchor: .bottom)
                // Scale up dynamically as it glows
                .scaleEffect(isGlowing ? 1.0 : 0.1, anchor: .bottom)
                .opacity(isGlowing ? (pulse ? 1.0 : 0.6) : 0.0)
                .onAppear {
                    // Start pulsing once it's fully glowing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
                }
        }
    }
}

/// A view that handles the drop, shrink, pop, and reveal of the black notch overlay.
struct MenuBarAnimationView: View {
    var showMenuBar: Bool
    var shrinkToNotch: Bool
    var popNotch: Bool
    var revealEye: Bool
    var expandToPomodoro: Bool
    
    // Standard notch geometry approximation
    let menuBarHeight: CGFloat = 38
    let notchWidth: CGFloat = 200
    let leftExtension: CGFloat = 80
    let rightExtension: CGFloat = 100
    
    var currentWidth: CGFloat {
        if !shrinkToNotch { return 10000 } // Or extremely wide
        if expandToPomodoro { return leftExtension + notchWidth + rightExtension }
        return notchWidth
    }
    
    var xOffset: CGFloat {
        // Expand 80 left, 100 right -> center shifts 10 to the right
        return expandToPomodoro ? (rightExtension - leftExtension) / 2 : 0
    }
    
    var eyeXOffset: CGFloat {
        // Move to the center of the left 80pt region
        return expandToPomodoro ? -(notchWidth / 2) - (leftExtension / 2) : 0
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Black dynamic shape using actual exact Notch geometry
                NotchShape(
                    flareRadius: shrinkToNotch ? 8 : 0,
                    bottomRadius: shrinkToNotch ? 12 : 0
                )
                    .fill(Color.black)
                    .frame(
                        width: shrinkToNotch ? currentWidth : geo.size.width * 1.05,
                        height: menuBarHeight
                    )
                    // The scale effect handles the bouncy "pop"
                    .scaleEffect(popNotch ? 1.05 : 1.0)
                    .position(
                        x: (geo.size.width / 2) + xOffset,
                        y: showMenuBar ? menuBarHeight / 2 : -menuBarHeight
                    )
                
                // Eye Icons
                if revealEye {
                    HStack(spacing: 8) {
                        EyeView(blinkScale: 1.0, lookOffset: .zero, isSleeping: false, emotion: .normal)
                        EyeView(blinkScale: 1.0, lookOffset: .zero, isSleeping: false, emotion: .normal)
                    }
                        .position(
                            x: (geo.size.width / 2) + eyeXOffset,
                            y: menuBarHeight / 2
                        )
                        .transition(.opacity)
                }
                
                // Timer Text
                if expandToPomodoro {
                    Text("25:00")
                        .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(.white.opacity(0.8))
                        .position(
                            x: (geo.size.width / 2) + (notchWidth / 2) + (rightExtension / 2),
                            y: menuBarHeight / 2
                        )
                        .transition(.opacity)
                }
            }
            .ignoresSafeArea()
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(onDismiss: {})
    }
}
