import Foundation

/// A source range and semantic style emitted by a Markdown inline decoration.
public struct MarkdownInlineDecorationMatch: Equatable, Sendable {
    public let range: NSRange
    public let delimiterRanges: [NSRange]
    public let isBold: Bool
    public let isItalic: Bool
    public let linkDestination: String?

    public init(
        range: NSRange,
        delimiterRanges: [NSRange],
        isBold: Bool = false,
        isItalic: Bool = false,
        linkDestination: String? = nil
    ) {
        self.range = range
        self.delimiterRanges = delimiterRanges
        self.isBold = isBold
        self.isItalic = isItalic
        self.linkDestination = linkDestination
    }
}

/// Finds one kind of inline Markdown styling while leaving its source text untouched.
public protocol MarkdownInlineDecoration: Sendable {
    func matches(in source: String) -> [MarkdownInlineDecorationMatch]
}
