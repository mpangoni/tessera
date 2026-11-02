import SwiftUI
import TesseraCore

/// Owns one document's block model and connects edits to the Markdown string macOS saves.
struct EditorView: View {
    @Binding var document: TesseraDocument
    @Environment(\.undoManager) private var undoManager

    // View state and preservation details used while moving between raw text and block editing.
    @State private var editorMode: EditorMode = .blocks
    @State private var blocks: [TesseraBlock] = []
    @State private var originalSource: String?
    @State private var lineEnding = "\n"
    @State private var trailingSource = ""
    @State private var hasBeenEdited = false
    @State private var dropTarget: UUID?
    @State private var lastPublished = ""
    @State private var focusedBlock: UUID?
    @State private var focusOffset = 0
    @State private var hoveredBlockID: UUID?
    @State private var focusedControlsBlockID: UUID?
    @StateObject private var undoCoordinator = BlockUndoCoordinator()

    /// Keyboard-focused controls take priority; otherwise only the row currently under the pointer is shown.
    private var controlsBlockID: UUID? { focusedControlsBlockID ?? hoveredBlockID }

    var body: some View {
        VStack(spacing: 0) {
            // The icon-only segmented control changes how the same Markdown document is displayed.
            HStack {
                Spacer(minLength: 0)
                Picker("Document view", selection: $editorMode) {
                    Image(systemName: "square.stack.3d.up")
                        .help("Block view")
                        .accessibilityLabel("Blocks")
                        .tag(EditorMode.blocks)
                    Image(systemName: "curlybraces")
                        .help("Raw Markdown")
                        .accessibilityLabel("Raw Markdown")
                        .tag(EditorMode.rawMarkdown)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .clipShape(Capsule())
                .accessibilityLabel("Document view")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.bar)

            Group {
                switch editorMode {
                case .blocks:
                    blockEditor
                case .rawMarkdown:
                    rawMarkdownEditor
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Keep a small empty bottom bar reserved for future document actions.
            HStack { Spacer(minLength: 0) }
                .frame(height: 28)
                .background(.bar)
        }
        .onAppear {
            load()
            configureUndoRestoration()
            undoCoordinator.manager = undoManager
        }
        .onChange(of: undoManager) { _, manager in undoCoordinator.manager = manager }
        .onChange(of: document.markdown) { _, value in
            if value != lastPublished { load() }
        }
    }

    /// Builds the movable block rows and connects their actions to document-level edit commands.
    private var blockEditor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { block in
                    BlockRow(
                        block: block,
                        text: contentBinding(for: block),
                        isFocused: focusedBlock == block.id,
                        areControlsVisible: controlsBlockID == block.id,
                        caretOffset: focusOffset,
                        isDropTarget: dropTarget == block.id,
                        onFocus: { focusedBlock = block.id },
                        onReturn: { range in split(block, selection: range) },
                        onBackspace: { mergePrevious(block) },
                        onVerticalBoundary: { moveAcrossBoundary(from: block.id, up: $0) },
                        onHoverBlock: { isHovering in
                            if isHovering {
                                hoveredBlockID = block.id
                            } else if hoveredBlockID == block.id {
                                hoveredBlockID = nil
                            }
                        },
                        onDeleteFocusChange: { isFocused in
                            if isFocused {
                                focusedControlsBlockID = block.id
                            } else if focusedControlsBlockID == block.id {
                                focusedControlsBlockID = nil
                            }
                        },
                        onDelete: { remove(block.id) },
                        onMove: { move(block.id, by: $0) },
                        onDrop: { id in move(id, to: blocks.firstIndex(where: { $0.id == block.id }) ?? blocks.count) },
                        onHoverDrop: { dropTarget = $0 ? block.id : (dropTarget == block.id ? nil : dropTarget) }
                    )
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
    }

    /// Shows the actual Markdown string so the user can edit syntax directly.
    private var rawMarkdownEditor: some View {
        TextEditor(text: $document.markdown)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(28)
            .frame(maxWidth: 780, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Parses the current Markdown and resets the in-memory edit state from that source.
    /// Empty files get one temporary paragraph so there is always somewhere to type.
    private func load() {
        let model = MarkdownCodec.decode(document.markdown)
        blocks = model.blocks.isEmpty ? [TesseraBlock(kind: .paragraph, content: "")] : model.blocks
        originalSource = model.originalSource
        lineEnding = model.lineEnding
        trailingSource = model.trailingSource
        hasBeenEdited = false
        lastPublished = document.markdown
    }

    /// Serializes the edited blocks and publishes the result to the document macOS saves.
    private func publish() {
        var model = currentDocument()
        model.hasBeenEdited = true
        document.markdown = MarkdownCodec.encode(model)
        lastPublished = document.markdown
        originalSource = nil
        hasBeenEdited = true
    }

    /// Packages the visible blocks with source-preservation details for the Markdown codec.
    private func currentDocument() -> BlockDocument {
        BlockDocument(blocks: blocks, originalSource: originalSource, lineEnding: lineEnding, trailingSource: trailingSource, hasBeenEdited: hasBeenEdited)
    }

    /// Gives a text view a live binding for one block, routing changes through the core edit command.
    private func contentBinding(for block: TesseraBlock) -> Binding<String> {
        Binding(
            get: { blocks.first(where: { $0.id == block.id })?.content ?? "" },
            set: { value in
                var model = currentDocument()
                do {
                    try BlockEditorCommands.update(id: block.id, content: value, in: &model)
                    blocks = model.blocks
                    hasBeenEdited = model.hasBeenEdited
                    publish()
                } catch { assertionFailure("Could not update block: \(error)") }
            }
        )
    }

    /// Splits a block at the current selection, then focuses the new block and records an undo step.
    /// NSTextView selections use UTF-16 ranges, so this converts the range before calling TesseraCore.
    private func split(_ block: TesseraBlock, selection: NSRange) -> Bool {
        var before = snapshot()
        before.focusedBlock = block.id
        before.caretOffset = selection.location
        var model = before.document
        guard let swiftRange = Range(selection, in: block.content) else { return false }
        let lower = block.content.distance(from: block.content.startIndex, to: swiftRange.lowerBound)
        let upper = block.content.distance(from: block.content.startIndex, to: swiftRange.upperBound)
        do {
            let newID = try BlockEditorCommands.split(id: block.id, replacing: lower..<upper, in: &model)
            blocks = model.blocks
            focusedBlock = newID
            focusOffset = 0
            hasBeenEdited = model.hasBeenEdited
            publish()
            undoCoordinator.register(from: before, to: snapshot(), actionName: "Split Block")
            return true
        } catch { return false }
    }

    /// Joins this block to the preceding one when Backspace is pressed at its start.
    private func mergePrevious(_ block: TesseraBlock) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }), index > 0 else { return false }
        let previous = blocks[index - 1]
        var before = snapshot()
        before.focusedBlock = block.id
        before.caretOffset = 0
        var model = before.document
        do {
            let joinOffset = try BlockEditorCommands.mergePrevious(id: block.id, in: &model)
            blocks = model.blocks
            focusedBlock = previous.id
            focusOffset = joinOffset
            hasBeenEdited = model.hasBeenEdited
            publish()
            undoCoordinator.register(from: before, to: snapshot(), actionName: "Merge Blocks")
            return true
        } catch { return false }
    }

    /// Deletes a block, or clears and resets it when it is the document's last remaining block.
    private func remove(_ id: UUID) {
        let before = snapshot()
        var model = before.document
        do {
            if model.blocks.count == 1 {
                try BlockEditorCommands.update(id: id, content: "", in: &model)
                try BlockEditorCommands.updateKind(id: id, kind: .paragraph, in: &model)
                focusedBlock = id
                focusOffset = 0
            } else {
                _ = try BlockEditorCommands.delete(id: id, in: &model)
                let next = model.blocks[min(blocks.firstIndex(where: { $0.id == id }) ?? 0, model.blocks.count - 1)]
                focusedBlock = next.id
                focusOffset = 0
            }
            apply(model)
            publish()
            undoCoordinator.register(from: before, to: snapshot(), actionName: "Delete Block")
        } catch { assertionFailure("Could not remove block: \(error)") }
    }

    /// Moves a block by a relative amount, as used by the accessibility Move Up/Down actions.
    private func move(_ id: UUID, by distance: Int) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        move(id, to: index + distance)
    }

    /// Moves focus across a block boundary and places the caret at the matching edge of that block.
    private func moveAcrossBoundary(from id: UUID, up: Bool) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return false }
        let adjacentIndex = up ? index - 1 : index + 1
        guard blocks.indices.contains(adjacentIndex) else { return false }
        let adjacentBlock = blocks[adjacentIndex]
        focusOffset = up ? (adjacentBlock.content as NSString).length : 0
        focusedBlock = adjacentBlock.id
        return true
    }

    /// Reorders a block to a specific destination and registers the change with UndoManager.
    private func move(_ id: UUID, to destination: Int) {
        guard let index = blocks.firstIndex(where: { $0.id == id }), (0..<blocks.count).contains(destination), index != destination else { return }
        let before = snapshot()
        var model = before.document
        do {
            try BlockEditorCommands.move(id: id, to: destination, in: &model)
            apply(model)
            focusedBlock = id
            publish()
            undoCoordinator.register(from: before, to: snapshot(), actionName: "Move Block")
        } catch { assertionFailure("Could not move block: \(error)") }
    }

    /// Replaces all in-memory document fields after a core command or undo operation.
    private func apply(_ model: BlockDocument) {
        blocks = model.blocks.isEmpty ? [TesseraBlock(kind: .paragraph, content: "")] : model.blocks
        originalSource = model.originalSource
        lineEnding = model.lineEnding
        trailingSource = model.trailingSource
        hasBeenEdited = model.hasBeenEdited
    }

    /// Captures both document contents and the current text cursor so undo restores the editing position.
    private func snapshot() -> EditorSnapshot {
        EditorSnapshot(document: currentDocument(), focusedBlock: focusedBlock, caretOffset: focusOffset)
    }

    /// Connects UndoManager callbacks to SwiftUI state and the saved Markdown string.
    private func configureUndoRestoration() {
        let blocks = $blocks
        let originalSource = $originalSource
        let lineEnding = $lineEnding
        let trailingSource = $trailingSource
        let hasBeenEdited = $hasBeenEdited
        let focusedBlock = $focusedBlock
        let focusOffset = $focusOffset
        let document = $document
        let lastPublished = $lastPublished
        undoCoordinator.restore = { snapshot in
            blocks.wrappedValue = snapshot.document.blocks.isEmpty ? [TesseraBlock(kind: .paragraph, content: "")] : snapshot.document.blocks
            originalSource.wrappedValue = snapshot.document.originalSource
            lineEnding.wrappedValue = snapshot.document.lineEnding
            trailingSource.wrappedValue = snapshot.document.trailingSource
            hasBeenEdited.wrappedValue = snapshot.document.hasBeenEdited
            focusedBlock.wrappedValue = snapshot.focusedBlock
            focusOffset.wrappedValue = snapshot.caretOffset
            let markdown = MarkdownCodec.encode(snapshot.document)
            document.wrappedValue.markdown = markdown
            lastPublished.wrappedValue = markdown
        }
    }
}

