import AppKit
import TesseraCore

/// Refines how an AST element's projected text receives inline or paragraph attributes.
protocol ElementTextFormat {
    func format(_ text: NSAttributedString, for element: ElementNode) -> NSAttributedString
}

/// Second-stage renderers use projected node ranges for layout decorations such as fills and borders.
protocol ElementTextDecoration {
    func apply(to textView: NSTextView, element: ElementNode, range: NSRange)
}

/// Visits the AST and returns an attributed string for each element while tracking output ranges.
struct TesseraTextProjection: ElementNodeVisitor {
    typealias Result = NSAttributedString

    let artifact: ContentArtifact
    let formats: [any ElementTextFormat]

    private(set) var nodeRanges: [UInt64: NSRange] = [:]
    private var outputOffset = 0

    struct RenderResult {
        let attributedString: NSAttributedString
        let nodeRanges: [UInt64: NSRange]
    }

    init(
        artifact: ContentArtifact,
        formats: [any ElementTextFormat] = [
            LabelColorTextFormat(),
            HeadingTextFormat(),
            CodeTextFormat(),
            StrongTextFormat(),
            EmphasisTextFormat(),
            StrikethroughTextFormat(),
            LinkTextFormat()
        ]
    ) {
        self.artifact = artifact
        self.formats = formats
    }

    /// Runs one complete AST traversal and returns styled text plus ranges for the later decoration pass.
    mutating func project(_ root: ElementNode) -> RenderResult {
        let text = root.accept(&self)
        return RenderResult(attributedString: text, nodeRanges: nodeRanges)
    }

    /// Wraps the visitor dispatch so every node records its range in the projected output.
    mutating func visit(_ node: ElementNode) -> NSAttributedString {
        let start = outputOffset
        let text = applyFormats(to: dispatch(node), for: node)
        let range = NSRange(location: start, length: text.length)

        // Leaf visitors do not advance the cursor while visiting children, so account for their output here.
        outputOffset = max(outputOffset, NSMaxRange(range))
        nodeRanges[node.id] = range
        return text
    }

    mutating func defaultVisit(_ node: ElementNode) -> NSAttributedString {
        switch node.kind {
        case .document, .container, .quote:
            return visitChildren(node.children, separator: "\n\n")
        case .list:
            return visitChildren(node.children, separator: "\n")
        case .text:
            return NSAttributedString(string: artifact.sourceText(for: node) ?? "")
        case .softBreak, .lineBreak:
            return NSAttributedString(string: "\n")
        case .divider:
            return NSAttributedString(string: "")
        default:
            return visitChildren(node.children)
        }
    }

    /// Projects code first, then appends its optional language label as a footer line.
    mutating func visitCodeBlock(_ node: ElementNode) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        let body = visitChildren(node.children)
        result.append(CodeBlockBodyTextFormat().format(body, for: node))

        if case let .codeBlock(language) = node.kind, let language, !language.isEmpty {
            if body.length > 0, !body.string.hasSuffix("\n") {
                result.append(NSAttributedString(string: "\n"))
                outputOffset += 1
            }

            let label = CodeBlockLanguageTextFormat().format(NSAttributedString(string: ""), for: node)
            result.append(label)
            outputOffset += label.length
        }
        return result
    }

    /// Visits children in order and accounts for inserted separators in output coordinates.
    private mutating func visitChildren(_ children: [ElementNode], separator: String = "") -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")

        // Add block spacing in the parent document so it stays outside shaded code surfaces.
        if separator == "\n\n", let first = children.first, isCodeBlock(first) {
            result.append(NSAttributedString(string: "\n"))
            outputOffset += 1
        }

        for (index, child) in children.enumerated() {
            if index > 0, !separator.isEmpty {
                let previousIsCode = isCodeBlock(children[index - 1])
                let currentIsCode = isCodeBlock(child)
                let blockSeparator = separator == "\n\n" && (previousIsCode || currentIsCode)
                    ? separator + "\n"
                    : separator
                result.append(NSAttributedString(string: blockSeparator))
                outputOffset += (blockSeparator as NSString).length
            }
            result.append(visit(child))
        }

        if separator == "\n\n", let last = children.last, isCodeBlock(last) {
            result.append(NSAttributedString(string: "\n"))
            outputOffset += 1
        }
        return result
    }

    private func isCodeBlock(_ node: ElementNode) -> Bool {
        if case .codeBlock = node.kind { return true }
        return false
    }

    /// Applies each registered text-format refinement without coupling the visitor to specific styles.
    private func applyFormats(to text: NSAttributedString, for node: ElementNode) -> NSAttributedString {
        formats.reduce(text) { current, format in format.format(current, for: node) }
    }
}

/// Uses AppKit's dynamic semantic label color so text follows light and dark appearances.
private struct LabelColorTextFormat: ElementTextFormat {
    func format(_ text: NSAttributedString, for element: ElementNode) -> NSAttributedString {
        guard text.length > 0 else { return text }
        let colored = NSMutableAttributedString(attributedString: text)
        let fullRange = NSRange(location: 0, length: colored.length)
        colored.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        if case let .codeBlock(language) = element.kind, let language, !language.isEmpty {
            let labelLength = min((language as NSString).length, colored.length)
            if labelLength > 0 {
                colored.addAttribute(
                    .foregroundColor,
                    value: NSColor.secondaryLabelColor,
                    range: NSRange(location: 0, length: labelLength)
                )
            }
        }
        return colored
    }
}

