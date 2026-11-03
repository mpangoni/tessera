import Foundation

/// Semantic kinds exposed to renderers without leaking Swift Markdown node classes.
public enum MarkdownASTNodeKind: Equatable, Sendable {
    case document
    case heading(level: Int)
    case paragraph
    case blockQuote
    case thematicBreak
    case unorderedList
    case orderedList
    case listItem
    case codeBlock(language: String?)
    case htmlBlock
    case table
    case text
    case emphasis
    case strong
    case inlineCode
    case link(destination: String?)
    case image(source: String?)
    case strikethrough
    case softBreak
    case lineBreak
    case inlineHTML
    case other(String)
}

/// One parsed Markdown node, addressed by its stable path within this parse and source range.
public struct MarkdownASTNode: Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: MarkdownASTNodeKind
    /// UTF-16 range into the exact source string, suitable for AppKit text selections.
    public let sourceRange: NSRange?
    public let children: [MarkdownASTNode]

    public init(id: String, kind: MarkdownASTNodeKind, sourceRange: NSRange?, children: [MarkdownASTNode]) {
        self.id = id
        self.kind = kind
        self.sourceRange = sourceRange
        self.children = children
    }
}

/// The AST is a derived view of Markdown source, never a replacement for the saved source text.
public struct MarkdownAST: Equatable, Sendable {
    public let root: MarkdownASTNode

    public init(root: MarkdownASTNode) { self.root = root }
}

