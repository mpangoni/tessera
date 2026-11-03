import SwiftUI
import UniformTypeIdentifiers

/// The native macOS document wrapper. Markdown remains the file's only stored data.
struct MarkdownDocument: FileDocument {
    // Markdown UTType is not exposed by the installed macOS 26 SDK.
    /// Accepts Markdown files and plain-text files through macOS's document picker.
    static var readableContentTypes: [UTType] { [UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText), .plainText] }
    var markdown: String

    /// Starts a new empty Markdown document.
    init(markdown: String = "") { self.markdown = markdown }

    /// Loads the file as UTF-8. Invalid text fails visibly instead of being altered during import.
    init(configuration: ReadConfiguration) throws {
        guard let text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        markdown = text
    }
    /// Writes the current Markdown string back as UTF-8 file contents.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(markdown.utf8))
    }
}
