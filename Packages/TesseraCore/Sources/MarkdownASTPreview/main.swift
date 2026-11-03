import Foundation
import TesseraCore

/// Parses a Markdown document with Tessera's codec and prints its semantic AST.
@main
enum MarkdownASTPreview {
    private static let samplePath = "Samples/Markdown/Markdown-Basic-Syntax-Reference.md"

    static func main() throws {
        let path = try inputPath()
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let artifact = try MarkdownCodec().parse(data)

        print("Tessera AST: \(path)")
        print("Source bytes: \(data.count)")
        printTree(artifact.root, artifact: artifact, depth: 0)
    }

    /// Uses the requested file when supplied, otherwise finds the bundled sample from common roots.
    private static func inputPath() throws -> String {
        if let provided = CommandLine.arguments.dropFirst().first {
            return provided
        }

        let candidates = [samplePath, "../../\(samplePath)"]
        if let path = candidates.first(where: FileManager.default.fileExists(atPath:)) {
            return path
        }

        fputs("Usage: swift run MarkdownASTPreview [markdown-file]\n", stderr)
        fputs("Default sample not found: \(samplePath)\n", stderr)
        exit(EXIT_FAILURE)
    }

    /// Shows the format-neutral kind, compact ID, byte range, and visible text when applicable.
    private static func printTree(_ node: ElementNode, artifact: ContentArtifact, depth: Int) {
        let indent = String(repeating: "  ", count: depth)
        let range = node.source.map { "bytes \($0.location)..<\($0.end)" } ?? "no source range"
        let text = node.kind == .text ? artifact.sourceText(for: node).map { " text=\($0.debugDescription)" } ?? "" : ""
        print("\(indent)\(node.id): \(node.kind) [\(range)]\(text)")

        for child in node.children {
            printTree(child, artifact: artifact, depth: depth + 1)
        }
    }
}
