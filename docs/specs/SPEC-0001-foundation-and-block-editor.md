# Tessera — SPEC-0001: Foundation and Markdown Block Editor

**Version:** 0.1.0  
**Status:** Proposed for implementation  
**Date:** 2026-11-02  
**Target:** macOS first; iPadOS and iOS later  
**Owner:** Tessera project  
**Implementation agent:** Codex

## 1. Product vision

Tessera is a native, local-first personal knowledge-management and technical-writing application. It combines the approachable block editing of Craft with the portability of Markdown. Later releases may introduce backlinks, knowledge navigation, LaTeX, diagrams, charts, and specialized technical blocks inspired by Obsidian, Bear, Ulysses, and Overleaf.

A Tessera *document* is a container of ordered blocks. A block is the smallest independently editable and movable unit. In the first release, documents are ordinary Markdown files (`.md`). Tessera must not require a workspace, database, cloud account, or proprietary format to open or save one.

**Primary first-release outcome:** A user can create or open a Markdown document, edit it as movable blocks, reorder blocks with drag-and-drop, save the document, and reopen it without losing content.

## 2. Scope and constraints

### In scope — v0.1

- A native macOS application named **Tessera**, with its own Xcode project and one application target.
- Native File menu actions: New, Open, Save, Save As, and Close. Standard macOS document-window behavior, including multiple open documents, undo/redo, and unsaved-change handling.
- Import and export UTF-8 Markdown (`.md`); preserve the document's content when no substantive edits occur.
- An ordered, block-based document editor with keyboard-based editing, block insertion, deletion, and drag-and-drop reordering.
- Basic Markdown block types: paragraph, headings H1-H6, unordered list item, ordered list item, blockquote, fenced code block, horizontal rule, and an opaque/raw Markdown fallback for unsupported constructs.
- Minimal inline Markdown input: keep `**bold**`, `*italic*`, backticks, links, and similar markup as editable text in v0.1; no full rich-text or WYSIWYG inline formatting is required.
- System fonts, system light/dark appearance, native selection/focus indicators, and a simple single-column editor.
- Automated tests for the document model, Markdown conversion, edit commands, and preservation of unsupported Markdown.
- A repository layout that keeps cross-platform models and logic independent from macOS-specific editing controls.

### Explicitly out of scope — v0.1

- iPhone/iPad builds and interactions (architecture preparation only).
- Vaults, folders, tags, search, backlinks, graph view, sync, collaboration, accounts, or cloud storage.
- Image attachment management, tables as editable grids, math rendering, diagrams, charts, plugins, and embedded media.
- A proprietary `.tessera` format or sidecar metadata files.
- Rich-text selection toolbars, live inline formatting, export to PDF/HTML, custom themes, or typography controls.

## 3. Platform and technology choices

- **Language:** Swift 6, with strict concurrency checking where practical.
- **UI:** SwiftUI, with small, isolated AppKit bridges only where native text input, focus, caret handling, or drag-and-drop behavior cannot be implemented reliably using SwiftUI alone.
- **First deployment target:** macOS 27+, using Xcode 27+ and SwiftUI's modern `Document` / `DocumentGroup` document infrastructure. This is an explicit MVP decision; it excludes older macOS releases until a compatibility spec is approved.
- **Future platform target:** iPadOS/iOS; share the model, Markdown codec, editor commands, and most view composition. Use platform-specific input adapters rather than embedding AppKit logic into the domain model.
- **Persistence:** local UTF-8 Markdown, via coordinated system document operations. Use `UTType.markdown`.
- **Dependencies:** prefer Apple frameworks; `swift-markdown` is permitted for parsing, with a pinned version. Do not use its normalized formatter for untouched source without testing content fidelity.
- **No backend, account, telemetry, or analytics service.**

### Document API boundary

Keep Apple document-framework conformance in the app/document-infrastructure layer. `TesseraCore` should work on strings and block models, not `DocumentGroup`, `NSDocument`, file URLs, or AppKit. On macOS 27, use the `Document` protocol with a reference-backed observable document and register undo actions for user changes so native autosave works correctly. Preserve system Save and Save As semantics; do not hand-roll independent file saving inside the editor view.

## 4. Domain model

