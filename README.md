# Tessera

## About

**Tessera 0.1.2 is a very unstable early version.** It is a local-first Markdown block editor with both block editing and a raw Markdown editing view. The portable `TesseraCore` Swift package contains the document model, Markdown codec, and editing commands; the macOS app owns document and input integration.

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

The block and raw Markdown editing views are documented in [`SPEC-0003`](docs/specs/SPEC-0003-dual-markdown-editing-views.md).

Inline bold and italic rendering in the block editor is documented in [`SPEC-0004`](docs/specs/SPEC-0004-inline-emphasis-rendering.md).

Horizontal-rule and blockquote visuals are documented in [`SPEC-0005`](docs/specs/SPEC-0005-horizontal-rule-and-blockquote-rendering.md).

## License

The Tessera source code is offered under the GNU General Public License, version 3 or any later version; see [`LICENSE`](LICENSE). A separate commercial license may be obtained by written agreement with the copyright holder, Marcos Augusto Pangoni (`marcos@pangoni.com.br`). This dual-licensing notice applies to the Tessera source code. Sample documents and other third-party materials retain the licenses stated with those materials; for example, [`Alice-in-Wonderland.md`](Samples/Alice/Alice-in-Wonderland.md) includes its own Project Gutenberg notice.

## Sample documents

Open [`Samples/Alice/Alice-in-Wonderland.md`](Samples/Alice/Alice-in-Wonderland.md) in Tessera to try the block editor with a short Markdown adaptation of the opening of Lewis Carroll's *Alice's Adventures in Wonderland*.

For examples of common Markdown elements, see the [basic syntax reference](Samples/Markdown/Markdown-Basic-Syntax-Reference.md).
