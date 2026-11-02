import SwiftUI

@main
struct TesseraApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: TesseraDocument()) { configuration in
            EditorView(document: configuration.$document)
                .frame(minWidth: 640, minHeight: 480)
        }
    }
}
