import Foundation

/// Compatibility view for clients that still need Markdown-specific node names and UTF-16 ranges.
/// The actual parse is performed by `MarkupAdapter` and its format-neutral `ElementNode` tree.
public enum MarkdownASTParser {
    public static func parse(_ source: String) -> MarkdownAST {
        let root = MarkupAdapter().adapt(source).root
        return MarkdownAST(root: legacyNode(root, source: source))
    }

    private static func legacyNode(_ node: ElementNode, source: String) -> MarkdownASTNode {
        MarkdownASTNode(
            id: String(node.id),
            kind: legacyKind(node.kind),
            sourceRange: utf16Range(node.source, in: source),
            children: node.children.map { legacyNode($0, source: source) }
        )
    }

    private static func legacyKind(_ kind: ElementKind) -> MarkdownASTNodeKind {
        switch kind {
        case .document: .document
        case .heading(let level): .heading(level: level)
        case .paragraph: .paragraph
        case .quote: .blockQuote
        case .divider: .thematicBreak
        case .list(let ordered): ordered ? .orderedList : .unorderedList
        case .listItem: .listItem
        case .codeBlock(let language): .codeBlock(language: language)
        case .embeddedContent: .htmlBlock
        case .table: .table
        case .text: .text
        case .emphasis: .emphasis
        case .strong: .strong
        case .inlineCode: .inlineCode
        case .link(let destination): .link(destination: destination)
        case .image(let source): .image(source: source)
        case .strikethrough: .strikethrough
        case .softBreak: .softBreak
        case .lineBreak: .lineBreak
        case .custom(let namespace, let name): .other("\(namespace).\(name)")
        case .container, .equation, .diagram, .chart: .other(String(describing: kind))
        }
    }

    private static func utf16Range(_ range: SourceRange?, in source: String) -> NSRange? {
        guard let range,
              range.unit == .utf8Byte,
              range.location >= 0,
              range.end <= source.utf8.count else { return nil }
        let start = String(decoding: source.utf8.prefix(range.location), as: UTF8.self).utf16.count
        let end = String(decoding: source.utf8.prefix(range.end), as: UTF8.self).utf16.count
        return NSRange(location: start, length: end - start)
    }
}
