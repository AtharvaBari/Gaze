import SwiftUI

struct MonsterMascotEyeView: View {
    var blinkScale: CGFloat
    var lookOffset: CGSize
    var isSleeping: Bool
    var emotion: EyeEmotion

    private let pupilOffsets: [CGSize] = [
        CGSize(width: -3, height: -3),
        CGSize(width:  3, height: -2),
        CGSize(width:  0, height:  3)
    ]

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.78, green: 0.95, blue: 0.78))
                .frame(width: 14, height: 18)

            ZStack {
                if let emoji = emotion.emoji {
                    Text(emoji)
                        .font(.system(size: 14))
                        .offset(lookOffset)
                } else {
                    ForEach(0..<pupilOffsets.count, id: \.self) { i in
                        Circle()
                            .fill(Color(white: 0.08))
                            .frame(width: 4, height: 4)
                            .overlay(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 1.4, height: 1.4)
                                    .offset(x: -0.6, y: -0.8)
                            )
                            .offset(pupilOffsets[i])
                            .offset(lookOffset)
                    }
                }
            }
            .clipShape(Capsule())

            SleepCurve()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 12, height: 6)
                .offset(y: 4)
                .opacity(isSleeping ? 1.0 : 0.0)
        }
        .frame(width: 14, height: 18)
        .scaleEffect(y: isSleeping ? 0.05 : blinkScale)
        .animation(.easeInOut(duration: 0.2), value: isSleeping)
    }
}
