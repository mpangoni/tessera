import Foundation
import Markdown

/// Adapts Swift Markdown's source-specific syntax tree to Tessera's semantic element tree.
public struct MarkupAdapter {
    public init() {}

    /// Visits every Swift Markdown node and preserves a range into the original UTF-8 source.
    public func adapt(_ source: String, originalData: Data? = nil) -> ContentArtifact {
        var visitor = ElementVisitor(source: source)
        let root = visitor.visit(Document(parsing: source))
        return ContentArtifact(root: root, source: SourceSnapshot(data: originalData ?? Data(source.utf8)))
    }
}

/// Builds Tessera nodes while Swift Markdown dispatches to each native node visit method.
private struct ElementVisitor: MarkupVisitor {
    let source: String
    private let offsets: SourceOffsetMap
    private var ids = ElementNodeIDGenerator()

    init(source: String) {
        self.source = source
        self.offsets = SourceOffsetMap(source: source)
    }

    mutating func defaultVisit(_ markup: any Markup) -> ElementNode {
        let id = ids.next()
        var children: [ElementNode] = []
        for child in markup.children { children.append(visit(child)) }

        // Swift Markdown exposes inline/code text as a property rather than a child node.
        // Add a range-backed text child so renderers can access the content without storing it.
        if children.isEmpty, let code = codeText(for: markup),
           let contentRange = contentRange(of: code, in: markup) {
            children.append(ElementNode(id: ids.next(), kind: .text, source: contentRange))
        }

        let kind = elementKind(for: markup)
        return ElementNode(
            id: id,
            kind: kind,
            children: children,
            source: markup.range.flatMap { sourceRange(for: $0) }
        )
    }

    private func elementKind(for markup: any Markup) -> ElementKind {
        switch markup {
        case is Document: .document
        case let node as Heading: .heading(level: node.level)
        case is Paragraph: .paragraph
        case is BlockQuote: .quote
        case is ThematicBreak: .divider
        case is UnorderedList: .list(ordered: false)
        case is OrderedList: .list(ordered: true)
        case is ListItem: .listItem
        case let node as CodeBlock: .codeBlock(language: node.language)
        case is HTMLBlock: .embeddedContent
        case is Table: .table
        case is Text: .text
        case is Emphasis: .emphasis
        case is Strong: .strong
        case is InlineCode: .inlineCode
        case let node as Link: .link(destination: node.destination)
        case let node as Image: .image(source: node.source)
        case is Strikethrough: .strikethrough
        case is SoftBreak: .softBreak
        case is LineBreak: .lineBreak
        default: .custom(namespace: "swift-markdown", name: String(describing: type(of: markup)))
        }
    }

    private func codeText(for markup: any Markup) -> String? {
        switch markup {
        case let node as InlineCode: node.code
        case let node as CodeBlock: node.code
        default: nil
        }
    }

    private func sourceRange(for range: Markdown.SourceRange) -> SourceRange? {
        guard let start = offsets.utf8Offset(for: range.lowerBound),
              let end = offsets.utf8Offset(for: range.upperBound), end >= start else { return nil }
        return SourceRange(location: start, length: end - start)
    }

    /// Locates text exposed by Swift Markdown inside its original source span.
    private func contentRange(of content: String, in markup: any Markup) -> SourceRange? {
        guard let markupRange = markup.range,
              let outer = sourceRange(for: markupRange) else { return nil }
        let sourceBytes = Array(source.utf8)
        let contentBytes = Array(content.utf8)
        guard !contentBytes.isEmpty, outer.end <= sourceBytes.count,
              outer.length >= contentBytes.count else { return nil }
        let lastStart = outer.end - contentBytes.count
        for start in outer.location...lastStart where sourceBytes[start..<(start + contentBytes.count)].elementsEqual(contentBytes) {
            return SourceRange(location: start, length: contentBytes.count)
        }
        return nil
    }
}

/// Converts Swift Markdown's one-based UTF-8 locations to byte offsets in the source snapshot.
private struct SourceOffsetMap {
    private let lineStarts: [Int]
    private let sourceByteCount: Int

    init(source: String) {
        let bytes = Array(source.utf8)
        sourceByteCount = bytes.count
        var starts = [0]
        for (index, byte) in bytes.enumerated() where byte == 10 { starts.append(index + 1) }
        lineStarts = starts
    }

    func utf8Offset(for location: SourceLocation) -> Int? {
        guard location.line > 0, location.line <= lineStarts.count else { return nil }
        let offset = lineStarts[location.line - 1] + max(0, location.column - 1)
        return min(offset, sourceByteCount)
    }
}
