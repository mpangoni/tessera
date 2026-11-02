import SwiftUI
import TesseraCore

struct EditorView: View {
    @Binding var document: TesseraDocument
    @Environment(\.undoManager) private var undoManager
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

    private var controlsBlockID: UUID? { focusedControlsBlockID ?? hoveredBlockID }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                Toggle("Raw Markdown", isOn: Binding(
                    get: { editorMode == .rawMarkdown },
                    set: { editorMode = $0 ? .rawMarkdown : .blocks }
                ))
                .toggleStyle(.switch)
                .fixedSize()
                .accessibilityHint("Switch between block and raw Markdown editing")
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

    private var rawMarkdownEditor: some View {
        TextEditor(text: $document.markdown)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(28)
            .frame(maxWidth: 780, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() {
        let model = MarkdownCodec.decode(document.markdown)
        blocks = model.blocks.isEmpty ? [TesseraBlock(kind: .paragraph, content: "")] : model.blocks
        originalSource = model.originalSource
        lineEnding = model.lineEnding
        trailingSource = model.trailingSource
        hasBeenEdited = false
        lastPublished = document.markdown
    }

    private func publish() {
        var model = currentDocument()
        model.hasBeenEdited = true
        document.markdown = MarkdownCodec.encode(model)
        lastPublished = document.markdown
        originalSource = nil
        hasBeenEdited = true
    }

    private func currentDocument() -> BlockDocument {
        BlockDocument(blocks: blocks, originalSource: originalSource, lineEnding: lineEnding, trailingSource: trailingSource, hasBeenEdited: hasBeenEdited)
    }

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

    private func move(_ id: UUID, by distance: Int) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        move(id, to: index + distance)
    }

    private func moveAcrossBoundary(from id: UUID, up: Bool) -> Bool {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return false }
        let adjacentIndex = up ? index - 1 : index + 1
        guard blocks.indices.contains(adjacentIndex) else { return false }
        let adjacentBlock = blocks[adjacentIndex]
        focusOffset = up ? (adjacentBlock.content as NSString).length : 0
        focusedBlock = adjacentBlock.id
        return true
    }

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

private enum EditorMode: Hashable {
    case blocks
    case rawMarkdown
}

private struct EditorSnapshot {
    var document: BlockDocument
    var focusedBlock: UUID?
    var caretOffset: Int
}

@MainActor
private final class BlockUndoCoordinator: ObservableObject {
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
