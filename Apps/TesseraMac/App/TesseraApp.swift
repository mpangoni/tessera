import SwiftUI

/// Starts the native document-based app, letting macOS manage New, Open, Save, and window lifecycle.
@main
struct TesseraApp: App {
    var body: some Scene {

        // Each document window gets its own editor view and bound Markdown document.
        DocumentGroup(newDocument: MarkdownDocument()) { configuration in
            MainEditorView(document: configuration.$document)
                .frame(minWidth: 640, minHeight: 480)
        }
    }
}
