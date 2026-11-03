// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TesseraCore",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [.library(name: "TesseraCore", targets: ["TesseraCore"])],
    dependencies: [
        // Swift Markdown supplies the parser used to build Tessera's platform-independent AST.
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.7.3")
    ],
    targets: [
        .target(
            name: "TesseraCore",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")]
        ),
        .testTarget(name: "TesseraCoreTests", dependencies: ["TesseraCore"]),
        .executableTarget(
            name: "MarkdownASTPreview",
            dependencies: ["TesseraCore"]
        )
    ]
)
