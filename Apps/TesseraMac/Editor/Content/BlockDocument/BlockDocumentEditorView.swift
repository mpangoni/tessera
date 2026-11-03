import SwiftUI

/// Hosts one document-wide TextKit 2 text view for the block editing mode.
struct BlockDocumentEditorView: EditorImplementation {
    @Binding var markdown: String

    static let mode: EditorMode = .blocks
    static let symbolName = "square.stack.3d.up"
    static let displayName = "Blocks"

    var body: some View {
        TextKit2MarkdownEditor(markdown: $markdown)
            .frame(maxWidth: 720)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
