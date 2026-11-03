import Foundation
import Markdown

/// Prints Swift Markdown's parsed tree for a Markdown file supplied on the command line.
@main
enum MarkdownASTPreview {
    static func main() throws {
        guard let path = CommandLine.arguments.dropFirst().first else {
            fputs("Usage: swift run MarkdownASTPreview <markdown-file>\n", stderr)
            exit(EXIT_FAILURE)
        }

        let source = try String(contentsOfFile: path, encoding: .utf8)
        let document = Document(parsing: source)
        print(document.debugDescription())
    }
}
