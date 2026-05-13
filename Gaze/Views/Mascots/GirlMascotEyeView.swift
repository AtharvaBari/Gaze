import SwiftUI

private struct LashPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let lashes: [(CGFloat, CGFloat, CGFloat)] = [
            (0.10, 0.7, -2.5),
            (0.35, 0.0, -1.0),
            (0.65, 0.0,  1.0),
            (0.90, 0.7,  2.5)
        ]
        for (px, py, dx) in lashes {
            let base = CGPoint(x: rect.minX + rect.width * px, y: rect.maxY)
            let tip = CGPoint(x: base.x + dx, y: rect.minY + rect.height * py)
            path.move(to: base)
            path.addLine(to: tip)
        }
        return path
    }
}

struct GirlMascotEyeView: View {
    var blinkScale: CGFloat
    var lookOffset: CGSize
    var isSleeping: Bool
    var emotion: EyeEmotion

    var body: some View {
        ZStack {
            EyeView(blinkScale: blinkScale, lookOffset: lookOffset, isSleeping: isSleeping, emotion: emotion)

            LashPath()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                .frame(width: 16, height: 7)
                .offset(y: -11)
                .opacity(isSleeping ? 0 : Double(blinkScale))

            Image(systemName: "sparkle")
                .font(.system(size: 6, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .pink.opacity(0.7), radius: 1.5)
                .offset(x: 7, y: -7)
                .opacity(isSleeping ? 0 : Double(blinkScale))
        }
        .frame(width: 14, height: 18)
    }
}
