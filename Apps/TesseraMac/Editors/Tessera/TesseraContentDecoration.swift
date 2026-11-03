import AppKit
import TesseraCore

/// An AST node paired with its range in the projected TextKit document.
struct TesseraDecoratedElement {
    let kind: ElementKind
    let range: NSRange
}

/// Draws backgrounds that belong to whole semantic blocks rather than individual lines.
struct TesseraContentDecorationPass {
    @MainActor
    func drawBackgrounds(
        in context: CGContext,
        textView: NSTextView,
        layoutManager: NSTextLayoutManager,
        elements: [TesseraDecoratedElement]
    ) {
        BlockQuoteBackgroundDecoration().draw(
            in: context,
            textView: textView,
            layoutManager: layoutManager,
            elements: elements
        )
        CodeBlockBackgroundDecoration().draw(
            in: context,
            textView: textView,
            layoutManager: layoutManager,
            elements: elements
        )
        InlineCodeBackgroundDecoration().draw(
            in: context,
            textView: textView,
            layoutManager: layoutManager,
            elements: elements
        )
    }

    func decoratedElements(in root: ElementNode, ranges: [UInt64: NSRange]) -> [TesseraDecoratedElement] {
        var result: [TesseraDecoratedElement] = []
        appendElements(from: root, ranges: ranges, to: &result)
        return result
    }

    private func appendElements(
        from node: ElementNode,
        ranges: [UInt64: NSRange],
        to result: inout [TesseraDecoratedElement]
    ) {
        if let range = ranges[node.id] {
            result.append(TesseraDecoratedElement(kind: node.kind, range: range))
        }
        for child in node.children {
            appendElements(from: child, ranges: ranges, to: &result)
        }
    }
}

/// Paints one full-width rectangle per code block before NSTextView draws any glyphs.
struct CodeBlockBackgroundDecoration {
    @MainActor
    func draw(
        in context: CGContext,
        textView: NSTextView,
        layoutManager: NSTextLayoutManager,
        elements: [TesseraDecoratedElement]
    ) {
        let codeRanges = elements.compactMap { element -> NSRange? in
            guard case .codeBlock = element.kind else { return nil }
            return element.range
        }
        guard !codeRanges.isEmpty else { return }

        guard let textContainer = layoutManager.textContainer else { return }
        let verticalBounds = BlockBackgroundGeometry.verticalBounds(for: codeRanges, in: layoutManager)

        let origin = textView.textContainerOrigin
        let topPadding: CGFloat = 8
        let bottomPadding: CGFloat = 12
        context.saveGState()
        context.setFillColor(NSColor.underPageBackgroundColor.cgColor)

        for bounds in verticalBounds {
            guard let bounds else { continue }
            let rect = CGRect(
                x: origin.x,
                y: origin.y + bounds.minY - topPadding,
                width: textContainer.size.width,
                height: bounds.height + topPadding + bottomPadding
            )
            let roundedRect = CGPath(roundedRect: rect, cornerWidth: 9, cornerHeight: 9, transform: nil)
            context.addPath(roundedRect)
            context.fillPath()
        }

        context.restoreGState()
    }
}

/// Shades each quote as one surface and draws its rule once across all contained paragraphs.
struct BlockQuoteBackgroundDecoration {
    @MainActor
    func draw(
        in context: CGContext,
        textView: NSTextView,
        layoutManager: NSTextLayoutManager,
        elements: [TesseraDecoratedElement]
    ) {
        guard let textContainer = layoutManager.textContainer else { return }
        let quoteRanges = elements.compactMap { element -> NSRange? in
            guard case .quote = element.kind else { return nil }
            return element.range
        }
        guard !quoteRanges.isEmpty else { return }

        let verticalBounds = BlockBackgroundGeometry.verticalBounds(for: quoteRanges, in: layoutManager)
        let origin = textView.textContainerOrigin
        let topPadding: CGFloat = 8
        let bottomPadding: CGFloat = 8

        context.saveGState()
        context.setFillColor(NSColor.controlBackgroundColor.cgColor)
        for bounds in verticalBounds {
            guard let bounds else { continue }
            let rect = CGRect(
                x: origin.x,
                y: origin.y + bounds.minY - topPadding,
                width: textContainer.size.width,
                height: bounds.height + topPadding + bottomPadding
            )
            context.addPath(CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil))
            context.fillPath()

            // The quote text is indented 22 points, leaving an 8-point inset before this 2-point rule.
            context.setStrokeColor(NSColor.secondaryLabelColor.cgColor)
            context.setLineWidth(2)
            context.setLineCap(.round)
            let x = rect.minX + 9
            context.move(to: CGPoint(x: x, y: rect.minY + 7))
            context.addLine(to: CGPoint(x: x, y: rect.maxY - 7))
            context.strokePath()
        }
        context.restoreGState()
    }
}

