import Foundation

/// A source range whose text should appear bold, italic, or both in an editor.
public struct MarkdownInlineEmphasis: Equatable, Sendable {
    /// UTF-16 range of the emphasized text, excluding its Markdown delimiters.
    public let range: NSRange
    /// UTF-16 ranges of the opening and closing Markdown delimiters to hide in the block view.
    public let delimiterRanges: [NSRange]
    public let isBold: Bool
    public let isItalic: Bool

    public init(range: NSRange, delimiterRanges: [NSRange], isBold: Bool, isItalic: Bool) {
        self.range = range
        self.delimiterRanges = delimiterRanges
        self.isBold = isBold
        self.isItalic = isItalic
    }
}

/// Finds basic Markdown emphasis without rewriting or removing the original source markers.
public enum MarkdownInlineEmphasisParser {
    private struct Pattern {
        let expression: NSRegularExpression
        let isBold: Bool
        let isItalic: Bool
    }

    private static let patterns: [Pattern] = [
        Pattern(expression: try! NSRegularExpression(pattern: #"(?<!\*)(\*\*\*)(?!\*)(?=\S)(.+?\S)(?<!\*)\*\*\*(?!\*)"#), isBold: true, isItalic: true),
        Pattern(expression: try! NSRegularExpression(pattern: #"(?<!_)(___)(?!_)(?=\S)(.+?\S)(?<!_)___(?!_)"#), isBold: true, isItalic: true),
        Pattern(expression: try! NSRegularExpression(pattern: #"(?<!\*)(\*\*)(?!\*)(?=\S)(.+?\S)(?<!\*)\*\*(?!\*)"#), isBold: true, isItalic: false),
        Pattern(expression: try! NSRegularExpression(pattern: #"(?<!_)(__)(?!_)(?=\S)(.+?\S)(?<!_)__(?!_)"#), isBold: true, isItalic: false),
        Pattern(expression: try! NSRegularExpression(pattern: #"(?<!\*)(\*)(?!\*)(?=\S)([^*\n]+?\S)(?<!\*)\*(?!\*)"#), isBold: false, isItalic: true),
        Pattern(expression: try! NSRegularExpression(pattern: #"(?<![\w_])(_)(?!_)(?=\S)([^_\n]+?\S)(?<!_)_(?![\w_])"#), isBold: false, isItalic: true)
    ]

    /// Returns UTF-16 ranges for simple asterisk and underscore emphasis syntax.
    ///
    /// Escaped markers, unclosed delimiters, and emphasis inside code spans are left unstyled.
    public static func ranges(in source: String) -> [MarkdownInlineEmphasis] {
        let text = source as NSString
        let fullRange = NSRange(location: 0, length: text.length)
        let codeRanges = inlineCodeRanges(in: text)
        var result: [MarkdownInlineEmphasis] = []

        for pattern in patterns {
            for match in pattern.expression.matches(in: source, range: fullRange) {
                let opening = match.range(at: 1)
                let content = match.range(at: 2)
                let closing = NSRange(location: NSMaxRange(match.range) - opening.length, length: opening.length)
                guard content.location != NSNotFound, content.length > 0,
                      !isEscaped(opening.location, in: text), !isEscaped(closing.location, in: text),
                      !codeRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { continue }
                result.append(MarkdownInlineEmphasis(
                    range: content,
                    delimiterRanges: [opening, closing],
                    isBold: pattern.isBold,
                    isItalic: pattern.isItalic
                ))
            }
        }

        return result.sorted {
            if $0.range.location == $1.range.location { return $0.range.length > $1.range.length }
            return $0.range.location < $1.range.location
        }
    }

    /// Finds matched backtick spans so asterisks inside code remain literal characters.
    private static func inlineCodeRanges(in text: NSString) -> [NSRange] {
        var ranges: [NSRange] = []
        var cursor = 0

        while cursor < text.length {
            guard text.character(at: cursor) == 96 else {
                cursor += 1
                continue
            }

            let openingStart = cursor
            while cursor < text.length && text.character(at: cursor) == 96 { cursor += 1 }
            let delimiterLength = cursor - openingStart
            var candidate = cursor
            var closingRange: NSRange?

            while candidate < text.length {
                guard text.character(at: candidate) == 96 else {
                    candidate += 1
                    continue
                }
                let runStart = candidate
                while candidate < text.length && text.character(at: candidate) == 96 { candidate += 1 }
                if candidate - runStart == delimiterLength {
                    closingRange = NSRange(location: runStart, length: delimiterLength)
                    break
                }
            }

            if let closingRange {
                ranges.append(NSRange(location: openingStart, length: NSMaxRange(closingRange) - openingStart))
                cursor = NSMaxRange(closingRange)
            }
        }

        return ranges
    }

    /// A delimiter is escaped only when preceded by an odd run of backslashes.
    private static func isEscaped(_ location: Int, in text: NSString) -> Bool {
        var cursor = location - 1
        var backslashCount = 0
        while cursor >= 0 && text.character(at: cursor) == 92 {
            backslashCount += 1
            cursor -= 1
        }
        return backslashCount.isMultiple(of: 2) == false
    }
}
