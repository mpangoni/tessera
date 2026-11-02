import Foundation

/// The Markdown block formats Tessera can edit as separate document items.
/// Use `rawMarkdown` when a construct is not safe to reshape into another type.
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

/// One editable item in a document. Its ID stays stable while that item is edited or moved in this session.
public struct TesseraBlock: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: BlockKind
    public var content: String
    /// The original Markdown spelling, kept so an untouched block can be written back exactly.
    public var source: String?
    /// Blank lines or other spacing that appeared immediately before this block in the source file.
    public var precedingSeparator: String
    /// Set after an edit so the codec knows it must serialize `content` instead of reusing `source`.
    public var isDirty: Bool

    /// Creates a block and, unless supplied, gives it a fresh session ID.
    public init(id: UUID = UUID(), kind: BlockKind, content: String, source: String? = nil, precedingSeparator: String = "", isDirty: Bool = false) {
        self.id = id
        self.kind = kind
        self.content = content
        self.source = source
        self.precedingSeparator = precedingSeparator
        self.isDirty = isDirty
    }
}

/// The ordered blocks plus the source details needed to preserve Markdown when saving.
public struct BlockDocument: Equatable, Sendable {
    public var blocks: [TesseraBlock]
    /// Full original text, used for a byte-for-byte-equivalent save if nothing was edited.
    public var originalSource: String?
    /// The line ending style to use for any newly serialized text.
    public var lineEnding: String
    /// Final source text that is not represented by a normal block, such as trailing blank lines.
    public var trailingSource: String
    /// Indicates that a document edit has happened since it was decoded.
    public var hasBeenEdited: Bool

    /// Creates a document model. Defaults represent an empty, unedited Markdown document.
    public init(blocks: [TesseraBlock] = [], originalSource: String? = nil, lineEnding: String = "\n", trailingSource: String = "", hasBeenEdited: Bool = false) {
        self.blocks = blocks
        self.originalSource = originalSource
        self.lineEnding = lineEnding
        self.trailingSource = trailingSource
        self.hasBeenEdited = hasBeenEdited
    }
}

/// Errors raised when Markdown cannot be read or a requested block edit is unsafe.
public enum TesseraError: Error, Equatable {
    /// The input file was not valid UTF-8 text.
    case invalidUTF8
    /// A block ID or insertion destination did not refer to a valid document position.
    case invalidBlockIndex
    /// The requested split or merge could not be done safely for that block type.
    case unsafeMerge
}
