# Tessera

Tessera 0.1.2 is a local-first Markdown block editor. The portable `TesseraCore` Swift package contains the document model, Markdown codec, and editing commands; the macOS app owns document and input integration.

## Requirements

- Xcode 26.6 / Swift 6.3 and macOS 26.5 or later. The project uses SwiftUI's native `FileDocument` API available in this toolchain.

## Build and test

```sh
swift test --package-path Packages/TesseraCore
xcodebuild -project Tessera.xcodeproj -scheme Tessera -destination 'platform=macOS' build
```

Open `Tessera.xcodeproj` in Xcode to run the app. The source-of-truth product specification is [`docs/specs/SPEC-0001-foundation-and-block-editor.md`](docs/specs/SPEC-0001-foundation-and-block-editor.md).

See [`docs/implementation-report.md`](docs/implementation-report.md) for the implemented scope and validation gaps.

Refinement scope for release 0.1.2 is recorded in [`SPEC-0002`](docs/specs/SPEC-0002-block-editor-refinements.md).

## Sample documents

Open [`Samples/Alice-in-Wonderland.md`](Samples/Alice-in-Wonderland.md) in Tessera to try the block editor with a short Markdown adaptation of the opening of Lewis Carroll's *Alice's Adventures in Wonderland*.