Implement a clear separation between **persistent Markdown text**, an **in-memory ordered block model**, and **editing operations**.

Suggested types (names may vary if Codex has a better Swift-idiomatic design):

```swift
struct TesseraBlock: Identifiable, Equatable, Sendable {
    let id: UUID               // Session identity in v0.1
    var kind: BlockKind
    var content: String         // User-editable block content
    var source: String?         // Original Markdown segment when unmodified
    var isDirty: Bool
}

enum BlockKind: Equatable, Sendable {
    case paragraph
    case heading(level: Int)
    case unorderedListItem
    case orderedListItem(number: Int)
    case blockquote
    case fencedCode(language: String?)
    case horizontalRule
    case rawMarkdown
}

struct BlockDocument: Equatable, Sendable {
    var blocks: [TesseraBlock]
    // Include document-level source metadata needed for safe round-tripping.
}
```

The code above describes the expected responsibilities, not a requirement to duplicate these exact declarations. Keep IDs stable during edits and moves within one open session. IDs do **not** need to survive re-opening `.md` files, and no persisted cross-document references may depend on them yet.

**Invariants:**

1. Document block order is authoritative for display and serialization.
2. Every meaningful source span belongs to exactly one block or an explicitly retained separator/source segment.
3. No editing command silently drops text.
4. All changes pass through a small set of testable editing commands, rather than separate ad-hoc array mutations in views.
5. Document serialization is deterministic for the same model.

## 5. Markdown import/export contract

### Import

1. Open a UTF-8 `.md` file through macOS document infrastructure. Invalid/undecodable data must produce a visible error, not silent replacement of characters.
2. Parse top-level blocks into an ordered block list. Preserve original source spans, separators, and line-ending style whenever practicable.
3. Recognize the v0.1 block types listed in Section 2. For Markdown not supported by the editor (for example, complex nested lists, tables, HTML, or complex multi-block structures), create an **opaque raw Markdown block** rather than discarding or flattening content.
4. A blank file opens as an empty editable document with an insertion point; the UI may create an empty paragraph as an in-memory convenience without forcing text into the saved file.
5. A fenced code block remains a single block, including lines and optional language designation.

### Export and preservation

1. Serialize blocks in their current order back to valid Markdown.
2. Untouched blocks should retain their original Markdown spelling and source wherever possible; changed supported blocks may be canonically serialized.
3. Opaque blocks are preserved verbatim when unrelated supported blocks are edited or reordered.
4. Saving an opened document **without any edits** must not gratuitously reformat its Markdown. Test byte-for-byte preservation for representative UTF-8/LF files, and test that CRLF and trailing newlines remain intact without edits.
5. No silent conversion of a list to plain paragraphs, destruction of a code fence, or deletion of an unrecognized construct is permitted.
6. When preservation cannot be guaranteed for a transformation, refuse that transformation gracefully or keep the affected source as raw Markdown.

### Example

Input:

````markdown
# Research Notes

First paragraph with **emphasis**.

- First item
- Second item

```swift
print("Tessera")
```
````

The editor exposes five movable blocks: one heading, one paragraph, two list items, and one fenced-code block. The code fence is not split into paragraphs. The saved document must still be usable in another Markdown editor.

## 6. Block editor behavior

### Layout

- One distraction-free document column, centered in the window with a readable maximum width.
- A subtle drag handle appears when hovering or focusing a block; native pointer and keyboard focus indications.
- Paragraphs use the system body font. Headings use system font styles with progressively smaller sizes. Code blocks use the system monospaced font.
- Heading prefixes (`#`) and basic block prefixes can be represented visually rather than shown as editable source; inline emphasis/link syntax remains visible as Markdown text in v0.1.
- No custom design system in the first release. Respect accessibility text sizing and the current system appearance.

### Editing interaction contract

