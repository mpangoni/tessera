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
        CodeBlockBackgroundDecoration().draw(
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
        guard let textContainer = layoutManager.textContainer,
              let contentManager = layoutManager.textContentManager else { return }

        let codeRanges = elements.compactMap { element -> NSRange? in
            guard case .codeBlock = element.kind else { return nil }
            return element.range
        }
        guard !codeRanges.isEmpty else { return }

        var verticalBounds = Array<CGRect?>(repeating: nil, count: codeRanges.count)
        let documentStart = contentManager.documentRange.location

        // Collect every laid-out paragraph that intersects each AST code block.
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

            for (index, codeRange) in codeRanges.enumerated() {
                if NSIntersectionRange(codeRange, fragmentRange).length > 0 {
                    verticalBounds[index] = verticalBounds[index].map { $0.union(fragmentBounds) } ?? fragmentBounds
                }
            }
            return true
        }

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
