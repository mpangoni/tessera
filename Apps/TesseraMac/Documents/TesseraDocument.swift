import SwiftUI
import UniformTypeIdentifiers

struct TesseraDocument: FileDocument {
    // Markdown UTType is not exposed by the installed macOS 26 SDK.
    static var readableContentTypes: [UTType] { [UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText), .plainText] }
    var markdown: String

    init(markdown: String = "") { self.markdown = markdown }
    init(configuration: ReadConfiguration) throws {
        guard let text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        markdown = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(markdown.utf8))
    }
}