/// Draws a small rounded fill behind each visual segment of inline code.
struct InlineCodeBackgroundDecoration {
    @MainActor
    func draw(
        in context: CGContext,
        textView: NSTextView,
        layoutManager: NSTextLayoutManager,
        elements: [TesseraDecoratedElement]
    ) {
        guard let contentManager = layoutManager.textContentManager else { return }
        let ranges = elements.compactMap { element -> NSRange? in
            guard case .inlineCode = element.kind else { return nil }
            return element.range
        }
        guard !ranges.isEmpty else { return }

        let documentStart = contentManager.documentRange.location
        let origin = textView.textContainerOrigin
        context.saveGState()
        context.setFillColor(NSColor.quaternaryLabelColor.withAlphaComponent(0.2).cgColor)

        for range in ranges where range.length > 0 {
            guard let start = contentManager.location(documentStart, offsetBy: range.location),
                  let end = contentManager.location(documentStart, offsetBy: NSMaxRange(range)),
                  let textRange = NSTextRange(location: start, end: end) else { continue }
            layoutManager.ensureLayout(for: textRange)

            layoutManager.enumerateTextSegments(in: textRange, type: .standard, options: []) {
                _, segmentFrame, _, _ in
                let pill = segmentFrame.offsetBy(dx: origin.x, dy: origin.y).insetBy(dx: -3, dy: -2)
                context.addPath(CGPath(roundedRect: pill, cornerWidth: 4, cornerHeight: 4, transform: nil))
                context.fillPath()
                return true
            }
        }

        context.restoreGState()
    }
}

/// Maps AST source ranges to the combined vertical bounds of their TextKit paragraphs.
@MainActor
private enum BlockBackgroundGeometry {
    static func verticalBounds(for ranges: [NSRange], in layoutManager: NSTextLayoutManager) -> [CGRect?] {
        guard let contentManager = layoutManager.textContentManager else {
            return Array(repeating: nil, count: ranges.count)
        }

        var bounds = Array<CGRect?>(repeating: nil, count: ranges.count)
        let documentStart = contentManager.documentRange.location
        layoutManager.enumerateTextLayoutFragments(from: documentStart, options: [.ensuresLayout]) { fragment in
            guard let textElement = fragment.textElement,
                  let elementRange = textElement.elementRange else { return true }
            let start = contentManager.offset(from: documentStart, to: elementRange.location)
            let end = contentManager.offset(from: documentStart, to: elementRange.endLocation)
            let fragmentRange = NSRange(location: start, length: max(0, end - start))
            guard fragmentRange.length > 0 else { return true }

            let frame = fragment.layoutFragmentFrame
            let surface = fragment.renderingSurfaceBounds
            let fragmentBounds = CGRect(
                x: frame.minX,
                y: frame.minY + surface.minY,
                width: frame.width,
                height: surface.height
            )
            for (index, range) in ranges.enumerated()
            where NSIntersectionRange(range, fragmentRange).length > 0 {
                bounds[index] = bounds[index].map { $0.union(fragmentBounds) } ?? fragmentBounds
            }
            return true
        }
        return bounds
    }
}

/// Gives NSTextView the current AST ranges and paints block surfaces before text.
final class TesseraBackgroundTextView: NSTextView {
    weak var decorationLayoutManager: NSTextLayoutManager?
    var decoratedElements: [TesseraDecoratedElement] = []
    private let decorationPass = TesseraContentDecorationPass()

    override func draw(_ dirtyRect: NSRect) {
        if let context = NSGraphicsContext.current?.cgContext,
           let decorationLayoutManager {
            decorationPass.drawBackgrounds(
                in: context,
                textView: self,
                layoutManager: decorationLayoutManager,
                elements: decoratedElements
            )
        }
        super.draw(dirtyRect)
    }
}
