import Foundation
import Testing
@testable import TesseraCore

/// An untouched file keeps its original spelling, Unicode, line endings, and final newline.
@Test func untouchedSourceIsByteForBytePreserved() {
    for source in ["# Olá 🌱\n\nText **bold**\n", "one\r\n\r\ntwo\r\n", ""] {
        let document = MarkdownCodec.decode(source)
        #expect(MarkdownCodec.encode(document) == source)
    }
}

/// Common Markdown blocks are recognized, while tables remain intact as raw Markdown.
@Test func recognizesBlockTypesAndKeepsUnsupportedConstructsOpaque() {
    let source = "# Heading\n\n- first\n- second\n\n```swift\nprint(1)\n```\n\n| a | b |\n| - | - |\n| x | y |"
    let document = MarkdownCodec.decode(source)
    #expect(document.blocks.map(\.kind) == [.heading(level: 1), .unorderedListItem, .unorderedListItem, .fencedCode(language: "swift"), .rawMarkdown])
    #expect(document.blocks[4].source?.contains("| a | b |") == true)
}

/// Invalid UTF-8 is reported instead of being silently replaced with other characters.
@Test func invalidUtf8IsRejected() {
    #expect(throws: TesseraError.invalidUTF8) { try MarkdownCodec.decode(Data([0xFF, 0xFE])) }
}

/// Headings at every supported level, ordered lists, quotes, and rules map to their block types.
@Test func recognizesRemainingBasicBlocks() {
    let source = "# one\n## two\n### three\n#### four\n##### five\n###### six\n\n1. ordered\n\n> quote\n\n---"
    let kinds = MarkdownCodec.decode(source).blocks.map(\.kind)
    #expect(kinds == [.heading(level: 1), .heading(level: 2), .heading(level: 3), .heading(level: 4), .heading(level: 5), .heading(level: 6), .orderedListItem(number: 1), .blockquote, .horizontalRule])
}

/// Horizontal-rule spellings and quote markers remain unchanged in an untouched document.
@Test func horizontalRuleVariantsAndBlockquoteSourceRoundTripExactly() {
    for rule in ["---", "***", "___"] {
        let source = "Before\n\n> Quoted text\n\n\(rule)\n"
        let document = MarkdownCodec.decode(source)
        #expect(document.blocks.map(\.kind) == [.paragraph, .blockquote, .horizontalRule])
        #expect(MarkdownCodec.encode(document) == source)
    }
}

/// Editing a supported block does not rewrite an unrelated HTML block.
@Test func editingSupportedBlockLeavesOpaqueSourceVerbatim() throws {
    var document = MarkdownCodec.decode("Before\n\n<table>\n<tr><td>x</td></tr>\n</table>\n\nAfter")
    let opaque = document.blocks[1].source!
    try BlockEditorCommands.update(id: document.blocks[0].id, content: "Changed", in: &document)
    let output = MarkdownCodec.encode(document)
    #expect(output.contains(opaque))
    #expect(output.contains("Changed"))
}

/// Nested lists stay together as one raw block because the editor cannot safely split them yet.
@Test func nestedListStaysInOneOpaqueBlock() {
    let document = MarkdownCodec.decode("- parent\n  - child\n")
    #expect(document.blocks.count == 1)
    #expect(document.blocks[0].kind == .rawMarkdown)
}

/// Reordering code or raw blocks keeps their exact source text in the saved document.
@Test func movingOpaqueAndCodeBlocksKeepsTheirSource() throws {
    var document = MarkdownCodec.decode("before\n\n```weird\na  `quote`\n```\n\n<table>x</table>\n\nafter")
    let codeSource = document.blocks[1].source!
    let htmlSource = document.blocks[2].source!
    try BlockEditorCommands.move(id: document.blocks[2].id, to: 0, in: &document)
    let output = MarkdownCodec.encode(document)
    #expect(output.contains(codeSource))
    #expect(output.contains(htmlSource))
}

/// Leading and trailing empty paragraphs survive edits and a save/reopen parse cycle.
@Test func emptyLeadingAndTrailingParagraphsSurviveEditedSerialization() throws {
    for source in ["\n\nbody", "body\n\n"] {
        var document = MarkdownCodec.decode(source)
        #expect(document.blocks.count == 2)
        try BlockEditorCommands.update(id: document.blocks.first(where: { !$0.content.isEmpty })!.id, content: "edited", in: &document)
        let saved = MarkdownCodec.encode(document)
        #expect(MarkdownCodec.decode(saved).blocks.count == 2)
    }
}
