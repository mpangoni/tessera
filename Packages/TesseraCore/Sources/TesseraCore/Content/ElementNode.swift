import Foundation

/// Shared semantic categories for content from Markdown, diagrams, equations, and other formats.
public enum ElementKind: Equatable, Sendable {
    case document
    
    // block content elements
    case container
    case paragraph
    case heading(level: Int)
    case quote
    case list(ordered: Bool)
    case listItem
    case codeBlock(language: String?)
    case image(source: String?)
    case divider
    case table
    case embeddedContent
    case softBreak
    case lineBreak
    case equation
    case diagram
    case chart
    case custom(namespace: String, name: String)
    
    // inline text elements
    case text
    case emphasis
    case strong
    case strikethrough
    case inlineCode
    case link(destination: String?)

}

/// Assigns compact preorder IDs while a codec constructs one artifact's tree.
public struct ElementNodeIDGenerator: Sendable {
    private var nextValue: UInt64 = 0

    public init() {}

    public mutating func next() -> UInt64 {
        defer { nextValue += 1 }
        return nextValue
    }
}

/// A node in Tessera's format-neutral content AST.
public struct ElementNode: Equatable, Sendable, Identifiable {
    /// Compact identity scoped to one artifact; codecs assign IDs during tree construction.
    public var id: UInt64
    public var kind: ElementKind
    public var children: [ElementNode]
    public var source: SourceRange?

    public init(
        id: UInt64,
        kind: ElementKind,
        children: [ElementNode] = [],
        source: SourceRange? = nil
    ) {
        self.id = id
        self.kind = kind
        self.children = children
        self.source = source
    }
}
