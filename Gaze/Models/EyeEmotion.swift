import Foundation

enum EyeEmotion: String, Equatable, CaseIterable {
    case normal
    case fire
    case lightning
    case code

    case coffee
    case burger
    case music

    case charging
    case lowBattery

    case surprised

    var emoji: String? {
        switch self {
        case .normal: return nil
        case .fire: return "🔥"
        case .lightning: return "⚡️"
        case .code: return "💻"

        case .coffee: return "☕️"
        case .burger: return "🍔"
        case .music: return "🎵"

        case .charging: return "⚡️"
        case .lowBattery: return "🪫"

        case .surprised: return "😲"
        }
    }
    
    static var randomFocused: EyeEmotion {
        return [.normal, .normal, .fire, .lightning, .code].randomElement()!
    }
    
    static var randomRelaxed: EyeEmotion {
        return [.normal, .coffee, .burger, .music].randomElement()!
    }
}
