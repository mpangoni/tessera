# Tessera

Tessera is a local-first Markdown block editor. The portable `TesseraCore` Swift package contains the document model, Markdown codec, and editing commands; the macOS app owns document and input integration.

## Requirements

- Xcode 27 / Swift 6 and macOS 27 are the specified runtime. This machine has Xcode 26.6 and macOS 26.5.2; the app is set to a macOS 27 deployment target but can only be compiled against the installed macOS 26.5 SDK here.

## Build and test

```sh
swift test --package-path Packages/TesseraCore
xcodebuild -project Tessera.xcodeproj -scheme Tessera -destination 'platform=macOS' build
```

Open `Tessera.xcodeproj` in Xcode to run the app. The source-of-truth product specification is [`docs/specs/SPEC-0001-foundation-and-block-editor.md`](docs/specs/SPEC-0001-foundation-and-block-editor.md).

See [`docs/implementation-report.md`](docs/implementation-report.md) for the implemented scope and validation gaps.
