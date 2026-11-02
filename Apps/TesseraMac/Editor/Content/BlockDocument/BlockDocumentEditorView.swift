import SwiftUI
import TesseraCore

/// Renders the document as independently editable and reorderable block rows.
struct BlockDocumentEditorView: EditorImplementation {
    let blocks: [TesseraBlock]
    let focusedBlock: UUID?
    let controlsBlockID: UUID?
    let focusOffset: Int
    let dropTarget: UUID?
    let text: (TesseraBlock) -> Binding<String>
    let onFocus: (UUID) -> Void
    let onReturn: (TesseraBlock, NSRange) -> Bool
    let onBackspace: (TesseraBlock) -> Bool
    let onVerticalBoundary: (UUID, Bool) -> Bool
    let onHoverBlock: (UUID, Bool) -> Void
    let onDeleteFocusChange: (UUID, Bool) -> Void
    let onDelete: (UUID) -> Void
    let onMove: (UUID, Int) -> Void
    let onDrop: (UUID, UUID) -> Void
    let onHoverDrop: (UUID, Bool) -> Void

    static let mode: EditorMode = .blocks
    static let symbolName = "square.stack.3d.up"
    static let displayName = "Blocks"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { block in
                    BlockRow(
                        block: block,
                        text: text(block),
                        isFocused: focusedBlock == block.id,
                        areControlsVisible: controlsBlockID == block.id,
                        caretOffset: focusOffset,
                        isDropTarget: dropTarget == block.id,
                        onFocus: { onFocus(block.id) },
                        onReturn: { onReturn(block, $0) },
                        onBackspace: { onBackspace(block) },
                        onVerticalBoundary: { onVerticalBoundary(block.id, $0) },
                        onHoverBlock: { onHoverBlock(block.id, $0) },
                        onDeleteFocusChange: { onDeleteFocusChange(block.id, $0) },
                        onDelete: { onDelete(block.id) },
                        onMove: { onMove(block.id, $0) },
                        onDrop: { onDrop($0, block.id) },
                        onHoverDrop: { onHoverDrop(block.id, $0) }
                    )
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
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

    /// Controls appear for the single active row, coordinated by `MainEditorView`.
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
