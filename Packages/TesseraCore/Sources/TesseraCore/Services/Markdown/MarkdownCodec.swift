import Foundation

/// Converts Markdown bytes to Tessera's format-neutral AST and back to Markdown bytes.
public struct MarkdownCodec: ContentCodec {
    private let adapter: MarkupAdapter

    public init(adapter: MarkupAdapter = MarkupAdapter()) {
        self.adapter = adapter
    }

    public func parse(_ data: Data) throws -> ContentArtifact {
        guard let source = String(data: data, encoding: .utf8) else { throw TesseraError.invalidUTF8 }
        return adapter.adapt(source, originalData: data)
    }

    public func encode(_ artifact: ContentArtifact) throws -> Data {
        Data(MarkdownTreeEncoder(artifact: artifact).encode(artifact.root).utf8)
    }

    /// Compatibility entry point for the existing editable block-document model.
    public static func decode(_ data: Data) throws -> BlockDocument {
        try MarkdownBlockCodec.decode(data)
    }

    /// Compatibility entry point for the existing editable block-document model.
    public static func decode(_ source: String) -> BlockDocument {
        MarkdownBlockCodec.decode(source)
    }

    /// Compatibility encoder for the existing editable block-document model.
    public static func encode(_ document: BlockDocument) -> String {
        MarkdownBlockCodec.encode(document)
    }
}

/// Serializes the shared AST by its semantic kinds, without depending on Swift Markdown nodes.
private struct MarkdownTreeEncoder {
    let artifact: ContentArtifact

    func encode(_ node: ElementNode) -> String {
        switch node.kind {
        case .document, .container:
            return node.children.map(encode).filter { !$0.isEmpty }.joined(separator: "\n\n")
        case .paragraph: return inlineChildren(of: node)
        case .heading(let level): return String(repeating: "#", count: min(max(level, 1), 6)) + " " + inlineChildren(of: node)
        case .quote:
            return encodeChildren(node).components(separatedBy: "\n").map { "> " + $0 }.joined(separator: "\n")
        case .list(let ordered):
            return node.children.enumerated().map { index, child in
                let marker = ordered ? "\(index + 1). " : "- "
                return marker + encode(child).replacingOccurrences(of: "\n", with: "\n  ")
            }.joined(separator: "\n")
        case .listItem: return encodeChildren(node)
        case .codeBlock(let language):
            let body = inlineChildren(of: node)
            let longest = body.components(separatedBy: "\n").map { $0.prefix(while: { $0 == "`" }).count }.max() ?? 0
            let fence = String(repeating: "`", count: max(3, longest + 1))
            return "\(fence)\(language.map { " " + $0 } ?? "")\n\(body)\n\(fence)"
        case .divider: return "---"
        case .table, .embeddedContent: return text(of: node)
        case .image(let source): return "![\(inlineChildren(of: node))](\(source ?? ""))"
        case .text: return text(of: node)
        case .emphasis: return "*\(inlineChildren(of: node))*"
        case .strong: return "**\(inlineChildren(of: node))**"
        case .strikethrough: return "~~\(inlineChildren(of: node))~~"
        case .inlineCode: return "`\(inlineChildren(of: node))`"
        case .link(let destination): return "[\(inlineChildren(of: node))](\(destination ?? ""))"
        case .softBreak: return "\n"
        case .lineBreak: return "  \n"
        case .equation, .diagram, .chart, .custom:
            return node.children.isEmpty ? text(of: node) : encodeChildren(node)
        }
    }

    private func encodeChildren(_ node: ElementNode) -> String { node.children.map(encode).joined() }
    private func inlineChildren(of node: ElementNode) -> String { encodeChildren(node) }

    /// Resolves a source slice only when serialization needs its characters.
    private func text(of node: ElementNode) -> String {
        artifact.sourceText(for: node) ?? ""
    }
}