- Click a block to edit; typing changes the current block.
- `Return` in a paragraph or heading splits at the caret into two blocks, placing focus in the new paragraph. Empty headings become paragraphs when the user continues onto a new line.
- `Shift+Return` inserts a line break inside the current text block without creating a new block.
- `Return` in a nonempty list item creates the next list item. `Return` on an empty list item ends the list and creates a paragraph.
- `Return` inside a fenced-code block inserts a newline **inside the same block**.
- `Backspace` at the beginning of a paragraph merges with an adjacent editable text block only if the merge is safe; otherwise preserve the text and leave the block intact. Non-text blocks must not be accidentally merged or deleted.
- Focus and caret should move predictably when splitting, inserting, or merging blocks.
- Provide an obvious way to add a paragraph below an existing block; a small plus control or keyboard action is sufficient.
- Blocks can be reordered by dragging the handle to a visible insertion position. Reordering must not change block content or IDs.
- One undo step should reverse one logical operation (typing as appropriate to native text editing, block split, merge, insertion, deletion, or move). Redo should restore it.
- Standard text selection, copy, paste, and keyboard shortcuts should work. Multi-block selection, bulk dragging, and rich pasted content conversion are not required yet.

When an interaction is under-specified, implement the safest behavior that preserves data and document validity; document that choice in the implementation notes rather than inventing extra product features.

## 7. Application and File menu

Use native macOS document menus and keyboard shortcuts instead of custom file dialogs wherever possible:

| Action | Expected behavior |
|---|---|
| New | Open a new empty Markdown document. |
| Open | Choose an existing `.md` file and display its blocks. |
| Save | Save the current file with native document behavior. |
| Save As | Save a separate copy at the user-selected path. |
| Close | Close the active document, respecting native unsaved-change handling. |
| Undo / Redo | Reverse and reapply editing operations. |

Support more than one open document/window. Keep document state independent per window. Autosave may be enabled through the native document lifecycle, but test that Save, Save As, undo, and external file changes behave coherently. Never overwrite an external modification without a system-mediated conflict decision.

## 8. Repository architecture

Suggested initial structure:

```text
Tessera/
  README.md
  AGENTS.md
  Tessera.xcodeproj/
  Apps/
    TesseraMac/
      TesseraApp.swift
      Documents/             # SwiftUI Document integration
      Views/                 # Window and editor composition
      Platform/              # macOS-specific input bridges
  Packages/
    TesseraCore/
      Package.swift
      Sources/TesseraCore/
        Model/               # Block and document models
        Markdown/            # Import/export codec
        Editing/             # Testable commands
      Tests/TesseraCoreTests/
    TesseraEditorUI/
      Package.swift
      Sources/TesseraEditorUI/  # Reusable SwiftUI editor views
  docs/
    specs/
      SPEC-0001-foundation-and-block-editor.md
    decisions/                # ADRs only when decisions need recording
    roadmap.md
```

`TesseraEditorUI` can initially be a target inside a shared package instead of a separate package if that simplifies builds. Do not split into many modules prematurely. Core editing functions must be unit-testable without creating a window. The macOS target owns AppKit adapters and document menus, not parsing logic.

### Recommended responsibilities

- `MarkdownCodec`: Markdown string ↔ block document, with preservation and serialization rules.
- `BlockEditorCommands`: insert, update, split, merge when safe, delete, and move.
- `EditorViewModel` or equivalent: focus state, selection, undo registration, and command dispatch, without direct persistence ownership.
- `TesseraDocument`: the platform document adapter and lifecycle integration.
- `BlockEditorView` / `BlockRowView`: reusable SwiftUI editor UI.

## 9. Testing and quality gate

Automated unit tests are required for:

1. Empty, one-paragraph, and multi-paragraph Markdown files.
2. Headings H1-H6, ordered/unordered lists, blockquotes, horizontal rules, and fenced code.
3. UTF-8 Unicode text, including Portuguese accents and emoji.
4. Source preservation for unsupported Markdown, such as a Markdown table, nested list, and inline HTML.
5. No-edit load/save round-trips, LF/CRLF endings, and trailing-newline cases.
6. Split, insert, move, delete, and safe merge operations; correct block ordering and preservation of content.
7. Reordering an opaque or code block without rewriting its contents.
8. Undo/redo of block transformations and moves (unit tests for command state plus app-level integration tests where feasible).
9. Malformed or non-UTF-8 input produces a clear error rather than silent data loss.

Manual macOS acceptance checks:

