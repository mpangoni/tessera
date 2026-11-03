import Foundation

/// Finds inline Markdown links so renderers can style the visible label separately from its URL.
public struct MarkdownLinkDecoration: MarkdownInlineDecoration {
    public init() {}

    public func matches(in source: String) -> [MarkdownInlineDecorationMatch] {
        MarkdownInlineLinkParser.links(in: source).map {
            MarkdownInlineDecorationMatch(
                range: $0.labelRange,
                delimiterRanges: $0.delimiterRanges,
                linkDestination: $0.destination
            )
        }
    }
}
