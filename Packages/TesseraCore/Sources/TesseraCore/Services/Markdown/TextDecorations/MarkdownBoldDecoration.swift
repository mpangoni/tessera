import Foundation

/// Finds bold text in either asterisk or underscore Markdown syntax.
public struct MarkdownBoldDecoration: MarkdownInlineDecoration {
    public init() {}

    public func matches(in source: String) -> [MarkdownInlineDecorationMatch] {
        MarkdownInlineEmphasisParser.ranges(in: source)
            .filter(\.isBold)
            .map {
                MarkdownInlineDecorationMatch(
                    range: $0.range,
                    delimiterRanges: $0.delimiterRanges,
                    isBold: true
                )
            }
    }
}
