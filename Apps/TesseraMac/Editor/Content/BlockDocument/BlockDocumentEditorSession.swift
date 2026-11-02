import SwiftUI
import TesseraCore

/// Owns block editor state and translates user actions into platform-independent block commands.
@MainActor
final class BlockDocumentEditorSession: ObservableObject {
    @Published private(set) var blocks: [TesseraBlock] = []
    @Published var dropTarget: UUID?
    @Published var focusedBlock: UUID?
    @Published var focusOffset = 0
    @Published var hoveredBlockID: UUID?
    @Published var focusedControlsBlockID: UUID?

    private var originalSource: String?
    private var lineEnding = "\n"
    private var trailingSource = ""
    private var hasBeenEdited = false
    private var lastPublished = ""
    private let undoCoordinator = BlockUndoCoordinator()

    /// Sends serialized edits back to the main editor, which publishes them to the file document.
    var onMarkdownChange: ((String) -> Void)?

    init(markdown: String = "") {
        load(markdown: markdown)
    }

    /// Connects block operations to the native window's Undo menu.
    func setUndoManager(_ manager: UndoManager?) {
        undoCoordinator.manager = manager
        undoCoordinator.restore = { [weak self] snapshot in
            guard let self else { return }
            self.apply(snapshot.document)
            self.focusedBlock = snapshot.focusedBlock
            self.focusOffset = snapshot.caretOffset
            let markdown = MarkdownCodec.encode(snapshot.document)
            self.lastPublished = markdown
            self.onMarkdownChange?(markdown)
        }
    }

    /// Loads an external document change while ignoring Markdown just published by this session.
    func loadIfChanged(markdown: String) {
        guard markdown != lastPublished else { return }
        load(markdown: markdown)
    }

    /// Parses Markdown and restores one editable placeholder block for an empty document.
    private func load(markdown: String) {
        let model = MarkdownCodec.decode(markdown)
        apply(model)
        hasBeenEdited = false
        lastPublished = markdown
    }

    /// Gives one row a binding that routes edits through `BlockEditorCommands.update`.
    func contentBinding(for block: TesseraBlock) -> Binding<String> {
        Binding(
            get: { [weak self] in self?.blocks.first(where: { $0.id == block.id })?.content ?? "" },
            set: { [weak self] value in self?.updateContent(value, for: block.id) }
        )
    }

    /// Splits at the text editor's selection and restores focus at the beginning of the new block.
    func split(_ block: TesseraBlock, selection: NSRange) -> Bool {
        var before = snapshot()
        before.focusedBlock = block.id
        before.caretOffset = selection.location
        var model = before.document
        guard let swiftRange = Range(selection, in: block.content) else { return false }
        let lower = block.content.distance(from: block.content.startIndex, to: swiftRange.lowerBound)
        let upper = block.content.distance(from: block.content.startIndex, to: swiftRange.upperBound)
        do {
            let newID = try BlockEditorCommands.split(id: block.id, replacing: lower..<upper, in: &model)
            apply(model)
            focusedBlock = newID
            focusOffset = 0
            publish()
            undoCoordinator.register(from: before, to: snapshot(), actionName: "Split Block")
            return true
        } catch { return false }
    }

    /// Merges into the preceding block when Backspace is pressed at the start of this block.
    func mergePrevious(_ block: TesseraBlock) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == block.id }), index > 0 else { return false }
        let previous = blocks[index - 1]
        var before = snapshot()
        before.focusedBlock = block.id
        before.caretOffset = 0
        var model = before.document
        do {
            let joinOffset = try BlockEditorCommands.mergePrevious(id: block.id, in: &model)
            apply(model)
            focusedBlock = previous.id
            focusOffset = joinOffset
            publish()
            undoCoordinator.register(from: before, to: snapshot(), actionName: "Merge Blocks")
            return true
        } catch { return false }
    }

    /// Deletes a row or clears it when it is the document's last editable block.
    func remove(_ id: UUID) {
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

    /// Moves a row by a relative amount for the accessible Move Up and Move Down actions.
    func move(_ id: UUID, by distance: Int) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        move(id, to: index + distance)
    }

    /// Moves keyboard focus to the previous or next block edge.
    func moveAcrossBoundary(from id: UUID, up: Bool) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return false }
        let adjacentIndex = up ? index - 1 : index + 1
        guard blocks.indices.contains(adjacentIndex) else { return false }
        let adjacentBlock = blocks[adjacentIndex]
        focusOffset = up ? (adjacentBlock.content as NSString).length : 0
        focusedBlock = adjacentBlock.id
        return true
    }

    /// Drops one block on another while preserving the document's block order.
    func move(_ id: UUID, before targetID: UUID) {
        move(id, to: blocks.firstIndex(where: { $0.id == targetID }) ?? blocks.count)
    }

    /// Builds a `BlockDocument` from the current state for serialization or undo capture.
    private func currentDocument() -> BlockDocument {
        BlockDocument(blocks: blocks, originalSource: originalSource, lineEnding: lineEnding, trailingSource: trailingSource, hasBeenEdited: hasBeenEdited)
    }

    private func updateContent(_ content: String, for id: UUID) {
        var model = currentDocument()
        do {
            try BlockEditorCommands.update(id: id, content: content, in: &model)
            apply(model)
            publish()
        } catch { assertionFailure("Could not update block: \(error)") }
    }

    private func move(_ id: UUID, to destination: Int) {
        guard let index = blocks.firstIndex(where: { $0.id == id }),
              (0..<blocks.count).contains(destination), index != destination else { return }
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

    private func publish() {
        var model = currentDocument()
        model.hasBeenEdited = true
        let markdown = MarkdownCodec.encode(model)
        lastPublished = markdown
        originalSource = nil
        hasBeenEdited = true
        onMarkdownChange?(markdown)
    }

    private func apply(_ model: BlockDocument) {
        blocks = model.blocks.isEmpty ? [TesseraBlock(kind: .paragraph, content: "")] : model.blocks
        originalSource = model.originalSource
        lineEnding = model.lineEnding
        trailingSource = model.trailingSource
        hasBeenEdited = model.hasBeenEdited
    }

    private func snapshot() -> EditorSnapshot {
        EditorSnapshot(document: currentDocument(), focusedBlock: focusedBlock, caretOffset: focusOffset)
    }
}

/// Stores the document and caret position so undo restores both text and editing focus.
private struct EditorSnapshot {
    var document: BlockDocument
    var focusedBlock: UUID?
    var caretOffset: Int
}

@MainActor
/// Registers block-level changes with macOS's native UndoManager.
private final class BlockUndoCoordinator {
    weak var manager: UndoManager?
    var restore: ((EditorSnapshot) -> Void)?

    func register(from: EditorSnapshot, to: EditorSnapshot, actionName: String) {
        guard let manager else { return }
        manager.registerUndo(withTarget: self) { target in
            target.restore?(from)
            target.register(from: to, to: from, actionName: actionName)
        }
        manager.setActionName(actionName)
    }
}
