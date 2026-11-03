import AppKit
import SwiftUI
import TesseraCore

/// Displays the semantic text extracted from a Markdown document's Tessera AST.
struct TextKitTesseraEditor: NSViewRepresentable {
    @Binding var markdown: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        // One content storage owns the document text for this TextKit 2 editor.
        let contentStorage = NSTextContentStorage()
        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)
        context.coordinator.contentStorage = contentStorage

        let textContainer = NSTextContainer(size: NSSize(width: 640, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.textContainer = textContainer

        let textView = TesseraBackgroundTextView(frame: .zero, textContainer: textContainer)
        textView.decorationLayoutManager = layoutManager
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = NSView.AutoresizingMask.width
        textView.minSize = NSSize(width: 0, height: 40)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainerInset = NSSize(width: 30, height: 5)
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = NSColor.labelColor

        let projection = projection(of: markdown)
        textView.decoratedElements = projection.decoratedElements
        contentStorage.attributedString = projection.attributedString

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? TesseraBackgroundTextView else { return }
        guard let contentStorage = context.coordinator.contentStorage else { return }

        let projection = projection(of: markdown)
        textView.decoratedElements = projection.decoratedElements
        textView.needsDisplay = true

        if !(contentStorage.attributedString ?? NSAttributedString()).isEqual(to: projection.attributedString) {
            contentStorage.attributedString = projection.attributedString
        }
    }

    /// Parses Markdown through the shared codec and lets the AST visitor build styled TextKit content.
    private func projection(of markdown: String) -> EditorProjection {
        guard let artifact = try? MarkdownCodec().parse(Data(markdown.utf8)) else {
            return EditorProjection(
                attributedString: NSAttributedString(
                    string: markdown,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: NSFont.systemFontSize),
                        .foregroundColor: NSColor.labelColor
                    ]
                ),
                decoratedElements: []
            )
        }
        var visitor = TesseraTextProjection(artifact: artifact)
        let renderedText = visitor.project(artifact.root)
        let decoratedElements = TesseraContentDecorationPass().decoratedElements(
            in: artifact.root,
            ranges: renderedText.nodeRanges
        )
        return EditorProjection(attributedString: renderedText.attributedString, decoratedElements: decoratedElements)
    }

    /// Retains the content store for as long as AppKit uses its layout and text views.
    private struct EditorProjection {
        let attributedString: NSAttributedString
        let decoratedElements: [TesseraDecoratedElement]
    }

    @MainActor
    final class Coordinator: NSObject {
        var contentStorage: NSTextContentStorage?
    }
}