/// Applies a typographic hierarchy to heading text without changing its characters or ranges.
private struct HeadingTextFormat: ElementTextFormat {
    func format(_ text: NSAttributedString, for element: ElementNode) -> NSAttributedString {
        guard case let .heading(level) = element.kind, text.length > 0 else { return text }

        let sizes: [CGFloat] = [28, 24, 20, 18, 16, 14]
        let index = min(max(level, 1), sizes.count) - 1
        let weight: NSFont.Weight = level <= 4 ? .bold : .semibold
        let headingFont = NSFont.systemFont(ofSize: sizes[index], weight: weight)

        // Reapply the heading scale while preserving inline italic/bold traits on child runs.
        return replacingFonts(in: text) { oldFont in
            let traits = NSFontManager.shared.traits(of: oldFont)
            var font = headingFont
            if traits.contains(.italicFontMask) {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }
            if traits.contains(.boldFontMask), level > 4 {
                font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
            }
            return font
        }
    }
}

/// Gives inline code a monospaced system font; fenced code is formatted as a separate block.
private struct CodeTextFormat: ElementTextFormat {
    func format(_ text: NSAttributedString, for element: ElementNode) -> NSAttributedString {
        switch element.kind {
        case .inlineCode:
            guard text.length > 0 else { return text }
            return replacingFonts(in: text) { oldFont in
                let traits = NSFontManager.shared.traits(of: oldFont)
                let weight: NSFont.Weight = traits.contains(.boldFontMask) ? .bold : .regular
                var codeFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: weight)
                if traits.contains(.italicFontMask) {
                    codeFont = NSFontManager.shared.convert(codeFont, toHaveTrait: .italicFontMask)
                }
                return codeFont
            }
        default:
            return text
        }
    }
}

/// Adds the fence language on a small, secondary-colored footer line.
private struct CodeBlockLanguageTextFormat: ElementTextFormat {
    func format(_ text: NSAttributedString, for element: ElementNode) -> NSAttributedString {
        guard case let .codeBlock(language) = element.kind,
              let language,
              !language.isEmpty else { return text }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right
        paragraphStyle.tailIndent = -10
        return NSAttributedString(
            string: language,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }
}

/// Applies monospaced styling and indentation to a code block's body, not its language label.
private struct CodeBlockBodyTextFormat: ElementTextFormat {
    func format(_ text: NSAttributedString, for element: ElementNode) -> NSAttributedString {
        guard case .codeBlock = element.kind, text.length > 0 else { return text }

        let formatted = NSMutableAttributedString(attributedString: text)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = 22
        paragraphStyle.headIndent = 22
        formatted.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: formatted.length)
        )

        return replacingFonts(in: formatted) { oldFont in
            let traits = NSFontManager.shared.traits(of: oldFont)
            let weight: NSFont.Weight = traits.contains(.boldFontMask) ? .bold : .regular
            var codeFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: weight)
            if traits.contains(.italicFontMask) {
                codeFont = NSFontManager.shared.convert(codeFont, toHaveTrait: .italicFontMask)
            }
            return codeFont
        }
    }
}

/// Converts each font run independently so nested strong and emphasis nodes compose correctly.
private struct StrongTextFormat: ElementTextFormat {
    func format(_ text: NSAttributedString, for element: ElementNode) -> NSAttributedString {
        guard case .strong = element.kind, text.length > 0 else { return text }
        return replacingFonts(in: text) { NSFontManager.shared.convert($0, toHaveTrait: .boldFontMask) }
    }
}

private struct EmphasisTextFormat: ElementTextFormat {
    func format(_ text: NSAttributedString, for element: ElementNode) -> NSAttributedString {
        guard case .emphasis = element.kind, text.length > 0 else { return text }
        return replacingFonts(in: text) { NSFontManager.shared.convert($0, toHaveTrait: .italicFontMask) }
    }
}

private struct StrikethroughTextFormat: ElementTextFormat {
    func format(_ text: NSAttributedString, for element: ElementNode) -> NSAttributedString {
        guard case .strikethrough = element.kind, text.length > 0 else { return text }
        let formatted = NSMutableAttributedString(attributedString: text)
        formatted.addAttribute(
            .strikethroughStyle,
            value: NSUnderlineStyle.single.rawValue,
            range: NSRange(location: 0, length: formatted.length)
        )
        return formatted
    }
}

private struct LinkTextFormat: ElementTextFormat {
    func format(_ text: NSAttributedString, for element: ElementNode) -> NSAttributedString {
        guard case let .link(destination) = element.kind,
              let destination,
              text.length > 0 else { return text }

        let formatted = NSMutableAttributedString(attributedString: text)
        let range = NSRange(location: 0, length: formatted.length)
        formatted.addAttribute(.link, value: destination, range: range)
        formatted.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
        formatted.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        return formatted
    }
}

/// Applies a font transformation to each existing font run without flattening nested formatting.
private func replacingFonts(
    in text: NSAttributedString,
    transform: (NSFont) -> NSFont
) -> NSAttributedString {
    let formatted = NSMutableAttributedString(attributedString: text)
    let fallbackFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    var location = 0

    while location < text.length {
        var effectiveRange = NSRange(location: 0, length: 0)
        let oldFont = text.attribute(.font, at: location, effectiveRange: &effectiveRange) as? NSFont ?? fallbackFont
        let end = min(NSMaxRange(effectiveRange), text.length)
        guard end > location else { break }
        formatted.addAttribute(.font, value: transform(oldFont), range: NSRange(location: location, length: end - location))
        location = end
    }

    return formatted
}
