import AppKit
import TesseraCore

/// A Markdown decoration can style source ranges, draw block geometry, or provide a TextKit 2 fragment.
@MainActor
protocol MarkdownTextDecorationRenderer {
    func apply(source: NSString, nodes: [MarkdownASTNode], to storage: NSTextStorage)
    func layoutFragment(for element: NSTextElement, at sourceOffset: Int, nodes: [MarkdownASTNode]) -> NSTextLayoutFragment?
    func draw(in textView: TesseraTextKit2View, nodes: [MarkdownASTNode])
}

extension MarkdownTextDecorationRenderer {
    func apply(source: NSString, nodes: [MarkdownASTNode], to storage: NSTextStorage) {}
    func layoutFragment(for element: NSTextElement, at sourceOffset: Int, nodes: [MarkdownASTNode]) -> NSTextLayoutFragment? { nil }
    func draw(in textView: TesseraTextKit2View, nodes: [MarkdownASTNode]) {}
}

/// Runs the registered renderers against the same source-preserving Markdown AST.
@MainActor
enum MarkdownTextDecorationPipeline {

    private static var renderers: [any MarkdownTextDecorationRenderer] = [
        BlockTextDecorationRenderer(),
        CodeTextDecorationRenderer(),
        LinkTextDecorationRenderer(),
        EmphasisTextDecorationRenderer(),
        ThematicBreakTextDecorationRenderer(),
        BlockQuoteTextDecorationRenderer()
    ]

    /// Adds a renderer for a new Markdown construct such as equations, diagrams, or charts.
    static func register(_ renderer: any MarkdownTextDecorationRenderer) {
        renderers.append(renderer)
    }

    /// Resets transient attributes, then lets each renderer decorate only its parsed source ranges.
    static func apply(source: String, ast: MarkdownAST, to textView: TesseraTextKit2View) {
        guard let storage = textView.textStorage else { return }
        let sourceText = source as NSString
        guard sourceText.length > 0 else { return }
        let allNodes = ast.root.flattened
        let fullRange = NSRange(location: 0, length: sourceText.length)
        textView.typingAttributes[.font] = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.typingAttributes[.foregroundColor] = NSColor.labelColor
        storage.beginEditing()
        storage.addAttributes([
            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.labelColor
        ], range: fullRange)
        storage.removeAttribute(.link, range: fullRange)
        storage.removeAttribute(.paragraphStyle, range: fullRange)

        for renderer in renderers {
            renderer.apply(source: sourceText, nodes: allNodes, to: storage)
        }

        storage.endEditing()
    }

    static func layoutFragment(for element: NSTextElement, at sourceOffset: Int, nodes: [MarkdownASTNode]) -> NSTextLayoutFragment? {
        renderers.lazy.compactMap { $0.layoutFragment(for: element, at: sourceOffset, nodes: nodes) }.first
    }

    static func flattenedNodes(in ast: MarkdownAST) -> [MarkdownASTNode] { ast.root.flattened }

    static func draw(in textView: TesseraTextKit2View, nodes: [MarkdownASTNode]) {
        renderers.forEach { $0.draw(in: textView, nodes: nodes) }
    }
}

private extension MarkdownASTNode {
    var flattened: [MarkdownASTNode] { [self] + children.flatMap(\.flattened) }
}

private struct BlockTextDecorationRenderer: MarkdownTextDecorationRenderer {

