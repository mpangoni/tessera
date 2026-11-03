import Foundation

/// Pairs the shared element AST with the optional source bytes from which it was parsed.
public struct ContentArtifact: Sendable {
    public var root: ElementNode

    /// The exact original input, when the artifact came from a source document.
    public var source: SourceSnapshot?

    public init(root: ElementNode, source: SourceSnapshot? = nil) {
        self.root = root
        self.source = source
    }

    /// Resolves a node's source range on demand without storing a second text value on the node.
    public func sourceText(for node: ElementNode) -> String? {
        guard let range = node.source else { return nil }
        return source?.text(in: range)
    }
}

extension ContentArtifact: Equatable {}
