import Foundation

enum MascotStyle: String, CaseIterable, Identifiable, Equatable {
    case `default`
    case girl
    case monster
    case angry

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .girl:    return "Girl"
        case .monster: return "Monster"
        case .angry:   return "Angry"
        }
    }
}
