import SwiftUI

private struct AngryLid: Shape {
    var mirrored: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let highOuter = mirrored ? rect.maxY * 0.55 : rect.minY
        let highInner = mirrored ? rect.minY : rect.maxY * 0.55
        path.move(to: CGPoint(x: rect.minX, y: highOuter))
        path.addLine(to: CGPoint(x: rect.maxX, y: highInner))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct AngryMascotEyeView: View {
    var blinkScale: CGFloat
    var lookOffset: CGSize
    var isSleeping: Bool
    var emotion: EyeEmotion
    var mirrored: Bool = false

    var body: some View {
        ZStack {
            EyeView(blinkScale: blinkScale, lookOffset: lookOffset, isSleeping: isSleeping, emotion: emotion)
                .shadow(color: Color.red.opacity(isSleeping ? 0.0 : 0.85), radius: 4)
                .shadow(color: Color.red.opacity(isSleeping ? 0.0 : 0.5), radius: 8)

            AngryLid(mirrored: mirrored)
                .fill(Color.black)
                .frame(width: 16, height: 12)
                .offset(y: -6)
                .opacity(isSleeping ? 0 : 1)
                .scaleEffect(y: blinkScale, anchor: .top)
        }
        .frame(width: 14, height: 18)
    }
}
