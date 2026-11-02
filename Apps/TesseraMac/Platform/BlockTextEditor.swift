import AppKit
import SwiftUI
import TesseraCore

struct BlockHoverTracker: NSViewRepresentable {
    let onHover: (Bool) -> Void
    func makeNSView(context: Context) -> HoverTrackingView {
        let view = HoverTrackingView()
        view.onHover = onHover
        return view
    }
    func updateNSView(_ nsView: HoverTrackingView, context: Context) { nsView.onHover = onHover }
}

final class HoverTrackingView: NSView {
    var onHover: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct BlockTextEditor: NSViewRepresentable {
    @Binding var text: String
    let kind: BlockKind
    let shouldFocus: Bool
    let caretOffset: Int
    let onFocus: () -> Void
    let onReturn: (NSRange) -> Bool
    let onBackspace: () -> Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> TesseraNSTextView {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(containerSize: NSSize(width: 640, height: 10_000))
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)
        let editor = TesseraNSTextView(frame: NSRect(x: 0, y: 0, width: 640, height: 32), textContainer: container)
        editor.delegate = context.coordinator
        editor.isRichText = false
        editor.isEditable = true
        editor.isSelectable = true
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.textContainerInset = NSSize(width: 0, height: 5)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.minSize = NSSize(width: 0, height: 28)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 640, height: 10_000)
        editor.string = text
        editor.font = font(for: kind)
        editor.textColor = .labelColor
        editor.insertionPointColor = .labelColor
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: max(80, editor.bounds.width), height: 10_000)
        editor.typingAttributes[.foregroundColor] = NSColor.labelColor
        return editor
    }

    func updateNSView(_ editor: TesseraNSTextView, context: Context) {
        context.coordinator.parent = self
        if editor.string != text {
            let selection = editor.selectedRange()
            editor.string = text
            editor.setSelectedRange(NSRange(location: min(selection.location, (text as NSString).length), length: 0))
        }
        editor.font = font(for: kind)
        editor.textColor = .labelColor
        editor.insertionPointColor = .labelColor
        editor.keyHandler = { [weak editor] event in
            guard let editor else { return false }
            let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if event.keyCode == 36 && modifiers.isEmpty { return context.coordinator.parent.onReturn(editor.selectedRange()) }
            if event.keyCode == 51 && modifiers.isEmpty {
                let range = editor.selectedRange()
                if range.location == 0 && range.length == 0 { return context.coordinator.parent.onBackspace() }
            }
            return false
        }
        editor.focusHandler = { context.coordinator.parent.onFocus() }
        if shouldFocus, editor.window?.firstResponder !== editor {
            DispatchQueue.main.async { [weak editor] in
                guard let editor, let window = editor.window, window.firstResponder !== editor else { return }
                window.makeFirstResponder(editor)
                let length = (editor.string as NSString).length
                editor.setSelectedRange(NSRange(location: min(max(caretOffset, 0), length), length: 0))
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: TesseraNSTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, let container = nsView.textContainer, let manager = nsView.layoutManager else { return nil }
        let measuredWidth = max(80, width)
        container.containerSize = NSSize(width: measuredWidth, height: 10_000)
        manager.ensureLayout(for: container)
        let contentHeight = manager.usedRect(for: container).height + nsView.textContainerInset.height * 2 + 4
        return CGSize(width: measuredWidth, height: max(30, ceil(contentHeight)))
    }

    private func font(for kind: BlockKind) -> NSFont {
        switch kind {
        case .heading(let level): .systemFont(ofSize: max(16, 30 - CGFloat(level * 2)), weight: .semibold)
        case .fencedCode: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        default: .systemFont(ofSize: NSFont.systemFontSize)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: BlockTextEditor
        init(_ parent: BlockTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView, editor.string != parent.text else { return }
            parent.text = editor.string
        }
    }
}

final class TesseraNSTextView: NSTextView {
    var keyHandler: ((NSEvent) -> Bool)?
    var focusHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) == true { return }
        super.keyDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { focusHandler?() }
        return result
    }
}
