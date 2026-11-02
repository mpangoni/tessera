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
