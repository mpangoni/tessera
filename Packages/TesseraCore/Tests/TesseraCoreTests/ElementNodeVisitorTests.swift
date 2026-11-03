import Testing
@testable import TesseraCore

@Test func elementVisitorDispatchesBySemanticKindAndUsesDefaultForOtherNodes() {
    var visitor = KindNameVisitor()
    let heading = ElementNode(id: 1, kind: .heading(level: 2))
    let paragraph = ElementNode(id: 2, kind: .paragraph)

    #expect(heading.accept(&visitor) == "heading:2")
    #expect(paragraph.accept(&visitor) == "default:paragraph")
}

private struct KindNameVisitor: ElementNodeVisitor {
    mutating func defaultVisit(_ node: ElementNode) -> String {
        "default:\(node.kind)"
    }

    mutating func visitHeading(_ node: ElementNode) -> String {
        guard case let .heading(level) = node.kind else { return defaultVisit(node) }
        return "heading:\(level)"
    }
}
