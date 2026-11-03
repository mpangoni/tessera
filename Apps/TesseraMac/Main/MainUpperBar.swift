import SwiftUI

/// Provides the global switch between Tessera's document editing experiences.
struct MainUpperBar: View {
    @Binding var selection: EditorMode

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Picker("Document view", selection: $selection) {
                editorOption(TesseraEditorView.self)
                editorOption(MarkdownEditorView.self)
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
    }

    /// Builds the icon and accessibility label from an editor's shared metadata.
    private func editorOption<Implementation: EditorImplementation>(
        _ implementation: Implementation.Type
    ) -> some View {
        Image(systemName: Implementation.symbolName)
            .help(Implementation.displayName)
            .accessibilityLabel(Implementation.displayName)
            .tag(Implementation.mode)
    }
}
