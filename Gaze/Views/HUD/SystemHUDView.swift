import SwiftUI

struct SystemHUDView: View {
    let state: SystemHUDState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, Color.white.opacity(0.78)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 16, height: 16)
                .shadow(color: .black.opacity(0.45), radius: 1.5, y: 0.5)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.6)
                        )

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color.white.opacity(0.72),
                                    Color.white.opacity(0.10)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, proxy.size.width * CGFloat(clampedValue)))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.95), Color.white.opacity(0.0)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .white.opacity(0.45), radius: 3.5)
                        .shadow(color: .white.opacity(0.18), radius: 8)
                }
            }
            .frame(height: 10)

            Text("\(Int(round(clampedValue * 100)))")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .frame(width: 28, alignment: .trailing)
                .shadow(color: .black.opacity(0.35), radius: 1, y: 0.5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(glassBackground)
        .overlay(borderStroke)
        .overlay(innerHighlight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: clampedValue)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .center)),
            removal: .opacity
        ))
    }

    private var clampedValue: Double {
        max(0, min(1, state.value))
    }

    private var iconName: String {
        switch state.kind {
        case .brightness:
            return "sun.max.fill"
        case .volume:
            switch clampedValue {
            case ..<0.01: return "speaker.slash.fill"
            case ..<0.34: return "speaker.wave.1.fill"
            case ..<0.67: return "speaker.wave.2.fill"
            default:      return "speaker.wave.3.fill"
            }
        }
    }

    private var glassBackground: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow, emphasized: true)
                .opacity(0.92)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.14),
                    Color.white.opacity(0.02),
                    Color.white.opacity(0.06)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var borderStroke: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.45),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
    }

    private var innerHighlight: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
            .blur(radius: 0.6)
            .padding(0.6)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }
}
