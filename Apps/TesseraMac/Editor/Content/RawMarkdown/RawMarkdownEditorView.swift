import SwiftUI

/// Edits the document's Markdown source directly in a native text editor.
struct RawMarkdownEditorView: EditorImplementation {
    @Binding var markdown: String

    static let mode: EditorMode = .rawMarkdown
    static let symbolName = "curlybraces"
    static let displayName = "Raw Markdown"

    var body: some View {
        TextEditor(text: $markdown)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(28)
            .frame(maxWidth: 780, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