    func apply(source: NSString, nodes: [MarkdownASTNode], to storage: NSTextStorage) {

        for node in nodes {
            guard let range = node.sourceRange, range.location >= 0, NSMaxRange(range) <= source.length else { continue }
            switch node.kind {

            case .heading(let level):
                let size = max(16, 30 - CGFloat(level * 2))
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: size, weight: .semibold), range: range)
                hideHeadingMarker(in: source, range: range, storage: storage)

            case .listItem:
                hideListMarker(in: source, range: range, storage: storage)

            case .thematicBreak:
                hide(range, storage: storage)

            default:
                break
            }
        }
    }

    private func hideHeadingMarker(in source: NSString, range: NSRange, storage: NSTextStorage) {
        guard let line = lineRanges(in: source, range: range).first else { return }
        let value = source.substring(with: line)
        let markerLength = (value as NSString).length -
            (value.replacingOccurrences(of: #"^\s{0,3}#{1,6}\s+"#, with: "", options: .regularExpression) as NSString).length
        if markerLength > 0 { hide(NSRange(location: line.location, length: markerLength), storage: storage) }
    }


    private func hideListMarker(in source: NSString, range: NSRange, storage: NSTextStorage) {
        guard let line = lineRanges(in: source, range: range).first else { return }
        let value = source.substring(with: line)
        let markerLength = (value as NSString).length -
            (value.replacingOccurrences(of: #"^\s*(?:[-*+]|\d+[.)])\s+"#, with: "", options: .regularExpression) as NSString).length
        if markerLength > 0 { hide(NSRange(location: line.location, length: markerLength), storage: storage) }
    }
}

private struct CodeTextDecorationRenderer: MarkdownTextDecorationRenderer {
    func apply(source: NSString, nodes: [MarkdownASTNode], to storage: NSTextStorage) {
        for node in nodes {
            guard let range = node.sourceRange, range.location >= 0, NSMaxRange(range) <= source.length else { continue }
            switch node.kind {
            case .codeBlock:

                storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular), range: range)
                storage.addAttribute(.backgroundColor, value: NSColor.underPageBackgroundColor, range: range)

                let paragraph = NSMutableParagraphStyle()
                paragraph.firstLineHeadIndent = 12
                paragraph.headIndent = 12
                paragraph.tailIndent = -12
                storage.addAttribute(.paragraphStyle, value: paragraph, range: range)

                hideFences(in: source, range: range, storage: storage)
            case .inlineCode:
                styleInlineCode(in: source, range: range, storage: storage)
            default:
                break
            }
        }
    }

    func layoutFragment(for element: NSTextElement, at sourceOffset: Int, nodes: [MarkdownASTNode]) -> NSTextLayoutFragment? {
        let isCode = nodes.contains { node in
            guard case .codeBlock = node.kind, let range = node.sourceRange else { return false }
            return NSLocationInRange(sourceOffset, range)
        }
        return isCode ? CodeBlockTextLayoutFragment(textElement: element, range: nil) : nil
    }

    private func hideFences(in source: NSString, range: NSRange, storage: NSTextStorage) {
        let lines = lineRanges(in: source, range: range)
        guard lines.count >= 2 else { return }
        let fence = #"^\s{0,3}(?:`{3,}|~{3,}).*$"#
        for line in [lines.first!, lines.last!] where source.substring(with: line).range(of: fence, options: .regularExpression) != nil {
            hide(line, storage: storage)
        }
    }

    private func styleInlineCode(in source: NSString, range: NSRange, storage: NSTextStorage) {
        let value = source.substring(with: range)
        let delimiterLength = value.prefix(while: { $0 == "`" }).count
        guard delimiterLength > 0, value.count >= delimiterLength * 2 else { return }
        let contentRange = NSRange(location: range.location + delimiterLength, length: range.length - delimiterLength * 2)
        if contentRange.length > 0 {
            storage.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular), range: contentRange)
        }
        hide(NSRange(location: range.location, length: delimiterLength), storage: storage)
        hide(NSRange(location: NSMaxRange(range) - delimiterLength, length: delimiterLength), storage: storage)
    }
}

/// Shades each code paragraph in TextKit's scrolling fragment coordinates.
private final class CodeBlockTextLayoutFragment: NSTextLayoutFragment {

    override func draw(at point: CGPoint, in context: CGContext) {
        context.saveGState()
        let surface = blockDecorationSurface(at: point)
        context.setFillColor(NSColor.underPageBackgroundColor.cgColor)
        context.fill(surface)
        context.restoreGState()
        super.draw(at: point, in: context)
    }

}

private struct LinkTextDecorationRenderer: MarkdownTextDecorationRenderer {
    func apply(source: NSString, nodes: [MarkdownASTNode], to storage: NSTextStorage) {
        let codeRanges = nodes.compactMap { node -> NSRange? in
            switch node.kind {
            case .codeBlock, .inlineCode: node.sourceRange
            default: nil
            }
        }
        for link in MarkdownInlineLinkParser.links(in: source as String)
        where !codeRanges.contains(where: { NSIntersectionRange(link.labelRange, $0).length > 0 }) {
            guard link.labelRange.location >= 0, NSMaxRange(link.labelRange) <= source.length else { continue }
            storage.addAttribute(.link, value: link.destination, range: link.labelRange)
            link.delimiterRanges.forEach { hide($0, storage: storage) }
        }
    }
}

private struct EmphasisTextDecorationRenderer: MarkdownTextDecorationRenderer {
    func apply(source: NSString, nodes: [MarkdownASTNode], to storage: NSTextStorage) {
        let codeRanges = nodes.compactMap { node -> NSRange? in
            switch node.kind {
            case .codeBlock, .inlineCode: node.sourceRange
            default: nil
            }
        }
        for match in MarkdownInlineEmphasisParser.ranges(in: source as String)
        where !codeRanges.contains(where: { NSIntersectionRange(match.range, $0).length > 0 }) {
            let markerLength = match.delimiterRanges.first?.length ?? 0
            let start = match.range.location + markerLength
            let contentLength = match.range.length - markerLength * 2
            guard contentLength > 0, start >= 0, start + contentLength <= source.length else { continue }
            let content = NSRange(location: start, length: contentLength)
            let font = storage.attribute(.font, at: start, effectiveRange: nil) as? NSFont
                ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            var decoratedFont = font
            if match.isBold { decoratedFont = NSFontManager.shared.convert(decoratedFont, toHaveTrait: .boldFontMask) }
            if match.isItalic { decoratedFont = NSFontManager.shared.convert(decoratedFont, toHaveTrait: .italicFontMask) }
            storage.addAttribute(.font, value: decoratedFont, range: content)
            match.delimiterRanges.forEach { hide($0, storage: storage) }
        }
    }
}

