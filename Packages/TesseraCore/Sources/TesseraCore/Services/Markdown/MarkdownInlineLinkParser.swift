import Foundation

/// A link label's source range and the Markdown syntax that surrounds the label.
public struct MarkdownInlineLink: Equatable, Sendable {
    public let labelRange: NSRange
    public let delimiterRanges: [NSRange]
    public let destination: String

    public init(labelRange: NSRange, delimiterRanges: [NSRange], destination: String) {
        self.labelRange = labelRange
        self.delimiterRanges = delimiterRanges
        self.destination = destination
    }
}

/// Parses basic inline links and returns ranges suitable for rich display without rewriting source.
public enum MarkdownInlineLinkParser {
    private static let expression = try! NSRegularExpression(
        pattern: #"(?<!!)\[([^\]\n]+)\]\((<[^>\n]+>|[^)\s]+)(?:\s+(?:"[^"]*"|'[^']*'|\([^)]*\)))?\)"#
    )

    public static func links(in source: String) -> [MarkdownInlineLink] {
        let text = source as NSString
        let fullRange = NSRange(location: 0, length: text.length)
        return expression.matches(in: source, range: fullRange).compactMap { match in
            let label = match.range(at: 1)
            let destinationRange = match.range(at: 2)
            guard label.location != NSNotFound, label.length > 0, destinationRange.location != NSNotFound,
                  !isEscaped(match.range.location, in: text) else { return nil }

            let rawDestination = text.substring(with: destinationRange)
            let destination = rawDestination.hasPrefix("<") && rawDestination.hasSuffix(">")
                ? String(rawDestination.dropFirst().dropLast())
                : rawDestination
            let prefixLength = label.location - match.range.location
            let suffixStart = NSMaxRange(label)
            let suffixLength = NSMaxRange(match.range) - suffixStart
            return MarkdownInlineLink(
                labelRange: label,
                delimiterRanges: [
                    NSRange(location: match.range.location, length: prefixLength),
                    NSRange(location: suffixStart, length: suffixLength)
                ],
                destination: destination
            )
        }
    }

    private static func isEscaped(_ location: Int, in text: NSString) -> Bool {
        var cursor = location - 1
        var backslashCount = 0
        while cursor >= 0 && text.character(at: cursor) == 92 {
            backslashCount += 1
            cursor -= 1
        }
        return !backslashCount.isMultiple(of: 2)
    }
}
