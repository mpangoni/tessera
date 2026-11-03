import SwiftUI

/// Composes document navigation and the selected content editor for one Markdown file.
struct MainContentView: View {
    @Binding var document: MarkdownDocument
    @State private var editorMode: EditorMode = .blocks

    init(document: Binding<MarkdownDocument>) {
        _document = document
    }

    /// Routes the navigation bar's choice through the main editor's mode-change command.
    private var contentEditorSelection: Binding<EditorMode> {
        Binding(get: { editorMode }, set: { mode in changeContentEditor(to: mode) })
    }

    var body: some View {
        VStack(spacing: 0) {
            MainUpperBar(selection: contentEditorSelection)

            Group {
                switch editorMode {
                case .blocks:
                    blockEditor
                case .rawMarkdown:
                    RawMarkdownEditorView(markdown: documentMarkdownBinding)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MainBottomBar()
        }
    }

    /// Binds raw Markdown edits to the main editor's document publish command.
    private var documentMarkdownBinding: Binding<String> {
        Binding(
            get: { document.markdown },
            set: { Self.publishDocument($0, to: $document) }
        )
    }

    /// Changes which content editor is shown beneath the shared navigation bars.
    private func changeContentEditor(to mode: EditorMode) {
        editorMode = mode
    }

    /// Publishes Markdown as the file document's only stored content.
    private static func publishDocument(_ markdown: String, to document: Binding<MarkdownDocument>) {
        document.wrappedValue.markdown = markdown
    }

    /// Supplies the saved Markdown source to the document-wide TextKit editor.
    private var blockEditor: some View {
        BlockDocumentEditorView(markdown: documentMarkdownBinding)
    }
}