/// The two ways Tessera can show and edit the same Markdown source.
private enum EditorMode: Hashable {
    case blocks
    case rawMarkdown
}

/// A restorable point in editing, including which block had focus and the caret offset.
private struct EditorSnapshot {
    var document: BlockDocument
    var focusedBlock: UUID?
    var caretOffset: Int
}

@MainActor
/// Registers block-level changes with the document window's native undo manager.
private final class BlockUndoCoordinator: ObservableObject {
    weak var manager: UndoManager?
    var restore: ((EditorSnapshot) -> Void)?

    /// Registers a reversible pair of snapshots under a readable Undo menu name.
    func register(from: EditorSnapshot, to: EditorSnapshot, actionName: String) {
        guard let manager else { return }
        manager.registerUndo(withTarget: self) { target in
            target.restore?(from)
            target.register(from: to, to: from, actionName: actionName)
        }
        manager.setActionName(actionName)
    }
}

/// One block's text editor and unobtrusive drag/delete controls.
private struct BlockRow: View {
    let block: TesseraBlock
    @Binding var text: String
    let isFocused: Bool
    let areControlsVisible: Bool
    let caretOffset: Int
    let isDropTarget: Bool
    let onFocus: () -> Void
    let onReturn: (NSRange) -> Bool
    let onBackspace: () -> Bool
    let onVerticalBoundary: (Bool) -> Bool
    let onHoverBlock: (Bool) -> Void
    let onDeleteFocusChange: (Bool) -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void
    let onDrop: (UUID) -> Void
    let onHoverDrop: (Bool) -> Void
    @State private var dragHandleHovered = false
    @State private var deleteHovered = false
    @FocusState private var deleteFocused: Bool

