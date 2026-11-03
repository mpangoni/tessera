import SwiftUI

/// Edits the document's Markdown source directly in a native text editor.
struct MarkdownEditorView: EditorImplementation {
    @Binding var markdown: String

    static let mode: EditorMode = .markdown
    static let symbolName = "curlybraces"
    static let displayName = "Markdown"

    var body: some View {
        TextEditor(text: $markdown)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(28)
            .frame(maxWidth: 780, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
