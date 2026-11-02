import SwiftUI

/// Composes document navigation and the selected content editor for one Markdown file.
struct MainEditorView: View {
    @Binding var document: MarkdownDocument
    @Environment(\.undoManager) private var undoManager
    @State private var editorMode: EditorMode = .blocks
    @StateObject private var blockSession: BlockDocumentEditorSession

    init(document: Binding<MarkdownDocument>) {
        _document = document
        _blockSession = StateObject(
            wrappedValue: BlockDocumentEditorSession(markdown: document.wrappedValue.markdown)
        )
    }

    /// Keyboard-focused controls take priority; otherwise the hovered block owns the controls.
    private var controlsBlockID: UUID? {
        blockSession.focusedControlsBlockID ?? blockSession.hoveredBlockID
    }

    /// Routes the navigation bar's choice through the main editor's mode-change command.
    private var contentEditorSelection: Binding<EditorMode> {
        Binding(get: { editorMode }, set: { mode in changeContentEditor(to: mode) })
    }

    var body: some View {
        VStack(spacing: 0) {
            EditorTopBar(selection: contentEditorSelection)

            Group {
                switch editorMode {
                case .blocks:
                    blockEditor
                case .rawMarkdown:
                    RawMarkdownEditorView(markdown: documentMarkdownBinding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            EditorBottomBar()
        }
        .onAppear {
            let documentBinding = $document
            blockSession.onMarkdownChange = { markdown in Self.publishDocument(markdown, to: documentBinding) }
            blockSession.setUndoManager(undoManager)
            loadDocument(document.markdown)
        }
        .onChange(of: undoManager) { _, manager in blockSession.setUndoManager(manager) }
        .onChange(of: document.markdown) { _, markdown in
            loadDocument(markdown)
        }
    }

    /// Binds raw Markdown edits to the main editor's document publish command.
    private var documentMarkdownBinding: Binding<String> {
        Binding(
            get: { document.markdown },
            set: { Self.publishDocument($0, to: $document) }
        )
    }

    /// Loads changed file contents into the block editing session.
    private func loadDocument(_ markdown: String) {
        blockSession.loadIfChanged(markdown: markdown)
    }

    /// Changes which content editor is shown beneath the shared navigation bars.
    private func changeContentEditor(to mode: EditorMode) {
        editorMode = mode
    }

    /// Publishes Markdown as the file document's only stored content.
    private static func publishDocument(_ markdown: String, to document: Binding<MarkdownDocument>) {
        document.wrappedValue.markdown = markdown
    }

    /// Supplies block editor state and forwards its gestures to the block editing session.
    private var blockEditor: some View {
        BlockDocumentEditorView(
            blocks: blockSession.blocks,
            focusedBlock: blockSession.focusedBlock,
            controlsBlockID: controlsBlockID,
            focusOffset: blockSession.focusOffset,
            dropTarget: blockSession.dropTarget,
            text: blockSession.contentBinding(for:),
            onFocus: { blockSession.focusedBlock = $0 },
            onReturn: { block, selection in blockSession.split(block, selection: selection) },
            onBackspace: { blockSession.mergePrevious($0) },
            onVerticalBoundary: { id, up in blockSession.moveAcrossBoundary(from: id, up: up) },
            onHoverBlock: { id, hovering in
                if hovering {
                    blockSession.hoveredBlockID = id
                } else if blockSession.hoveredBlockID == id {
                    blockSession.hoveredBlockID = nil
                }
            },
            onDeleteFocusChange: { id, isFocused in
                if isFocused {
                    blockSession.focusedControlsBlockID = id
                } else if blockSession.focusedControlsBlockID == id {
                    blockSession.focusedControlsBlockID = nil
                }
            },
            onDelete: blockSession.remove,
            onMove: { id, distance in blockSession.move(id, by: distance) },
            onDrop: { id, targetID in blockSession.move(id, before: targetID) },
            onHoverDrop: { id, hovering in
                blockSession.dropTarget = hovering ? id : (blockSession.dropTarget == id ? nil : blockSession.dropTarget)
            }
        )
    }
}