private struct ThematicBreakTextDecorationRenderer: MarkdownTextDecorationRenderer {
    func draw(in textView: TesseraTextKit2View, nodes: [MarkdownASTNode]) {
        NSColor.separatorColor.setStroke()
        for node in nodes {
            guard case .thematicBreak = node.kind,
                  let range = node.sourceRange,
                  let frame = textView.textFrames(for: range).first else { continue }
            let path = NSBezierPath()
            path.lineWidth = 1
            path.move(to: NSPoint(x: textView.textContainerOrigin.x + 2, y: frame.midY))
            path.line(to: NSPoint(x: textView.bounds.maxX - textView.textContainerOrigin.x - 2, y: frame.midY))
            path.stroke()
        }
    }
}

private struct BlockQuoteTextDecorationRenderer: MarkdownTextDecorationRenderer {

    private func hideQuoteMarkers(in source: NSString, range: NSRange, storage: NSTextStorage) {
        for line in lineRanges(in: source, range: range) {
            let value = source.substring(with: line)
            let markerLength = (value as NSString).length -
                (value.replacingOccurrences(of: #"^\s{0,3}> ?"#, with: " ", options: .regularExpression) as NSString).length
            if markerLength > 0 { hide(NSRange(location: line.location, length: markerLength), storage: storage) }
        }
    }

    func apply(source: NSString, nodes: [MarkdownASTNode], to storage: NSTextStorage) {
        for node in nodes {

            guard let range = node.sourceRange, range.location >= 0, NSMaxRange(range) <= source.length else { continue }

            switch node.kind {

            case .blockQuote:
                hideQuoteMarkers(in: source, range: range, storage: storage)
            default:
                break
            }
        }
    }

    func layoutFragment(for element: NSTextElement, at sourceOffset: Int, nodes: [MarkdownASTNode]) -> NSTextLayoutFragment? {
        let isInsideQuote = nodes.contains { node in
            guard case .blockQuote = node.kind, let range = node.sourceRange else { return false }
            return NSLocationInRange(sourceOffset, range)
        }
        return isInsideQuote ? BlockQuoteTextLayoutFragment(textElement: element, range: nil) : nil
    }
}

/// Draws quote backgrounds and rules in TextKit 2's scrolling fragment coordinate system.
private final class BlockQuoteTextLayoutFragment: NSTextLayoutFragment {

    override func draw(at point: CGPoint, in context: CGContext) {
        context.saveGState()

        let surface = blockDecorationSurface(at: point)
        //context.setFillColor(NSColor.quaternaryLabelColor.withAlphaComponent(0.7).cgColor)
        //context.fill(surface)

        context.setStrokeColor(NSColor.textColor.cgColor)
        context.setLineWidth(4)
        //context.setLineCap(.round)

        context.move(to: CGPoint(x: surface.minX - 12, y: surface.minY + 2))
        context.addLine(to: CGPoint(x: surface.minX - 12, y: surface.maxY - 2))

        context.strokePath()
        context.restoreGState()
        super.draw(at: point, in: context)
    }
}

/// Gives all paragraph fragments the same column width, so they read as one block background.
private extension NSTextLayoutFragment {

    func blockDecorationSurface(at point: CGPoint) -> CGRect {
        let renderingBounds = renderingSurfaceBounds.offsetBy(dx: point.x, dy: point.y)
        let container = textLayoutManager?.textContainer
        let textView = container?.textView
        let fragmentFrame = layoutFragmentFrame.offsetBy(dx: point.x, dy: point.y)
        let left = textView == nil ? fragmentFrame.minX : 0//TesseraTextKit2View.textInset
        let width = container?.size.width ?? fragmentFrame.width

        return CGRect(
            x: left,
            y: renderingBounds.minY,
            width: width,
            height: renderingBounds.height
        )
    }
}

private func lineRanges(in source: NSString, range: NSRange) -> [NSRange] {
    var result: [NSRange] = []
    let end = min(source.length, NSMaxRange(range))
    var start = max(0, range.location)
    while start < end {
        let newline = source.range(of: "\n", options: [], range: NSRange(location: start, length: end - start)).location
        let lineEnd = newline == NSNotFound ? end : newline
        result.append(NSRange(location: start, length: lineEnd - start))
        start = newline == NSNotFound ? end : newline + 1
    }
    return result
}

private func hide(_ range: NSRange, storage: NSTextStorage) {
    guard range.location >= 0, NSMaxRange(range) <= storage.length else { return }
    storage.addAttributes([.font: NSFont.systemFont(ofSize: 0.1), .foregroundColor: NSColor.clear], range: range)
}
