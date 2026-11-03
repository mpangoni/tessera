import Foundation

/// A source-preserving edit that a native text view can apply as one undoable replacement.
public struct MarkdownSourceEdit: Equatable, Sendable {
    public let range: NSRange
    public let replacement: String
    public let caretOffset: Int

    public init(range: NSRange, replacement: String, caretOffset: Int) {
        self.range = range
        self.replacement = replacement
        self.caretOffset = caretOffset
    }
}

/// Performs top-level block operations against AST ranges without reserializing untouched Markdown.
public enum MarkdownSourceCommands {
    /// Replaces the current selection with a Markdown block boundary at its AST location.
    public static func splitBlock(replacing selection: NSRange, in source: String) -> MarkdownSourceEdit? {
        let nodes = MarkdownASTParser.parse(source).root.children
        guard let node = nodes.first(where: { node in
            guard let range = node.sourceRange else { return false }
            return NSIntersectionRange(range, selection).length > 0 ||
                (selection.length == 0 && selection.location >= range.location && selection.location <= NSMaxRange(range))
        }), let blockRange = node.sourceRange,
              selection.location >= blockRange.location,
              NSMaxRange(selection) <= NSMaxRange(blockRange) else { return nil }

        let sourceText = source as NSString
        let marker = splitMarker(for: node, source: sourceText, blockRange: blockRange, caret: selection.location)
        guard let marker else { return nil }
        let caretOffset = selection.location + marker.utf16.count
        return MarkdownSourceEdit(range: selection, replacement: marker, caretOffset: caretOffset)
    }

    /// Merges the block at its beginning into the previous source block.
    public static func mergePreviousBlock(at sourceOffset: Int, in source: String) -> MarkdownSourceEdit? {
        let nodes = MarkdownASTParser.parse(source).root.children
        let ranges = nodes.compactMap(\.sourceRange)
        guard let index = ranges.indices.first(where: { index in
            sourceOffset == ranges[index].location + leadingSyntaxLength(for: nodes[index], source: source as NSString, range: ranges[index])
        }), index > 0 else { return nil }
        let current = ranges[index]
        let previous = ranges[index - 1]
        let sourceText = source as NSString
        let syntaxLength = leadingSyntaxLength(for: nodes[index], source: sourceText, range: current)
        let replacementRange = NSRange(location: NSMaxRange(previous), length: NSMaxRange(current) - NSMaxRange(previous))
        let currentContentStart = min(NSMaxRange(current), current.location + syntaxLength)
        let content = sourceText.substring(with: NSRange(location: currentContentStart, length: NSMaxRange(current) - currentContentStart))
        let joinOffset = previous.location + previous.length
        return MarkdownSourceEdit(range: replacementRange, replacement: content, caretOffset: joinOffset)
    }

    /// Removes the top-level AST block containing the source offset.
    public static func deleteBlock(at sourceOffset: Int, in source: String) -> MarkdownSourceEdit? {
        let ranges = topLevelRanges(in: source)
        guard let index = ranges.firstIndex(where: { NSLocationInRange(sourceOffset, $0) }) else { return nil }
        let current = ranges[index]
        let range: NSRange
        if ranges.count == 1 {
            range = current
        } else if index + 1 < ranges.count {
            range = NSRange(location: current.location, length: ranges[index + 1].location - current.location)
        } else {
            let previous = ranges[index - 1]
            range = NSRange(location: NSMaxRange(previous), length: NSMaxRange(current) - NSMaxRange(previous))
        }
        return MarkdownSourceEdit(range: range, replacement: "", caretOffset: range.location)
    }

    /// Moves the top-level AST block containing the source offset by one neighboring block.
    public static func moveBlock(at sourceOffset: Int, by distance: Int, caretOffset: Int, in source: String) -> MarkdownSourceEdit? {
        guard distance == -1 || distance == 1 else { return nil }
        let ranges = topLevelRanges(in: source)
        guard let index = ranges.firstIndex(where: { NSLocationInRange(sourceOffset, $0) }) else { return nil }
        let neighborIndex = index + distance
        guard ranges.indices.contains(neighborIndex) else { return nil }

        let current = ranges[index]
        let neighbor = ranges[neighborIndex]
        let sourceText = source as NSString
        let combined = NSRange(
            location: min(current.location, neighbor.location),
            length: max(NSMaxRange(current), NSMaxRange(neighbor)) - min(current.location, neighbor.location)
        )
        let currentText = sourceText.substring(with: current)
        let neighborText = sourceText.substring(with: neighbor)
        let replacement: String
        let movedCaret: Int

        if distance < 0 {
            let gap = sourceText.substring(with: NSRange(location: NSMaxRange(neighbor), length: current.location - NSMaxRange(neighbor)))
            replacement = currentText + gap + neighborText
            movedCaret = caretOffset >= current.location
                ? neighbor.location + min(caretOffset - current.location, current.length)
                : neighbor.location + current.length + gap.utf16.count + max(0, caretOffset - neighbor.location)
        } else {
            let gap = sourceText.substring(with: NSRange(location: NSMaxRange(current), length: neighbor.location - NSMaxRange(current)))
            replacement = neighborText + gap + currentText
            movedCaret = caretOffset >= current.location
                ? neighbor.location + neighbor.length + gap.utf16.count + min(caretOffset - current.location, current.length)
                : neighbor.location + max(0, caretOffset - neighbor.location)
        }

        return MarkdownSourceEdit(range: combined, replacement: replacement, caretOffset: movedCaret)
    }

