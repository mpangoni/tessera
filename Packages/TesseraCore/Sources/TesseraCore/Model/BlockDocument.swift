import Foundation

public enum BlockKind: Equatable, Sendable {
    case paragraph
    case heading(level: Int)
    case unorderedListItem
    case orderedListItem(number: Int)
    case blockquote
    case fencedCode(language: String?)
    case horizontalRule
    case rawMarkdown
}

public struct TesseraBlock: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: BlockKind
    public var content: String
    public var source: String?
    public var precedingSeparator: String
    public var isDirty: Bool

    public init(id: UUID = UUID(), kind: BlockKind, content: String, source: String? = nil, precedingSeparator: String = "", isDirty: Bool = false) {
        self.id = id
        self.kind = kind
        self.content = content
        self.source = source
        self.precedingSeparator = precedingSeparator
        self.isDirty = isDirty
    }
}

public struct BlockDocument: Equatable, Sendable {
    public var blocks: [TesseraBlock]
    public var originalSource: String?
    public var lineEnding: String
    public var trailingSource: String
    public var hasBeenEdited: Bool

    public init(blocks: [TesseraBlock] = [], originalSource: String? = nil, lineEnding: String = "\n", trailingSource: String = "", hasBeenEdited: Bool = false) {
        self.blocks = blocks
        self.originalSource = originalSource
        self.lineEnding = lineEnding
        self.trailingSource = trailingSource
        self.hasBeenEdited = hasBeenEdited
    }
}

public enum TesseraError: Error, Equatable {
    case invalidUTF8
    case invalidBlockIndex
    case unsafeMerge
}
