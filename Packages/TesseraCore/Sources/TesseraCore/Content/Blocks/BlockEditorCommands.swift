import Foundation

/// The small set of edits that can change block order or content.
/// Keeping these operations here lets the app and future platforms share the same rules.
public enum BlockEditorCommands {
    /// Inserts a new block at `index`, marks it as new, and returns its ID.
    /// Valid insertion positions include the start and the end of the document.
    @discardableResult
    public static func insert(_ block: TesseraBlock, at index: Int, in document: inout BlockDocument) throws -> UUID {
        guard (0...document.blocks.count).contains(index) else { throw TesseraError.invalidBlockIndex }
        var item = block
        item.isDirty = true
        item.source = nil
        if index > 0 && item.precedingSeparator.isEmpty { item.precedingSeparator = document.lineEnding + document.lineEnding }
        document.blocks.insert(item, at: index)
        document.hasBeenEdited = true
        return item.id
    }

    /// Replaces a block's text and clears its saved source because that source is now out of date.
    public static func update(id: UUID, content: String, in document: inout BlockDocument) throws {
        guard let index = document.blocks.firstIndex(where: { $0.id == id }) else { throw TesseraError.invalidBlockIndex }
        document.blocks[index].content = content
        document.blocks[index].isDirty = true
        document.blocks[index].source = nil
        document.hasBeenEdited = true
    }

    /// Changes a block's Markdown type and marks its old source as stale.
    public static func updateKind(id: UUID, kind: BlockKind, in document: inout BlockDocument) throws {
        guard let index = document.blocks.firstIndex(where: { $0.id == id }) else { throw TesseraError.invalidBlockIndex }
        document.blocks[index].kind = kind
        document.blocks[index].isDirty = true
        document.blocks[index].source = nil
        document.hasBeenEdited = true
    }

    /// Splits a block at a character offset, leaving an empty side when the offset is at an edge.
    public static func split(id: UUID, at offset: Int, in document: inout BlockDocument) throws -> UUID {
        try split(id: id, replacing: offset..<offset, in: &document)
    }

    /// Replaces the selected character range with a block boundary and returns the new block's ID.
    /// List items and quotes continue as the same type; ordinary text becomes a paragraph.
    @discardableResult
    public static func split(id: UUID, replacing range: Range<Int>, in document: inout BlockDocument) throws -> UUID {
        guard let index = document.blocks.firstIndex(where: { $0.id == id }), isSplitable(document.blocks[index].kind) else { throw TesseraError.unsafeMerge }
        let text = document.blocks[index].content
        guard range.lowerBound >= 0, range.upperBound >= range.lowerBound, range.upperBound <= text.count else { throw TesseraError.invalidBlockIndex }
        let start = text.index(text.startIndex, offsetBy: range.lowerBound)
        let end = text.index(text.startIndex, offsetBy: range.upperBound)
        document.blocks[index].content = String(text[..<start])
        document.blocks[index].isDirty = true
        document.blocks[index].source = nil
        let nextKind: BlockKind
        switch document.blocks[index].kind {
        case .unorderedListItem: nextKind = .unorderedListItem
        case .orderedListItem(let number): nextKind = .orderedListItem(number: number + 1)
        case .blockquote: nextKind = .blockquote
        default: nextKind = .paragraph
        }
        let added = TesseraBlock(kind: nextKind, content: String(text[end...]), precedingSeparator: document.lineEnding + document.lineEnding, isDirty: true)
        document.blocks.insert(added, at: index + 1)
        document.hasBeenEdited = true
        return added.id
    }

    /// Moves a block to its new zero-based position in the ordered document.
    public static func move(id: UUID, to destination: Int, in document: inout BlockDocument) throws {
        guard let source = document.blocks.firstIndex(where: { $0.id == id }), (0..<document.blocks.count).contains(destination) else { throw TesseraError.invalidBlockIndex }
        let block = document.blocks.remove(at: source)
        document.blocks.insert(block, at: min(destination, document.blocks.count))
        document.hasBeenEdited = true
    }

    /// Removes a block and returns it so callers can inspect it or register an undo operation.
    @discardableResult
    public static func delete(id: UUID, in document: inout BlockDocument) throws -> TesseraBlock {
        guard let index = document.blocks.firstIndex(where: { $0.id == id }) else { throw TesseraError.invalidBlockIndex }
        document.hasBeenEdited = true
        return document.blocks.remove(at: index)
    }

    /// Joins this block onto the end of the preceding block and returns the UTF-16 join offset.
    /// The offset uses UTF-16 because AppKit's text selection APIs use that indexing scheme.
    @discardableResult
    public static func mergePrevious(id: UUID, in document: inout BlockDocument) throws -> Int {
        guard let index = document.blocks.firstIndex(where: { $0.id == id }), index > 0,
              isMergeable(document.blocks[index - 1].kind), isMergeable(document.blocks[index].kind) else { throw TesseraError.unsafeMerge }
        let joinOffset = document.blocks[index - 1].content.utf16.count
        document.blocks[index - 1].content += document.blocks[index].content
        document.blocks[index - 1].isDirty = true
        document.blocks[index - 1].source = nil
        document.blocks.remove(at: index)
        document.hasBeenEdited = true
        return joinOffset
    }

    /// Only plain text-like blocks can be split without risking a malformed Markdown structure.
    private static func isSplitable(_ kind: BlockKind) -> Bool {
        switch kind { case .paragraph, .heading, .unorderedListItem, .orderedListItem, .blockquote: true; default: false }
    }
    /// Only plain text-like blocks can be joined without flattening structured content.
    private static func isMergeable(_ kind: BlockKind) -> Bool {
        switch kind { case .paragraph, .heading, .unorderedListItem, .orderedListItem, .blockquote: true; default: false }
    }
}
