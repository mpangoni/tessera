import Foundation

/// Finds italic text in either asterisk or underscore Markdown syntax.
public struct MarkdownItalicDecoration: MarkdownInlineDecoration {
    public init() {}

    public func matches(in source: String) -> [MarkdownInlineDecorationMatch] {
        MarkdownInlineEmphasisParser.ranges(in: source)
            .filter(\.isItalic)
            .map {
                MarkdownInlineDecorationMatch(
                    range: $0.range,
                    delimiterRanges: $0.delimiterRanges,
                    isItalic: true
                )
            }
    }
}
