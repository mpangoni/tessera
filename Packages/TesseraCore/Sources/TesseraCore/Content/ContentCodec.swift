import Foundation

/// Converts source bytes to a typed AST artifact and encodes that artifact back to bytes.
public protocol ContentCodec {
    /// Parses source data and returns the AST together with any preserved original source.
    func parse(_ data: Data) throws -> ContentArtifact

    /// Encodes an AST artifact into the codec's source format.
    func encode(_ artifact: ContentArtifact) throws -> Data
}
