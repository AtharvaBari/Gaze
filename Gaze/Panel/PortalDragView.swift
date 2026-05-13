import AppKit

final class PortalDragView: NSView {
    private weak var hostedView: NSView?

    var onDragEnter: (() -> Void)?
    var onDragExit: (() -> Void)?
    var onDropString: ((String) -> Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizesSubviews = true
        registerForDraggedTypes([.string, .URL, .fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func embed(_ view: NSView) {
        hostedView?.removeFromSuperview()
        view.frame = bounds
        view.autoresizingMask = [.width, .height]
        addSubview(view)
        hostedView = view
    }

    override var isFlipped: Bool { false }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard canAccept(sender) else { return [] }
        onDragEnter?()
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return canAccept(sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExit?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        if let str = pasteboard.string(forType: .string), let handler = onDropString {
            let consumed = handler(str)
            if !consumed { onDragExit?() }
            return consumed
        }
        if let url = pasteboard.string(forType: .URL) ?? pasteboard.string(forType: .fileURL),
           let handler = onDropString {
            let consumed = handler(url)
            if !consumed { onDragExit?() }
            return consumed
        }
        onDragExit?()
        return false
    }

    private func canAccept(_ sender: NSDraggingInfo) -> Bool {
        let types = sender.draggingPasteboard.types ?? []
        return types.contains(.string) || types.contains(.URL) || types.contains(.fileURL)
    }
}
