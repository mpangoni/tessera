# Tessera v0.1 implementation report

## Implemented

- Created a macOS app project and a portable `TesseraCore` Swift package, with the specification, repository guidance, and roadmap under `docs/`.
- Added a Sendable block model and testable insert, update, split, safe merge, delete, and move commands.
- Added a UTF-8 Markdown codec for paragraphs, headings, list items, blockquotes, horizontal rules, and fenced code. It retains exact original source for no-edit saves and preserves unsupported or nested constructs as opaque blocks.
- Added a SwiftUI document editor with multiline text inputs, block insertion/deletion, visual drag targets, and single-block reordering. It uses SwiftUI's native document group for New/Open/Save/Save As and multiple document windows.
- The Xcode project targets macOS 26.5 so the app can launch on the available development OS. This is a deliberate compatibility deviation from the macOS 27 target in SPEC-0001. The installed Xcode 26.6 SDK requires a direct standard Markdown UTI identifier in place of its unavailable `UTType.markdown` declaration.

## Verification

- `swift test --package-path Packages/TesseraCore`: passed, 9 tests.
- `xcodebuild -project Tessera.xcodeproj -scheme Tessera -destination 'platform=macOS' build`: passed against macOS 26.5 SDK.
- Launched the resulting `.app` on macOS 26.5.2; the Tessera process started.
- `git diff --check`: passed.

## Remaining gaps and limitations

- Only app process launch was verified. The manual editing, file lifecycle, VoiceOver, appearance, multiple-window, and long-document acceptance checks remain unverified.
- The document adapter uses SwiftUI `FileDocument` because the requested Xcode 27 `Document` APIs are unavailable in Xcode 26.6. Native external-change conflict handling, autosave behavior, and undo integration therefore need verification and likely adjustment on Xcode 27.
- The current editor provides multiline text fields and block-level add/delete/reorder, but does not yet implement the specified Return-to-split, Shift+Return, list continuation/termination, code-block newline contract, safe Backspace merge, caret transfer, or native undo/redo for block operations.
- Drag/drop and keyboard behavior, VoiceOver, appearance, two-window isolation, Save As extension behavior, and long-document scrolling have not been manually tested.
- Complex Markdown is intentionally opaque. Editing supported blocks can canonicalize those blocks and their surrounding separators; only no-edit saves promise byte-for-byte retention.