    /// Reorders a block to the position of another top-level block, retaining existing separators.
    public static func moveBlock(at sourceOffset: Int, to targetOffset: Int, caretOffset: Int, in source: String) -> MarkdownSourceEdit? {
        let ranges = topLevelRanges(in: source)
        guard let sourceIndex = ranges.firstIndex(where: { NSLocationInRange(sourceOffset, $0) }),
              let targetIndex = ranges.firstIndex(where: { NSLocationInRange(targetOffset, $0) }),
              sourceIndex != targetIndex else { return nil }

        let lowerIndex = min(sourceIndex, targetIndex)
        let upperIndex = max(sourceIndex, targetIndex)
        let combined = NSRange(
            location: ranges[lowerIndex].location,
            length: NSMaxRange(ranges[upperIndex]) - ranges[lowerIndex].location
        )
        let text = source as NSString
        let blockRanges = Array(ranges[lowerIndex...upperIndex])
        var blocks = blockRanges.map { text.substring(with: $0) }
        let gaps = zip(blockRanges, blockRanges.dropFirst()).map { current, next in
            text.substring(with: NSRange(location: NSMaxRange(current), length: next.location - NSMaxRange(current)))
        }
        let localSource = sourceIndex - lowerIndex
        let localTarget = targetIndex - lowerIndex
        let moving = blocks.remove(at: localSource)
        blocks.insert(moving, at: localTarget)
        let replacement = blocks.enumerated().reduce(into: "") { result, element in
            if element.offset > 0 { result += gaps[element.offset - 1] }
            result += element.element
        }

        let caretRelativeToBlock = caretOffset - ranges[sourceIndex].location
        var movedCaret = caretOffset
        if (0..<ranges[sourceIndex].length).contains(caretRelativeToBlock) {
            let newStart = combined.location + blocks.prefix(localTarget).reduce(0) { $0 + $1.utf16.count } +
                gaps.prefix(localTarget).reduce(0) { $0 + $1.utf16.count }
            movedCaret = newStart + min(caretRelativeToBlock, ranges[sourceIndex].length)
        }
        return MarkdownSourceEdit(range: combined, replacement: replacement, caretOffset: movedCaret)
    }

    private static func topLevelRanges(in source: String) -> [NSRange] {
        MarkdownASTParser.parse(source).root.children.compactMap(\.sourceRange)
    }

    private static func splitMarker(for node: MarkdownASTNode, source: NSString, blockRange: NSRange, caret: Int) -> String? {
        switch node.kind {
        case .paragraph:
            return "\n\n"
        case .heading:
            return "\n\n"
        case .blockQuote:
            return "\n> "
        case .unorderedList, .orderedList:
            let lineStart = source.range(of: "\n", options: .backwards, range: NSRange(location: blockRange.location, length: max(0, caret - blockRange.location))).location
            let start = lineStart == NSNotFound ? blockRange.location : lineStart + 1
            let line = source.substring(with: NSRange(location: start, length: max(0, caret - start)))
            if let match = firstMatch(#"^\s*(?:[-*+]\s+|\d+[.)]\s+)"#, in: line) {
                if case .orderedList = node.kind,
                   let numeral = firstMatch(#"\d+"#, in: match),
                   let number = Int(numeral) {
                    let nextMarker = match.replacingOccurrences(of: numeral, with: String(number + 1), options: [], range: match.range(of: numeral))
                    return "\n" + nextMarker
                }
                return "\n" + match
            }
            return "\n- "
        default:
            return nil
        }
    }

    private static func leadingSyntaxLength(for node: MarkdownASTNode, source: NSString, range: NSRange) -> Int {
        let firstLineEnd = source.range(of: "\n", options: [], range: NSRange(location: range.location, length: source.length - range.location)).location
        let end = firstLineEnd == NSNotFound ? NSMaxRange(range) : min(firstLineEnd, NSMaxRange(range))
        let line = source.substring(with: NSRange(location: range.location, length: max(0, end - range.location)))
        let pattern: String
        switch node.kind {
        case .heading: pattern = #"^\s{0,3}#{1,6}\s+"#
        case .blockQuote: pattern = #"^\s{0,3}> ?"#
        case .unorderedList: pattern = #"^\s*(?:[-*+]\s+)"#
        case .orderedList: pattern = #"^\s*\d+[.)]\s+"#
        default: return 0
        }
        return firstMatch(pattern, in: line).map { ($0 as NSString).length } ?? 0
    }

    private static func firstMatch(_ pattern: String, in string: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let text = string as NSString
        guard let match = expression.firstMatch(in: string, range: NSRange(location: 0, length: text.length)) else { return nil }
        return text.substring(with: match.range)
    }
}
