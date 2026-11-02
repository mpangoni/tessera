import AppKit
import SwiftUI
import TesseraCore

/// Adds mouse-enter/exit tracking to a SwiftUI row without intercepting clicks or text input.
struct BlockHoverTracker: NSViewRepresentable {
    let onHover: (Bool) -> Void
    /// Creates the AppKit view that reports whether the pointer is over the row.
    func makeNSView(context: Context) -> HoverTrackingView {
        let view = HoverTrackingView()
        view.onHover = onHover
        return view
    }
    /// Keeps the callback current when SwiftUI refreshes this representable.
    func updateNSView(_ nsView: HoverTrackingView, context: Context) { nsView.onHover = onHover }
}

/// AppKit's tracking-area view used by `BlockHoverTracker`.
final class HoverTrackingView: NSView {
    var onHover: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?

    /// Rebuilds the tracking area when the view moves or its visible region changes.
    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    /// The pointer entered this block row.
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    /// The pointer left this block row.
    override func mouseExited(with event: NSEvent) { onHover?(false) }
    /// Let clicks pass through to the editor and its controls.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Wraps an NSTextView so SwiftUI blocks keep native macOS text selection and keyboard behavior.
struct BlockTextEditor: NSViewRepresentable {
    @Binding var text: String
    let kind: BlockKind
    let shouldFocus: Bool
    let caretOffset: Int
    let onFocus: () -> Void
    let onReturn: (NSRange) -> Bool
    let onBackspace: () -> Bool
    let onVerticalBoundary: (Bool) -> Bool

    /// Builds a coordinator that forwards native text changes back to the SwiftUI binding.
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// Creates the text storage, layout manager, and editable AppKit text view for one block.
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

    /// Syncs SwiftUI state into the native view and installs block-aware keyboard handling.
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
            // Plain Return splits a block; Backspace at offset zero merges it with the previous block.
            if event.keyCode == 36 && modifiers.isEmpty { return context.coordinator.parent.onReturn(editor.selectedRange()) }
            if event.keyCode == 51 && modifiers.isEmpty {
                let range = editor.selectedRange()
                if range.location == 0 && range.length == 0 { return context.coordinator.parent.onBackspace() }
            }
            // At a visual edge, let the document view move focus to the adjacent block.
            if (event.keyCode == 126 || event.keyCode == 125), modifiers.isEmpty,
               editor.isAtVerticalBlockBoundary(up: event.keyCode == 126) {
                return context.coordinator.parent.onVerticalBoundary(event.keyCode == 126)
            }
            return false
        }
        editor.focusHandler = { context.coordinator.parent.onFocus() }
        // SwiftUI may recreate this row after a split or merge. Restore focus and the requested caret.
        if shouldFocus, editor.window?.firstResponder !== editor {
            DispatchQueue.main.async { [weak editor] in
                guard let editor, let window = editor.window, window.firstResponder !== editor else { return }
                window.makeFirstResponder(editor)
                let length = (editor.string as NSString).length
                editor.setSelectedRange(NSRange(location: min(max(caretOffset, 0), length), length: 0))
            }
        }
    }

    /// Sizes the text view to fit its wrapped lines so a block grows instead of scrolling internally.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: TesseraNSTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, let container = nsView.textContainer, let manager = nsView.layoutManager else { return nil }
        let measuredWidth = max(80, width)
        container.containerSize = NSSize(width: measuredWidth, height: 10_000)
        manager.ensureLayout(for: container)
        let contentHeight = manager.usedRect(for: container).height + nsView.textContainerInset.height * 2 + 4
        return CGSize(width: measuredWidth, height: max(30, ceil(contentHeight)))
    }

    /// Uses larger type for headings and monospaced type for code blocks.
    private func font(for kind: BlockKind) -> NSFont {
        switch kind {
        case .heading(let level): .systemFont(ofSize: max(16, 30 - CGFloat(level * 2)), weight: .semibold)
        case .fencedCode: .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        default: .systemFont(ofSize: NSFont.systemFontSize)
        }
    }

    /// NSTextView calls this object when the user changes text with the keyboard.
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: BlockTextEditor
        init(_ parent: BlockTextEditor) { self.parent = parent }
        /// Publishes native edits to SwiftUI, which then updates the block model and Markdown document.
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView, editor.string != parent.text else { return }
            parent.text = editor.string
        }
    }
}

/// NSTextView subclass that gives Tessera first chance to handle block-level key presses.
final class TesseraNSTextView: NSTextView {
    var keyHandler: ((NSEvent) -> Bool)?
    var focusHandler: (() -> Void)?

    /// Run Tessera's key handler first; use normal AppKit text editing for unhandled keys.
    override func keyDown(with event: NSEvent) {
        if keyHandler?(event) == true { return }
        super.keyDown(with: event)
    }

    /// Reports focus changes so the document view knows which block is active.
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { focusHandler?() }
        return result
    }

    /// Checks whether the caret is on the first or last rendered line of this block.
    /// The layout manager measures visual lines, including lines created by text wrapping.
    func isAtVerticalBlockBoundary(up: Bool) -> Bool {
        guard let container = textContainer, let manager = layoutManager else { return false }
        manager.ensureLayout(for: container)
        let glyphs = manager.glyphRange(for: container)
        guard glyphs.length > 0 else { return true }
        let stringLength = (string as NSString).length
        let selection = selectedRange()
        let character = min(selection.location == stringLength ? max(0, stringLength - 1) : selection.location, max(0, stringLength - 1))
        let currentGlyph = manager.glyphIndexForCharacter(at: character)
        var currentLine = NSRange(location: 0, length: 0)
        let currentRect = manager.lineFragmentRect(forGlyphAt: currentGlyph, effectiveRange: &currentLine)
        let edgeGlyph = up ? glyphs.location : NSMaxRange(glyphs) - 1
        var edgeLine = NSRange(location: 0, length: 0)
        let edgeRect = manager.lineFragmentRect(forGlyphAt: edgeGlyph, effectiveRange: &edgeLine)
        return abs(currentRect.minY - edgeRect.minY) < 0.5
    }
}
