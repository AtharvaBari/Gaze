import SwiftUI

enum MascotFactory {
    @ViewBuilder
    static func makeEye(
        style: MascotStyle,
        blinkScale: CGFloat,
        lookOffset: CGSize,
        isSleeping: Bool,
        emotion: EyeEmotion,
        mirrored: Bool = false
    ) -> some View {
        switch style {
        case .default:
            EyeView(blinkScale: blinkScale,
                    lookOffset: lookOffset,
                    isSleeping: isSleeping,
                    emotion: emotion)
        case .girl:
            GirlMascotEyeView(blinkScale: blinkScale,
                              lookOffset: lookOffset,
                              isSleeping: isSleeping,
                              emotion: emotion)
        case .monster:
            MonsterMascotEyeView(blinkScale: blinkScale,
                                 lookOffset: lookOffset,
                                 isSleeping: isSleeping,
                                 emotion: emotion)
        case .angry:
            AngryMascotEyeView(blinkScale: blinkScale,
                               lookOffset: lookOffset,
                               isSleeping: isSleeping,
                               emotion: emotion,
                               mirrored: mirrored)
        }
    }
}
