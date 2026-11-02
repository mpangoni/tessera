# Tessera

Tessera is a local-first Markdown block editor. The portable `TesseraCore` Swift package contains the document model, Markdown codec, and editing commands; the macOS app owns document and input integration.

## Requirements

- The specification calls for macOS 27 / Xcode 27. The current Xcode project targets macOS 26.5 so it can run on this development machine; this compatibility adjustment should be revisited when validating the macOS 27 document APIs.

## Build and test

```sh
swift test --package-path Packages/TesseraCore
xcodebuild -project Tessera.xcodeproj -scheme Tessera -destination 'platform=macOS' build
```

Open `Tessera.xcodeproj` in Xcode to run the app. The source-of-truth product specification is [`docs/specs/SPEC-0001-foundation-and-block-editor.md`](docs/specs/SPEC-0001-foundation-and-block-editor.md).

See [`docs/implementation-report.md`](docs/implementation-report.md) for the implemented scope and validation gaps.