    /// Controls appear for the single active row, coordinated by `EditorView`.
    private var controlsVisible: Bool { areControlsVisible }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .opacity(controlsVisible ? (dragHandleHovered ? 0.85 : 0.4) : 0)
                .frame(width: 20, height: 28)
                .contentShape(Rectangle())
                .onHover { dragHandleHovered = $0 }
                .draggable(block.id.uuidString)
                .help("Drag to reorder block")
                .accessibilityLabel("Drag to reorder block")

            BlockTextEditor(text: $text, kind: block.kind, shouldFocus: isFocused, caretOffset: caretOffset, onFocus: onFocus, onReturn: onReturn, onBackspace: onBackspace, onVerticalBoundary: onVerticalBoundary)
                .frame(maxWidth: .infinity, minHeight: 30)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.tertiary)
                    .opacity(deleteHovered || deleteFocused ? 0.85 : 0.4)
                    .frame(width: 24, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focused($deleteFocused)
            .opacity(controlsVisible ? 1 : 0)
            .onHover { deleteHovered = $0 }
            .help("Delete block")
            .accessibilityLabel("Delete block")
        }
        .padding(.vertical, 4)
        .background(isDropTarget ? Color.accentColor.opacity(0.12) : .clear)
        .contentShape(Rectangle())
        .overlay { BlockHoverTracker(onHover: onHoverBlock).allowsHitTesting(false) }
        .animation(.easeInOut(duration: 0.14), value: controlsVisible)
        .onChange(of: deleteFocused) { _, isFocused in onDeleteFocusChange(isFocused) }
        .accessibilityAction(named: Text("Move block up")) { onMove(-1) }
        .accessibilityAction(named: Text("Move block down")) { onMove(1) }
        .dropDestination(for: String.self) { values, _ in
            guard let id = values.first.flatMap(UUID.init(uuidString:)), id != block.id else { return false }
            onDrop(id)
            return true
        } isTargeted: { onHoverDrop($0) }
    }
}
