import Foundation
import Testing
@testable import TesseraCore

@Test func splitMoveDeleteAndSafeMerge() throws {
    var document = BlockDocument(blocks: [
        TesseraBlock(kind: .paragraph, content: "alpha beta"),
        TesseraBlock(kind: .rawMarkdown, content: "|a|b|")
    ])
    let first = document.blocks[0].id
    let second = try BlockEditorCommands.split(id: first, at: 5, in: &document)
    #expect(document.blocks.map(\.content) == ["alpha", " beta", "|a|b|"])
    try BlockEditorCommands.move(id: second, to: 0, in: &document)
    #expect(document.blocks[0].id == second)
    try BlockEditorCommands.mergePrevious(id: first, in: &document)
    #expect(document.blocks[0].content == " betaalpha")
    let removed = try BlockEditorCommands.delete(id: document.blocks[1].id, in: &document)
    #expect(removed.kind == .rawMarkdown)
    #expect(document.blocks.count == 1)
}

@Test func nonTextMergeIsRefused() throws {
    var document = BlockDocument(blocks: [TesseraBlock(kind: .fencedCode(language: nil), content: "code"), TesseraBlock(kind: .paragraph, content: "text")])
    #expect(throws: TesseraError.unsafeMerge) { try BlockEditorCommands.mergePrevious(id: document.blocks[1].id, in: &document) }
    #expect(document.blocks.count == 2)
}

@Test func splitReplacesSelectedTextAndPreservesOrder() throws {
    var document = BlockDocument(blocks: [TesseraBlock(kind: .paragraph, content: "Hello beautiful world")])
    let oldID = document.blocks[0].id
    let newID = try BlockEditorCommands.split(id: oldID, replacing: 6..<16, in: &document)
    #expect(document.blocks.map(\.content) == ["Hello ", "world"])
    #expect(document.blocks[0].id == oldID)
    #expect(document.blocks[1].id == newID)
}

@Test func mergeReturnsExactUTF16CaretJoinPoint() throws {
    var document = BlockDocument(blocks: [TesseraBlock(kind: .paragraph, content: "Olá 🌱"), TesseraBlock(kind: .paragraph, content: " world")])
    let caret = try BlockEditorCommands.mergePrevious(id: document.blocks[1].id, in: &document)
    #expect(caret == ("Olá 🌱" as NSString).length)
    #expect(document.blocks.map(\.content) == ["Olá 🌱 world"])
}

@Test func splitOnListContinuesListAndNumbering() throws {
    var unordered = BlockDocument(blocks: [TesseraBlock(kind: .unorderedListItem, content: "alpha beta")])
    let nextUnordered = try BlockEditorCommands.split(id: unordered.blocks[0].id, at: 5, in: &unordered)
    #expect(unordered.blocks[1].id == nextUnordered)
    #expect(unordered.blocks[1].kind == .unorderedListItem)

    var ordered = BlockDocument(blocks: [TesseraBlock(kind: .orderedListItem(number: 4), content: "alpha beta")])
    _ = try BlockEditorCommands.split(id: ordered.blocks[0].id, at: 5, in: &ordered)
    #expect(ordered.blocks[1].kind == .orderedListItem(number: 5))
}

@Test func splitThenMergeSerializesWithBlankParagraphBoundary() throws {
    var document = MarkdownCodec.decode("Hello beautiful world\n\nSecond paragraph\n")
    let first = document.blocks[0].id
    let second = try BlockEditorCommands.split(id: first, at: 15, in: &document)
    try BlockEditorCommands.mergePrevious(id: second, in: &document)
    let saved = MarkdownCodec.encode(document)
    #expect(saved.contains("Hello beautiful world\n\nSecond paragraph"))
    #expect(MarkdownCodec.decode(saved).blocks.map(\.content) == ["Hello beautiful world", "Second paragraph"])
}
