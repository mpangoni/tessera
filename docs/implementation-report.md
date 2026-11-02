# Tessera v0.1.2 implementation report

## Implemented

- Created a macOS app project and a portable `TesseraCore` Swift package, with the specification, repository guidance, and roadmap under `docs/`.
- Added a Sendable block model and testable insert, update, split, safe merge, delete, and move commands.
- Added selected-range splitting, ordered/unordered list continuation, merge caret offsets, and model snapshot undo/redo registration.
- Added a UTF-8 Markdown codec for paragraphs, headings, list items, blockquotes, horizontal rules, and fenced code. It retains exact original source for no-edit saves, preserves unsupported or nested constructs as opaque blocks, and round-trips empty leading/trailing paragraphs after edits.
- Added a native AppKit text input bridge for cursor/selection-aware Return and Backspace, plus hover-only drag/delete controls with keyboard move actions and single-block drag reordering. The plus controls are removed.
- Up/Down moves between visual lines within a block and transfers focus to the adjacent block at a block boundary. At the document boundary, native text-view behavior applies. Set the Launch Services multiple-instance prohibition key.
- The app remains a SwiftUI `FileDocument` / `DocumentGroup` document application for New/Open/Save/Save As and multiple windows.
- Bumped the app's marketing version to 0.1.2 and added the accepted refinements as SPEC-0002.
- The Xcode project targets macOS 26.5, using SwiftUI `FileDocument` / `DocumentGroup`. The installed Xcode 26.6 SDK requires a direct standard Markdown UTI identifier in place of its unavailable `UTType.markdown` declaration.

## Verification

- `swift test --package-path Packages/TesseraCore`: passed, 14 tests.
- `xcodebuild -project Tessera.xcodeproj -scheme Tessera -destination 'platform=macOS' build`: passed against macOS 26.5 SDK.
- In an isolated app instance, verified selection split, Return at block end, Backspace merge caret placement, and native Undo/Redo. The app process launched on macOS 26.5.2.
- Confirmed the built Info.plist contains `LSMultipleInstancesProhibited = true`; a second test launch left one test-app process running.
- `git diff --check`: passed.

## Remaining gaps and limitations

- Arrow-key boundary behavior, hover reveal/hide, drag/drop, deletion, app-level save/reopen, VoiceOver, light/dark, two-window isolation, Save As extension behavior, and 300-block scrolling still need UI verification. Core tests cover Markdown round-trips for empty blocks and edited split/merge output.
- Native external-change conflict handling and autosave behavior need app-level verification.
- Complex Markdown is intentionally opaque. Editing supported blocks can canonicalize those blocks and their surrounding separators; only no-edit saves promise byte-for-byte retention.
