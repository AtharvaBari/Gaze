import SwiftUI

struct VoiceResponseView: View {
    let transcript: String
    let response: String?
    let isThinking: Bool
    let isSpeaking: Bool

    @State private var dotPhase: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !transcript.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                    Text(transcript)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: speakerIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.95), Color.cyan.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if isThinking {
                    ThinkingDots(phase: dotPhase)
                } else if let response, !response.isEmpty {
                    Text(response)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .truncationMode(.tail)
                } else {
                    Text("")
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                dotPhase = 3
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private var speakerIcon: String {
        if isThinking { return "sparkles" }
        if isSpeaking { return "speaker.wave.2.fill" }
        return "sparkles"
    }
}

private struct ThinkingDots: View {
    var phase: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(opacity(for: i)))
                    .frame(width: 4, height: 4)
            }
        }
    }

    private func opacity(for index: Int) -> Double {
        let active = phase % 3
        return active == index ? 0.95 : 0.35
    }
}
