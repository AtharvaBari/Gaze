import AppKit
import QuartzCore
import SwiftUI

final class NotchPanel: NSPanel {
    private(set) var baseFrame: NSRect
    private(set) var notchAnchorX: CGFloat

    init(contentRect: NSRect, notchAnchorX: CGFloat? = nil) {
        self.baseFrame = contentRect
        self.notchAnchorX = notchAnchorX ?? contentRect.midX
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovable = false
        self.becomesKeyOnlyIfNeeded = true
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func setContent(_ view: some View) {
        let hosting = NSHostingView(rootView: view)
        let portal = PortalDragView(frame: NSRect(origin: .zero, size: self.frame.size))
        portal.embed(hosting)
        self.contentView = portal
    }

    func setPortalHandlers(onEnter: @escaping () -> Void,
                           onExit: @escaping () -> Void,
                           onDrop: @escaping (String) -> Bool) {
        guard let portal = self.contentView as? PortalDragView else { return }
        portal.onDragEnter = onEnter
        portal.onDragExit = onExit
        portal.onDropString = onDrop
    }

    func updateBaseFrame(_ frame: NSRect, anchorX: CGFloat? = nil, animated: Bool = true) {
        self.baseFrame = frame
        self.notchAnchorX = anchorX ?? frame.midX
        applyFrame(frame, animated: animated)
    }

    func resizeWidth(to width: CGFloat, animated: Bool = true) {
        applyExpansion(width: width, height: self.frame.height, animated: animated)
    }

    func resizeHeight(to height: CGFloat, animated: Bool = true) {
        applyExpansion(width: self.frame.width, height: height, animated: animated)
    }

    func restoreWidth(animated: Bool = true) {
        applyExpansion(width: baseFrame.width, height: self.frame.height, animated: animated)
    }

    func restoreHeight(animated: Bool = true) {
        applyExpansion(width: self.frame.width, height: baseFrame.height, animated: animated)
    }

    func restoreBaseFrame(animated: Bool = true) {
        applyFrame(baseFrame, animated: animated)
    }

    private func applyExpansion(width: CGFloat, height: CGFloat, animated: Bool) {
        let originX = notchAnchorX - width / 2
        let topY = baseFrame.maxY
        let target = NSRect(x: originX, y: topY - height, width: width, height: height)
        applyFrame(target, animated: animated)
    }

    private func applyFrame(_ frame: NSRect, animated: Bool) {
        guard animated else {
            self.setFrame(frame, display: true)
            return
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.45
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
            ctx.allowsImplicitAnimation = true
            self.animator().setFrame(frame, display: true)
        }
    }
}
