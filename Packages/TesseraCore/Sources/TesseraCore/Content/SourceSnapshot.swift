import Foundation

/// The unit used to interpret offsets into a source snapshot.
public enum SourceOffsetUnit: Equatable, Sendable {
    case utf8Byte
    case utf16CodeUnit
    case unicodeScalar
}

/// A half-open UTF-8 byte range into a `SourceSnapshot`.
public struct SourceRange: Equatable, Sendable {
    public let location: Int
    public let length: Int
    public let unit: SourceOffsetUnit

    public init(location: Int, length: Int, unit: SourceOffsetUnit = .utf8Byte) {
        self.location = location
        self.length = length
        self.unit = unit
    }

    public var end: Int { location + length }
}

/// Captures the exact bytes supplied to a content codec for lossless source preservation.
public struct SourceSnapshot: Equatable, Sendable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    /// Materializes a UTF-8 source slice only when a consumer asks for its text.
    public func text(in range: SourceRange) -> String? {
        guard range.unit == .utf8Byte,
              range.location >= 0,
              range.length >= 0,
              range.end <= data.count else { return nil }

        return data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return range.length == 0 ? "" : nil
            }
            let slice = UnsafeBufferPointer(start: baseAddress.advanced(by: range.location), count: range.length)
            return String(decoding: slice, as: UTF8.self)
        }
    }
}
