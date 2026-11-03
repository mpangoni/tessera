# SPEC-0006: TextKit 2 Document Editor

## Goal

Replace one-text-view-per-block rendering with one editable TextKit 2 text view backed by a platform-independent Markdown AST projection.

## Scope

- Keep Markdown text as the saved document source.
- Parse Markdown into an AST with source ranges; use the AST to style and identify document structures.
- Use one `NSTextView` configured with TextKit 2 for the whole document.
- Apply inline formatting to source ranges without removing Markdown from the backing string.
- Preserve ordinary text editing, selection, undo, drag and drop, and document saving.
- Keep block commands in TesseraCore and route block-level actions through those commands.
- Keep specialized block visuals and range-anchored controls extensible.

## Acceptance criteria

- [ ] The block editor creates one TextKit 2 text view for the document.
- [ ] The AST contains block and inline node kinds with UTF-16 source ranges.
- [ ] Typing updates the Markdown document and preserves unsupported syntax.
- [ ] Bold, italic, code, and links can be styled from AST/source ranges.
- [ ] Native selection, caret movement, undo, and text drag and drop continue working.
- [ ] Block-level operations can identify their target from source ranges.
- [ ] The implementation does not access the legacy `NSLayoutManager` API.

## Validation

- Test source range conversion, including Unicode and line endings.
- Build the Core package and macOS app.
- Manually inspect a sample document in the TextKit 2 editor when UI automation is available.
