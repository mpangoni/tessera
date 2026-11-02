import Foundation

public enum MarkdownCodec {
    private struct Line { var text: String; var ending: String }

    public static func decode(_ data: Data) throws -> BlockDocument {
        guard let source = String(data: data, encoding: .utf8) else { throw TesseraError.invalidUTF8 }
        return decode(source)
    }

    public static func decode(_ source: String) -> BlockDocument {
        let eol = source.contains("\r\n") ? "\r\n" : "\n"
        var lines: [Line] = []
        var offset = source.startIndex
        while offset < source.endIndex {
            if let end = source[offset...].firstIndex(of: "\n") {
                let before = source[offset..<end]
                lines.append(Line(text: before.last == "\r" ? String(before.dropLast()) : String(before), ending: before.last == "\r" ? "\r\n" : "\n"))
                offset = source.index(after: end)
            } else { lines.append(Line(text: String(source[offset...]), ending: "")); offset = source.endIndex }
        }
        if source.isEmpty { return BlockDocument(originalSource: "", lineEnding: eol) }
        var blocks: [TesseraBlock] = [], separator = "", trailing = "", i = 0
        while i < lines.count {
            if lines[i].text.trimmingCharacters(in: .whitespaces).isEmpty {
                let blank = lines[i].text + lines[i].ending
                if i == lines.count - 1 { trailing += blank } else { separator += blank }
                i += 1; continue
            }
            let start = i
            if let fence = fenceMarker(lines[i].text) {
                i += 1
                while i < lines.count {
                    let t = lines[i].text.trimmingCharacters(in: .whitespaces)
                    i += 1
                    if t.hasPrefix(fence.marker) { break }
                }
            } else if isListLine(lines[i].text) {
                i += 1
                while i < lines.count && !lines[i].text.trimmingCharacters(in: .whitespaces).isEmpty && lines[i].text.first?.isWhitespace == true { i += 1 }
            } else {
                i += 1
                while i < lines.count && !lines[i].text.trimmingCharacters(in: .whitespaces).isEmpty && fenceMarker(lines[i].text) == nil && !isStandaloneBlock(lines[i].text) { i += 1 }
            }
            let chosen = Array(lines[start..<i])
            let raw = chosen.map { $0.text + $0.ending }.joined()
            blocks.append(parseBlock(chosen.map(\.text).joined(separator: "\n"), raw: raw, separator: separator))
            separator = ""
        }
        return BlockDocument(blocks: blocks, originalSource: source, lineEnding: eol, trailingSource: trailing)
    }

    public static func encode(_ document: BlockDocument) -> String {
        if !document.hasBeenEdited, let source = document.originalSource { return source }
        return document.blocks.map { block in
            block.precedingSeparator + (block.isDirty || block.source == nil ? serialize(block, eol: document.lineEnding) : block.source!)
        }.joined() + document.trailingSource
    }

    private static func parseBlock(_ text: String, raw: String, separator: String) -> TesseraBlock {
        let first = text.components(separatedBy: "\n")[0]
        if let fence = fenceMarker(first) {
            let lines = text.components(separatedBy: "\n")
            let body = lines.count > 1 ? lines.dropFirst().dropLast().joined(separator: "\n") : ""
            return TesseraBlock(kind: .fencedCode(language: fence.info.isEmpty ? nil : fence.info), content: body, source: raw, precedingSeparator: separator)
        }
        if let range = text.range(of: #"^(#{1,6})\s+(.*)$"#, options: .regularExpression) {
            let whole = String(text[range]); let level = whole.prefix(while: { $0 == "#" }).count
            return TesseraBlock(kind: .heading(level: level), content: String(whole.dropFirst(level)).trimmingCharacters(in: .whitespaces), source: raw, precedingSeparator: separator)
        }
        if text.range(of: #"^(?:---+|\*\*\*+|___+)$"#, options: .regularExpression) != nil { return TesseraBlock(kind: .horizontalRule, content: text, source: raw, precedingSeparator: separator) }
        if ["- ", "* ", "+ "].contains(where: { text.hasPrefix($0) }) {
            if text.contains("\n") || text.range(of: #"\n\s{2,}[-*+]\s+"#, options: .regularExpression) != nil { return TesseraBlock(kind: .rawMarkdown, content: text, source: raw, precedingSeparator: separator) }
            return TesseraBlock(kind: .unorderedListItem, content: String(text.dropFirst(2)), source: raw, precedingSeparator: separator)
        }
        if let first = text.firstIndex(where: { $0 == "." || $0 == ")" }), first > text.startIndex,
           text[text.startIndex..<first].allSatisfy(\.isNumber), text.index(after: first) < text.endIndex, text[text.index(after: first)] == " " {
            let n = Int(text[..<first]) ?? 1
            return TesseraBlock(kind: .orderedListItem(number: n), content: String(text[text.index(first, offsetBy: 2)...]), source: raw, precedingSeparator: separator)
        }
        if text.hasPrefix("> ") { return TesseraBlock(kind: .blockquote, content: String(text.dropFirst(2)), source: raw, precedingSeparator: separator) }
        if (text.contains("|") && text.contains("\n")) || (text.contains("<") && text.contains(">")) {
            return TesseraBlock(kind: .rawMarkdown, content: text, source: raw, precedingSeparator: separator)
        }
        return TesseraBlock(kind: .paragraph, content: text.replacingOccurrences(of: "\n", with: " "), source: raw, precedingSeparator: separator)
    }

    private static func isListLine(_ line: String) -> Bool {
        line.range(of: #"^\s*(?:[-*+]|\d+[.)])\s+"#, options: .regularExpression) != nil
    }

    private static func isStandaloneBlock(_ line: String) -> Bool {
        isListLine(line) || line.range(of: #"^\s{0,3}#{1,6}\s+"#, options: .regularExpression) != nil ||
        line.range(of: #"^\s{0,3}>\s?"#, options: .regularExpression) != nil ||
        line.range(of: #"^(?:---+|\*\*\*+|___+)$"#, options: .regularExpression) != nil
    }

    private static func fenceMarker(_ line: String) -> (marker: String, info: String)? {
        guard let range = line.range(of: #"^\s{0,3}(`{3,}|~{3,})(.*)$"#, options: .regularExpression) else { return nil }
        let match = String(line[range]).trimmingCharacters(in: .whitespaces)
        let marker = String(match.prefix(while: { $0 == "`" || $0 == "~" }))
        return (marker, String(match.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces))
    }

    private static func serialize(_ block: TesseraBlock, eol: String) -> String {
        switch block.kind {
        case .paragraph: return block.content
        case .heading(let level): return String(repeating: "#", count: min(max(level, 1), 6)) + " " + block.content
        case .unorderedListItem: return "- " + block.content
        case .orderedListItem(let number): return "\(number). " + block.content
        case .blockquote: return "> " + block.content
        case .horizontalRule: return "---"
        case .rawMarkdown: return block.content
        case .fencedCode(let language):
            let longest = block.content.components(separatedBy: "\n").map { $0.prefix(while: { $0 == "`" }).count }.max() ?? 0
            let marker = String(repeating: "`", count: max(3, longest + 1))
            return "\(marker)\(language.map { " " + $0 } ?? "")\(eol)\(block.content)\(eol)\(marker)"
        }
    }
}
