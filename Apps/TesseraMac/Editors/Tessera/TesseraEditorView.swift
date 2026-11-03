import SwiftUI

/// Hosts one TextKit 2 text view for the Tessera AST projection.
struct TesseraEditorView: EditorImplementation {
    @Binding var markdown: String

    static let mode: EditorMode = .tessera
    static let symbolName = "square.stack.3d.up"
    static let displayName = "Tessera"

    var body: some View {
        TextKitTesseraEditor(markdown: $markdown)
            .frame(maxWidth: 720)
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
