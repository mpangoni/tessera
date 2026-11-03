# Explore the Tessera AST

From the repository root, run:

```sh
swift run --package-path Packages/TesseraCore MarkdownASTPreview
```

The preview parses `Markdown-Basic-Syntax-Reference.md` using Tessera's
`MarkdownCodec`, then prints each `ElementNode` with its ID, semantic kind,
UTF-8 source range, and visible text for text nodes.

To inspect another document, pass its path:

```sh
swift run --package-path Packages/TesseraCore MarkdownASTPreview path/to/document.md
```
