import SwiftUI

struct PrivacyIndicator: View {
    var isActive: Bool

    @State private var pulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.35))
                .frame(width: 8, height: 8)
                .scaleEffect(isActive ? pulse : 0.8)
                .blur(radius: isActive ? 1.5 : 0)

            Circle()
                .fill(Color.red.opacity(0.95))
                .frame(width: 4, height: 4)
                .shadow(color: .red.opacity(0.7), radius: 2)
        }
        .opacity(isActive ? 1 : 0)
        .onChange(of: isActive) { active in
            if active {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = 1.6
                }
            } else {
                pulse = 1.0
            }
        }
    }
}
