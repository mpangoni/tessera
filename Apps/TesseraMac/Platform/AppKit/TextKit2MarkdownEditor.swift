import AppKit
import SwiftUI
import TesseraCore

/// Embeds one editable TextKit 2 text view for the complete Markdown document.
struct TextKit2MarkdownEditor: NSViewRepresentable {
    @Binding var markdown: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// Creates the native scroll view and its single TextKit 2 text view.
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        // Keep NSScrollView scrolling active while omitting its visible scrollbar.
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = TesseraTextKit2View(usingTextLayoutManager: true)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.drawsBackground = false
        // Reserve a slim fixed gutter so hover controls never shift document text.
        textView.textContainerInset = NSSize(width: TesseraTextKit2View.textInset, height: 5)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 40)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 640, height: CGFloat.greatestFiniteMagnitude)
        textView.string = markdown
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.returnHandler = { [weak textView, weak coordinator = context.coordinator] selection in
            guard let textView, let coordinator else { return false }
            return coordinator.splitBlock(in: textView, selection: selection)
        }
        textView.backspaceHandler = { [weak textView, weak coordinator = context.coordinator] offset in
            guard let textView, let coordinator else { return false }
            return coordinator.mergeBlock(in: textView, offset: offset)
        }
        context.coordinator.configure(textView)

        scrollView.documentView = textView
        applyMarkdownStyles(to: textView)
        return scrollView
    }

    /// Synchronizes externally loaded Markdown without moving the user's caret unnecessarily.
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if let textView = textView as? TesseraTextKit2View {
            textView.returnHandler = { [weak textView, weak coordinator = context.coordinator] selection in
                guard let textView, let coordinator else { return false }
                return coordinator.splitBlock(in: textView, selection: selection)
            }
            textView.backspaceHandler = { [weak textView, weak coordinator = context.coordinator] offset in
                guard let textView, let coordinator else { return false }
                return coordinator.mergeBlock(in: textView, offset: offset)
            }
        }
        if textView.string != markdown {
            let selection = textView.selectedRange()
            textView.string = markdown
            let length = (markdown as NSString).length
            textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
        }
        context.coordinator.configure(textView)
        applyMarkdownStyles(to: textView)
    }

    /// Delegates all source-based styling to the registered Markdown decoration renderers.
    private func applyMarkdownStyles(to textView: NSTextView) {
        guard let textView = textView as? TesseraTextKit2View else { return }
        let ast = MarkdownASTParser.parse(textView.string)
        MarkdownTextDecorationPipeline.apply(source: textView.string, ast: ast, to: textView)
        textView.updateBlockStructure(ast.root.children)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, @preconcurrency NSTextLayoutManagerDelegate {
        var parent: TextKit2MarkdownEditor
        private weak var activeTextView: NSTextView?
        private var activeBlockRanges: [NSRange] = []
        private var activeBlockIndex: Int?
        private var activeSourceOffset = 0
        init(_ parent: TextKit2MarkdownEditor) { self.parent = parent }

        /// Publishes native text edits as Markdown and reapplies source-derived display styling.
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.markdown = textView.string
            configure(textView)
            parent.applyMarkdownStyles(to: textView)
        }

        /// Installs native TextKit 2 drawing for quote fragments and refreshes quote ranges.
        func configure(_ textView: NSTextView) {
            activeTextView = textView
            if let textView = textView as? TesseraTextKit2View {
                configureControls(on: textView)
            }
            decorationNodes = MarkdownTextDecorationPipeline.flattenedNodes(in: MarkdownASTParser.parse(textView.string))
            textView.textLayoutManager?.delegate = self
        }

        /// Supplies a quote-aware layout fragment so its decoration scrolls with TextKit content.
        func textLayoutManager(
            _ textLayoutManager: NSTextLayoutManager,
            textLayoutFragmentFor location: NSTextLocation,
            in textElement: NSTextElement
        ) -> NSTextLayoutFragment {
            guard let content = activeTextView?.textContentStorage else {
                return NSTextLayoutFragment(textElement: textElement, range: nil)
            }
            let offset = content.offset(from: content.documentRange.location, to: location)
            return MarkdownTextDecorationPipeline.layoutFragment(
                for: textElement,
                at: offset,
                nodes: decorationNodes
            ) ?? NSTextLayoutFragment(textElement: textElement, range: nil)
        }

        /// Adds block operations to AppKit's native context menu at the clicked source position.
        func textView(_ textView: NSTextView, menu: NSMenu, for event: NSEvent, at charIndex: Int) -> NSMenu? {
            let root = MarkdownASTParser.parse(textView.string).root
            activeBlockRanges = root.children.compactMap(\.sourceRange)
            activeBlockIndex = activeBlockRanges.firstIndex { NSLocationInRange(charIndex, $0) }
            activeSourceOffset = charIndex
            activeTextView = textView
            configureControls(on: textView)
            guard let activeBlockIndex else { return menu }

            menu.addItem(.separator())
            addMenuItem("Delete Block", action: #selector(deleteBlock(_:)), menu: menu)
            addMenuItem("Move Block Up", action: #selector(moveBlockUp(_:)), menu: menu, enabled: activeBlockIndex > 0)
            addMenuItem("Move Block Down", action: #selector(moveBlockDown(_:)), menu: menu, enabled: activeBlockIndex + 1 < activeBlockRanges.count)
            return menu
        }

        @objc private func deleteBlock(_ sender: Any?) {
            guard let textView = activeTextView,
                  let edit = MarkdownSourceCommands.deleteBlock(at: activeSourceOffset, in: textView.string) else { return }
            apply(edit, to: textView)
        }

        @objc private func moveBlockUp(_ sender: Any?) { moveBlock(by: -1) }
        @objc private func moveBlockDown(_ sender: Any?) { moveBlock(by: 1) }

        private func moveBlock(by distance: Int) {
            guard let textView = activeTextView,
                  let edit = MarkdownSourceCommands.moveBlock(
                    at: activeSourceOffset,
                    by: distance,
                    caretOffset: textView.selectedRange().location,
                    in: textView.string
                  ) else { return }
            apply(edit, to: textView)
        }

        private func apply(_ edit: MarkdownSourceEdit, to textView: NSTextView) {
            textView.insertText(edit.replacement, replacementRange: edit.range)
            textView.setSelectedRange(NSRange(location: min(edit.caretOffset, (textView.string as NSString).length), length: 0))
        }

        func splitBlock(in textView: NSTextView, selection: NSRange) -> Bool {
            guard let edit = MarkdownSourceCommands.splitBlock(replacing: selection, in: textView.string) else { return false }
            apply(edit, to: textView)
            return true
        }

        func mergeBlock(in textView: NSTextView, offset: Int) -> Bool {
            guard let edit = MarkdownSourceCommands.mergePreviousBlock(at: offset, in: textView.string) else { return false }
            apply(edit, to: textView)
            return true
        }

        private func addMenuItem(_ title: String, action: Selector, menu: NSMenu, enabled: Bool = true) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.isEnabled = enabled
            menu.addItem(item)
        }

        func configureControls(on textView: NSTextView) {
            guard let textView = textView as? TesseraTextKit2View else { return }
            textView.onDeleteBlock = { [weak self, weak textView] sourceOffset in
                guard let self, let textView,
                      let edit = MarkdownSourceCommands.deleteBlock(at: sourceOffset, in: textView.string) else { return }
                self.apply(edit, to: textView)
            }
            textView.onMoveBlock = { [weak self, weak textView] sourceOffset, targetOffset in
                guard let self, let textView,
                      let edit = MarkdownSourceCommands.moveBlock(
                        at: sourceOffset,
                        to: targetOffset,
                        caretOffset: textView.selectedRange().location,
                        in: textView.string
                      ) else { return }
                self.apply(edit, to: textView)
            }
        }

        private var decorationNodes: [MarkdownASTNode] = []
    }
}

/// Sends block-boundary keys to Core commands and leaves all other typing to native TextKit behavior.
final class TesseraTextKit2View: NSTextView {
    nonisolated static let textInset: CGFloat = 30

    var returnHandler: ((NSRange) -> Bool)?
    var backspaceHandler: ((Int) -> Bool)?
    var onDeleteBlock: ((Int) -> Void)?
    var onMoveBlock: ((Int, Int) -> Void)?
    private var blockNodes: [MarkdownASTNode] = []
    private var hoveredBlock: MarkdownASTNode?
    private var dragSourceOffset: Int?
    private let moveButton = BlockActionButton(symbolName: "line.3.horizontal", label: "Drag to reorder block")
    private let deleteButton = BlockActionButton(symbolName: "trash", label: "Delete block")

    override func updateTrackingAreas() {
        for area in trackingAreas { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        super.updateTrackingAreas()
        installButtonsIfNeeded()
    }

    /// Repositions controls when the document view is resized.
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateControlFrames()
    }

    /// Receives the current parse's block ranges and updates controls for the hovered block.
    func updateBlockStructure(_ nodes: [MarkdownASTNode]) {
        blockNodes = nodes
        if let hoveredBlock, !nodes.contains(where: { $0.id == hoveredBlock.id }) { self.hoveredBlock = nil }
        installButtonsIfNeeded()
        updateControlFrames()
        needsDisplay = true
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let offset = characterIndexForInsertion(at: point)
        let node = blockNodes.first { node in
            guard let range = node.sourceRange else { return false }
            return NSLocationInRange(offset, range)
        }
        if node?.id != hoveredBlock?.id {
            hoveredBlock = node
            updateControlFrames()
            setControlsVisible(node != nil, animated: true)
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if moveButton.frame.contains(point) || deleteButton.frame.contains(point) { return }
        hoveredBlock = nil
        setControlsVisible(false, animated: true)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        MarkdownTextDecorationPipeline.draw(in: self, nodes: blockNodes)
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if modifiers.isEmpty, event.keyCode == 36, returnHandler?(selectedRange()) == true { return }
        if modifiers.isEmpty, event.keyCode == 51 {
            let selection = selectedRange()
            if selection.length == 0, backspaceHandler?(selection.location) == true { return }
        }
        super.keyDown(with: event)
    }

    private func installButtonsIfNeeded() {
        guard moveButton.superview == nil else { return }
        moveButton.isHidden = true
        deleteButton.isHidden = true
        // The handle is a drag affordance, so clicking it alone must not move a block.
        moveButton.target = nil
        moveButton.action = nil
        deleteButton.target = self
        deleteButton.action = #selector(deleteHoveredBlock)
        moveButton.onHoverChanged = { [weak self] hovering in self?.controlHoverChanged(hovering) }
        deleteButton.onHoverChanged = { [weak self] hovering in self?.controlHoverChanged(hovering) }
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handleMoveGesture(_:)))
        moveButton.addGestureRecognizer(pan)
        addSubview(moveButton)
        addSubview(deleteButton)
    }

    private func controlHoverChanged(_ hovering: Bool) {
        if hovering {
            setControlsVisible(true, animated: true)
            return
        }
        let point = convert(NSEvent.mouseLocation, from: nil)
        guard !bounds.contains(point) else { return }
        hoveredBlock = nil
        setControlsVisible(false, animated: true)
    }

    private func setControlsVisible(_ visible: Bool, animated: Bool) {
        let buttons = [moveButton, deleteButton]
        if visible { buttons.forEach { $0.isHidden = false } }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? 0.14 : 0
            buttons.forEach { $0.animator().alphaValue = visible ? 0.4 : 0 }
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !visible else { return }
                self.moveButton.isHidden = true
                self.deleteButton.isHidden = true
            }
        }
    }

    private func updateControlFrames() {
        guard let hoveredBlock, let range = hoveredBlock.sourceRange else { return }
        let frames = textFrames(for: range)
        guard let first = frames.first, let last = frames.last else { return }
        let leftX = max(0, textContainerOrigin.x - 28)
        let rightX = min(max(0, bounds.width - 26), last.maxX + 2)
        moveButton.frame = NSRect(x: leftX, y: first.minY - 2, width: 24, height: 26)
        deleteButton.frame = NSRect(x: rightX, y: last.minY - 2, width: 24, height: 26)
    }

    /// Uses TextKit 2's source-range geometry to place controls beside this block's first and last lines.
    func textFrames(for range: NSRange) -> [CGRect] {
        guard let content = textContentStorage, let layout = textLayoutManager else { return [] }
        let documentStart = content.documentRange.location
        guard let start = content.location(documentStart, offsetBy: range.location),
              let end = content.location(documentStart, offsetBy: NSMaxRange(range)),
              let textRange = NSTextRange(location: start, end: end) else { return [] }
        layout.ensureLayout(for: textRange)
        var result: [CGRect] = []
        layout.enumerateTextSegments(in: textRange, type: .standard, options: []) { _, frame, _, _ in
            result.append(frame.offsetBy(dx: self.textContainerOrigin.x, dy: self.textContainerOrigin.y))
            return true
        }
        return result
    }

    @objc private func deleteHoveredBlock() {
        guard let offset = hoveredBlock?.sourceRange?.location else { return }
        onDeleteBlock?(offset)
    }

    @objc private func handleMoveGesture(_ gesture: NSPanGestureRecognizer) {
        let point = gesture.location(in: self)
        switch gesture.state {
        case .began:
            dragSourceOffset = hoveredBlock?.sourceRange?.location
        case .ended:
            defer { dragSourceOffset = nil }
            guard let sourceOffset = dragSourceOffset else { return }
            let targetOffset = characterIndexForInsertion(at: point)
            onMoveBlock?(sourceOffset, targetOffset)
        case .cancelled, .failed:
            dragSourceOffset = nil
        default:
            break
        }
    }
}

/// Small transparent control used in the text view's reserved left and right gutters.
private final class BlockActionButton: NSButton {
    var onHoverChanged: ((Bool) -> Void)?

    init(symbolName: String, label: String) {
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
        imagePosition = .imageOnly
        contentTintColor = .secondaryLabelColor
        isBordered = false
        alphaValue = 0.4
        toolTip = label
        setAccessibilityLabel(label)
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override func updateTrackingAreas() {
        for area in trackingAreas { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        alphaValue = 0.85
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        alphaValue = 0.4
        onHoverChanged?(false)
    }
}