- Create a file, type multiple paragraphs, save it, close it, and reopen it.
- Open a Markdown file authored in another editor; compare content before and after saving.
- Drag a heading below a paragraph, save, and verify the order in a plain-text editor.
- Split and merge paragraphs using keyboard commands; verify caret placement and undo/redo.
- Keep two documents open; changes to one must never appear in the other.
- Check basic VoiceOver navigation, system light/dark appearances, and long-document scrolling (at least 300 simple blocks).

**Release criterion:** No known content-loss or source-destruction bugs. The app must build and launch locally on the supported macOS target, and the core test suite must pass.

## 10. Implementation sequence for Codex

Work in small independently testable slices:

1. **Bootstrap:** Initialize the repository, Xcode project, app target, Swift packages/targets, README, and tests. Confirm a blank macOS window launches.
2. **Domain model and commands:** Implement blocks, document invariants, editing commands, and tests without UI.
3. **Markdown codec:** Implement import/export, preservation behavior, and fixture-based tests. Do not continue until the codec passes its round-trip tests.
4. **Document lifecycle:** Connect the core to modern SwiftUI document infrastructure; wire New/Open/Save/Save As and multiwindow support.
5. **Editor UI:** Implement block rendering, focus, typing, split/insert/list/code behavior, and single-block drag-and-drop with a drop indicator.
6. **Undo and integration:** Connect logical edits to native undo, confirm native autosaving, and fix interoperability bugs.
7. **Release verification:** Run the automated suite, execute the manual checklist, update docs, and record known limitations.

After each slice, run available build/tests, fix errors, and commit a coherent change. If build/test execution is unavailable, explicitly report what was not verified; do not claim success.

## 11. Deliverables

- A runnable macOS Tessera application and Xcode project.
- A Markdown-capable core package with tested block operations.
- A simple usable editor and native document menu integration.
- Updated `README.md` with requirements and build/run/test instructions.
- `AGENTS.md` stating conventions for future Codex work: source-of-truth specs, minimal scope, tests before expansion, no silent data loss, and explicit build verification.
- This file checked into `docs/specs/` and a short `docs/roadmap.md`.
- A brief implementation report describing what was implemented, how it was verified, and what remains unsupported.

## 12. Rules for future specifications

Treat `SPEC-0001` as the baseline. Future changes must appear in separate, numbered specs (for example, `SPEC-0002-navigation-and-workspaces.md`, `SPEC-0003-inline-formatting.md`, or `SPEC-0004-diagrams.md`). A future spec must state **goal, scope, user interactions, data-model changes, Markdown compatibility, migration considerations, tests, and acceptance criteria**.

Keep these principles stable:

1. **Documents belong to the user:** standard Markdown interchange must always remain available.
2. **Blocks remain composable:** new types (math, chart, diagram, image) should extend the block model rather than requiring a second editor architecture.
3. **Local-first by default:** optional sync may be introduced later, never required for basic editing.
4. **Platform logic stays at the edges:** domain model and document transformations remain portable to iPadOS/iOS.
5. **Forward compatibility is explicit:** do not add hidden metadata into `.md` or create a new native format without its own migration/interchange spec.
6. **Small releases:** each spec should be independently useful, testable, and shippable.

## 13. Codex execution brief

> Implement `docs/specs/SPEC-0001-foundation-and-block-editor.md` as the first release of Tessera. Start with the foundation and model tests; build in the order specified in Section 10. Use native SwiftUI document handling on macOS 27, keep the core platform-independent, and preserve unsupported Markdown verbatim. Do not implement future-scope features. Run builds and tests after each phase, correct failures, and finish with an implementation report listing passing checks, manual checks, and remaining limitations. Where the spec leaves room for interpretation, choose the smallest data-safe behavior and document it.

## 14. References and rationale

- Apple, SwiftUI `Document` and document-based apps: https://developer.apple.com/documentation/swiftui/document
- Apple, creating a document-based app: https://developer.apple.com/documentation/swiftui/creating-a-document-based-app
- Apple, `WritableDocument` (undo registration and autosave): https://developer.apple.com/documentation/swiftui/writabledocument
- Apple, Markdown uniform type: https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/markdown
- Swift Markdown parser: https://github.com/swiftlang/swift-markdown

These references are implementation guidance; use current installed SDK signatures when writing code.
