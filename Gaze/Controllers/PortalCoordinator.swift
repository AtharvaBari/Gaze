import Foundation
import Combine

final class PortalCoordinator: ObservableObject {
    @Published var isHovering: Bool = false
    @Published private(set) var lastCapture: PortalCapture?
    @Published private(set) var swallowPulse: Int = 0

    func beginHover() {
        isHovering = true
    }

    func endHover() {
        isHovering = false
    }

    func swallow(_ capture: PortalCapture) {
        lastCapture = capture
        swallowPulse &+= 1
        isHovering = false
    }
}
