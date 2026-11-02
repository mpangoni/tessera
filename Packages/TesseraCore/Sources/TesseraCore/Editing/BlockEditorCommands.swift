import Foundation

public enum BlockEditorCommands {
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

    public static func update(id: UUID, content: String, in document: inout BlockDocument) throws {
        guard let index = document.blocks.firstIndex(where: { $0.id == id }) else { throw TesseraError.invalidBlockIndex }
        document.blocks[index].content = content
        document.blocks[index].isDirty = true
        document.blocks[index].source = nil
        document.hasBeenEdited = true
    }

    public static func updateKind(id: UUID, kind: BlockKind, in document: inout BlockDocument) throws {
        guard let index = document.blocks.firstIndex(where: { $0.id == id }) else { throw TesseraError.invalidBlockIndex }
        document.blocks[index].kind = kind
        document.blocks[index].isDirty = true
        document.blocks[index].source = nil
        document.hasBeenEdited = true
    }

    public static func split(id: UUID, at offset: Int, in document: inout BlockDocument) throws -> UUID {
        guard let index = document.blocks.firstIndex(where: { $0.id == id }), isSplitable(document.blocks[index].kind) else { throw TesseraError.unsafeMerge }
        let text = document.blocks[index].content
        guard offset >= 0 && offset <= text.count else { throw TesseraError.invalidBlockIndex }
        let cut = text.index(text.startIndex, offsetBy: offset)
        document.blocks[index].content = String(text[..<cut])
        document.blocks[index].isDirty = true
        document.blocks[index].source = nil
        let added = TesseraBlock(kind: .paragraph, content: String(text[cut...]), precedingSeparator: document.lineEnding + document.lineEnding, isDirty: true)
        document.blocks.insert(added, at: index + 1)
        document.hasBeenEdited = true
        return added.id
    }

    public static func move(id: UUID, to destination: Int, in document: inout BlockDocument) throws {
        guard let source = document.blocks.firstIndex(where: { $0.id == id }), (0..<document.blocks.count).contains(destination) else { throw TesseraError.invalidBlockIndex }
        let block = document.blocks.remove(at: source)
        document.blocks.insert(block, at: min(destination, document.blocks.count))
        document.hasBeenEdited = true
    }

    @discardableResult
    public static func delete(id: UUID, in document: inout BlockDocument) throws -> TesseraBlock {
        guard let index = document.blocks.firstIndex(where: { $0.id == id }) else { throw TesseraError.invalidBlockIndex }
        document.hasBeenEdited = true
        return document.blocks.remove(at: index)
    }

    public static func mergePrevious(id: UUID, in document: inout BlockDocument) throws {
        guard let index = document.blocks.firstIndex(where: { $0.id == id }), index > 0,
              isMergeable(document.blocks[index - 1].kind), isMergeable(document.blocks[index].kind) else { throw TesseraError.unsafeMerge }
        document.blocks[index - 1].content += document.blocks[index].content
        document.blocks[index - 1].isDirty = true
        document.blocks[index - 1].source = nil
        document.blocks.remove(at: index)
        document.hasBeenEdited = true
    }

    private static func isSplitable(_ kind: BlockKind) -> Bool {
        switch kind { case .paragraph, .heading: true; default: false }
    }
    private static func isMergeable(_ kind: BlockKind) -> Bool {
        switch kind { case .paragraph, .heading, .unorderedListItem, .orderedListItem, .blockquote: true; default: false }
    }
}
