/// Visits semantic elements and returns a caller-defined result for each node.
public protocol ElementNodeVisitor {
    associatedtype Result

    mutating func visit(_ node: ElementNode) -> Result
    mutating func defaultVisit(_ node: ElementNode) -> Result
    mutating func visitDocument(_ node: ElementNode) -> Result
    mutating func visitContainer(_ node: ElementNode) -> Result
    mutating func visitParagraph(_ node: ElementNode) -> Result
    mutating func visitHeading(_ node: ElementNode) -> Result
    mutating func visitQuote(_ node: ElementNode) -> Result
    mutating func visitList(_ node: ElementNode) -> Result
    mutating func visitListItem(_ node: ElementNode) -> Result
    mutating func visitCodeBlock(_ node: ElementNode) -> Result
    mutating func visitImage(_ node: ElementNode) -> Result
    mutating func visitDivider(_ node: ElementNode) -> Result
    mutating func visitTable(_ node: ElementNode) -> Result
    mutating func visitEmbeddedContent(_ node: ElementNode) -> Result
    mutating func visitSoftBreak(_ node: ElementNode) -> Result
    mutating func visitLineBreak(_ node: ElementNode) -> Result
    mutating func visitEquation(_ node: ElementNode) -> Result
    mutating func visitDiagram(_ node: ElementNode) -> Result
    mutating func visitChart(_ node: ElementNode) -> Result
    mutating func visitCustom(_ node: ElementNode) -> Result
    mutating func visitText(_ node: ElementNode) -> Result
    mutating func visitEmphasis(_ node: ElementNode) -> Result
    mutating func visitStrong(_ node: ElementNode) -> Result
    mutating func visitStrikethrough(_ node: ElementNode) -> Result
    mutating func visitInlineCode(_ node: ElementNode) -> Result
    mutating func visitLink(_ node: ElementNode) -> Result
}

public extension ElementNodeVisitor {
    /// Dispatches each semantic kind to its matching visitor method.
    mutating func visit(_ node: ElementNode) -> Result {
        dispatch(node)
    }

    /// Allows visitors to wrap dispatch with bookkeeping before or after visiting a node.
    mutating func dispatch(_ node: ElementNode) -> Result {
        switch node.kind {
        case .document: visitDocument(node)
        case .container: visitContainer(node)
        case .paragraph: visitParagraph(node)
        case .heading: visitHeading(node)
        case .quote: visitQuote(node)
        case .list: visitList(node)
        case .listItem: visitListItem(node)
        case .codeBlock: visitCodeBlock(node)
        case .image: visitImage(node)
        case .divider: visitDivider(node)
        case .table: visitTable(node)
        case .embeddedContent: visitEmbeddedContent(node)
        case .softBreak: visitSoftBreak(node)
        case .lineBreak: visitLineBreak(node)
        case .equation: visitEquation(node)
        case .diagram: visitDiagram(node)
        case .chart: visitChart(node)
        case .custom: visitCustom(node)
        case .text: visitText(node)
        case .emphasis: visitEmphasis(node)
        case .strong: visitStrong(node)
        case .strikethrough: visitStrikethrough(node)
        case .inlineCode: visitInlineCode(node)
        case .link: visitLink(node)
        }
    }

    mutating func visitDocument(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitContainer(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitParagraph(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitHeading(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitQuote(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitList(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitListItem(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitCodeBlock(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitImage(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitDivider(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitTable(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitEmbeddedContent(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitSoftBreak(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitLineBreak(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitEquation(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitDiagram(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitChart(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitCustom(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitText(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitEmphasis(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitStrong(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitStrikethrough(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitInlineCode(_ node: ElementNode) -> Result { defaultVisit(node) }
    mutating func visitLink(_ node: ElementNode) -> Result { defaultVisit(node) }
}

public extension ElementNode {
    /// Starts a visitor at this node while leaving tree traversal to the visitor.
    func accept<Visitor: ElementNodeVisitor>(_ visitor: inout Visitor) -> Visitor.Result {
        visitor.visit(self)
    }
}
