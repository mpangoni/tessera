import Foundation
import Testing
@testable import TesseraCore

@Test func parsesMarkdownIntoBlockAndInlineASTNodes() {
    let source = "# Heading\n\nA **bold** and [link](https://example.org).\n\n> Quoted\n\n---"
    let ast = MarkdownASTParser.parse(source)
    let nodes = flatten(ast.root)

    #expect(ast.root.kind == .document)
    #expect(nodes.contains { $0.kind == .heading(level: 1) })
    #expect(nodes.contains { $0.kind == .paragraph })
    #expect(nodes.contains { $0.kind == .strong })
    #expect(nodes.contains { $0.kind == .link(destination: "https://example.org") })
    #expect(nodes.contains { $0.kind == .blockQuote })
    #expect(nodes.contains { $0.kind == .thematicBreak })
}

@Test func semanticTextResolvesFromTheSharedSourceSnapshot() throws {
    let source = "**hello 🌿**"
    let artifact = try MarkdownCodec().parse(Data(source.utf8))
    let nodes = flattenElements(artifact.root)
    let visibleText = try #require(nodes.first { $0.kind == .text })

    #expect(artifact.source?.data == Data(source.utf8))
    #expect(artifact.sourceText(for: visibleText) == "hello 🌿")
}

@Test func convertsParserSourceLocationsToUTF16RangesAcrossUnicodeAndCRLF() {
    let source = "🌿 intro\r\n# Heading\r\n\r\nText **bold**"
    let ast = MarkdownASTParser.parse(source)
    let nodes = flatten(ast.root)
    let nsSource = source as NSString

    let heading = nodes.first { $0.kind == .heading(level: 1) }
    #expect(heading?.sourceRange.map { nsSource.substring(with: $0) } == "# Heading")

    let strong = nodes.first { $0.kind == .strong }
    #expect(strong?.sourceRange.map { nsSource.substring(with: $0) } == "**bold**")
}

@Test func blockQuoteASTRangeGroupsMultipleParagraphs() {
    let source = "> Sample text\n>\n> Another paragraph"
    let ast = MarkdownASTParser.parse(source)
    let quote = ast.root.children.first

    #expect(quote?.kind == .blockQuote)
    #expect(quote?.children.filter { $0.kind == .paragraph }.count == 2)
    #expect(quote?.sourceRange.map { (source as NSString).substring(with: $0) } == source)
}

@Test func sourceCommandsDeleteAndMoveTopLevelBlocksWithoutReformattingTheirText() {
    let source = "# First\r\n\r\nSecond **bold**\r\n\r\n> Third"
    let nsSource = source as NSString
    let secondOffset = nsSource.range(of: "Second").location

    let delete = MarkdownSourceCommands.deleteBlock(at: secondOffset, in: source)
    #expect(delete.map { nsSource.replacingCharacters(in: $0.range, with: $0.replacement) } == "# First\r\n\r\n> Third")

    let move = MarkdownSourceCommands.moveBlock(at: secondOffset, by: -1, caretOffset: secondOffset + 4, in: source)
    #expect(move.map { nsSource.replacingCharacters(in: $0.range, with: $0.replacement) } == "Second **bold**\r\n\r\n# First\r\n\r\n> Third")
    #expect(move?.caretOffset == 4)

    let thirdOffset = nsSource.range(of: "Third").location
    let dragMove = MarkdownSourceCommands.moveBlock(at: thirdOffset, to: nsSource.range(of: "First").location, caretOffset: thirdOffset + 2, in: source)
    #expect(dragMove.map { nsSource.replacingCharacters(in: $0.range, with: $0.replacement) } == "> Third\r\n\r\n# First\r\n\r\nSecond **bold**")
}

@Test func sourceCommandsSplitAndMergeParagraphAndHeadingBlocks() {
    let paragraph = "Hello world"
    let paragraphSplit = MarkdownSourceCommands.splitBlock(
        replacing: NSRange(location: 6, length: 0),
        in: paragraph
    )
    #expect(paragraphSplit.map { (paragraph as NSString).replacingCharacters(in: $0.range, with: $0.replacement) } == "Hello \n\nworld")
    #expect(paragraphSplit?.caretOffset == 8)

    let heading = "# Heading\n\nParagraph"
    let paragraphStart = (heading as NSString).range(of: "Paragraph").location
    let merged = MarkdownSourceCommands.mergePreviousBlock(at: paragraphStart, in: heading)
    #expect(merged.map { (heading as NSString).replacingCharacters(in: $0.range, with: $0.replacement) } == "# HeadingParagraph")
    #expect(merged?.caretOffset == 9)
}

@Test func sourceCommandsContinueQuoteAndListMarkersWhenSplitting() {
    let quote = "> Hello world"
    let quoteSplit = MarkdownSourceCommands.splitBlock(replacing: NSRange(location: 8, length: 0), in: quote)
    #expect(quoteSplit.map { (quote as NSString).replacingCharacters(in: $0.range, with: $0.replacement) } == "> Hello \n> world")

    let list = "- Hello world"
    let listSplit = MarkdownSourceCommands.splitBlock(replacing: NSRange(location: 8, length: 0), in: list)
    #expect(listSplit.map { (list as NSString).replacingCharacters(in: $0.range, with: $0.replacement) } == "- Hello \n- world")
}

private func flatten(_ node: MarkdownASTNode) -> [MarkdownASTNode] {
    [node] + node.children.flatMap(flatten)
}

private func flattenElements(_ node: ElementNode) -> [ElementNode] {
    [node] + node.children.flatMap(flattenElements)
}
