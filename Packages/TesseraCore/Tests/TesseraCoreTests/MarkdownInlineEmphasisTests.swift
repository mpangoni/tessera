import Foundation
import Testing
@testable import TesseraCore

@Test func parsesBoldItalicAndCombinedEmphasisRanges() {
    let source = "A **bold** and *italic* word, plus ***both***."
    let ranges = MarkdownInlineEmphasisParser.ranges(in: source)
    let text = source as NSString

    #expect(ranges.filter(\.isBold).map { text.substring(with: $0.range) } == ["bold", "both"])
    #expect(ranges.filter(\.isItalic).map { text.substring(with: $0.range) } == ["italic", "both"])
    #expect(ranges.flatMap(\.delimiterRanges).map { text.substring(with: $0) } == ["**", "**", "*", "*", "***", "***"])
}

@Test func keepsNestedEmphasisRangesAndUnicodeOffsetsAccurate() {
    let source = "Olá **café *forte* 🌱**"
    let ranges = MarkdownInlineEmphasisParser.ranges(in: source)
    let text = source as NSString

    #expect(ranges.contains { $0.isBold && text.substring(with: $0.range) == "café *forte* 🌱" })
    #expect(ranges.contains { $0.isItalic && text.substring(with: $0.range) == "forte" })
    #expect(ranges.flatMap(\.delimiterRanges).map { text.substring(with: $0) } == ["**", "**", "*", "*"])
}

@Test func ignoresEscapedMarkersAndInlineCode() {
    let source = #"\*literal\* `**code**` and **real**"#
    let ranges = MarkdownInlineEmphasisParser.ranges(in: source)

    #expect(ranges.count == 1)
    #expect((source as NSString).substring(with: ranges[0].range) == "real")
}

@Test func recognizesUnderscoreEmphasisWithoutFormattingInsideWords() {
    let source = "_italic_ and __bold__, but not under_score"
    let ranges = MarkdownInlineEmphasisParser.ranges(in: source)
    let text = source as NSString

    #expect(ranges.filter(\.isItalic).map { text.substring(with: $0.range) } == ["italic"])
    #expect(ranges.filter(\.isBold).map { text.substring(with: $0.range) } == ["bold"])
}

@Test func independentDecorationsReturnRangesAndKeepLinkDestination() {
    let source = "**bold** _italic_ and [Tessera](https://example.com/path)"
    let bold = MarkdownBoldDecoration().matches(in: source)
    let italic = MarkdownItalicDecoration().matches(in: source)
    let links = MarkdownLinkDecoration().matches(in: source)
    let text = source as NSString

    #expect(bold.count == 1)
    #expect(text.substring(with: bold[0].range) == "bold")
    #expect(italic.count == 1)
    #expect(text.substring(with: italic[0].range) == "italic")
    #expect(links.count == 1)
    #expect(text.substring(with: links[0].range) == "Tessera")
    #expect(links[0].linkDestination == "https://example.com/path")
    #expect(links[0].delimiterRanges.map { text.substring(with: $0) } == ["[", "](https://example.com/path)"])
}

@Test func ignoresImageSyntaxWhenFindingInlineLinks() {
    let links = MarkdownInlineLinkParser.links(in: "![image](image.png) and [link](page.md)")
    #expect(links.count == 1)
    #expect(links[0].destination == "page.md")
}
