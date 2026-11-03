import SwiftUI

/// The shared metadata every document editor contributes to the mode picker.
///
/// Keeping this contract small lets `MainContentView` coordinate different editor
/// experiences without needing to know how each one renders its content.
protocol EditorImplementation: View {
    static var mode: EditorMode { get }
    static var symbolName: String { get }
    static var displayName: String { get }
}

/// The two current ways to edit a Markdown document.
enum EditorMode: Hashable {
    case tessera
    case markdown
}
