# Tessera — SPEC-0002: Block Editor Refinements

**Version:** 0.1.2  
**Status:** Approved implementation scope  
**Date:** 2026-11-02  
**Applies to:** Tessera v0.1 block editor

## Goal

Refine block controls and keyboard editing while retaining the portable block model, native macOS text editing, drag reordering, and Markdown interoperability.

## Scope and interactions

- Hide drag and delete controls by default. Reveal them on row hover with a subtle fade, keep them visible while the pointer is within the row or controls, and show controls for only one block at a time. Preserve visibility for a keyboard-focused block action. Reserve their layout space and style icons with tertiary/secondary colors at about 40% opacity, increasing to about 85% on icon hover.
- Remove all plus controls. Insert blocks through Return.
- Return splits at the caret or selected range. Text before the range stays in the current block; selected text is removed; text after it moves to a new block. At the start/end this creates an empty block before/after. Focus and caret move to the new block's start.
- Preserve native Shift+Return line breaks. Code and opaque Markdown blocks keep their safe in-block newline behavior.
- Backspace at the start of a block merges it into a preceding block when the merge is safe. The caret moves to the exact join offset. Backspace in the first block is a no-op at the boundary.
- Up/Down arrows move between visual lines within a block. At the first or last visual line, they move keyboard focus to the preceding or following block, placing the caret at that block's end or beginning respectively. At the document boundary, normal native text-view behavior applies.
- Launch Services must not start a second Tessera instance while one is already running.
- Keep block operations in platform-independent `TesseraCore` commands. Register split, merge, move, insert, and delete as named undoable operations through the macOS undo manager.
- Preserve at least one editable paragraph when the last block is deleted.
- Keep drag reordering and deletion available to keyboard and accessibility users.

## Data and Markdown compatibility

- Split blocks retain distinct session IDs and document ordering. Merge retains the preceding block's ID.
- Serialization reflects all edits. Empty leading and trailing paragraph blocks must remain represented through save and reopen without adding private metadata to Markdown.
- Preserve untouched source, line endings, opaque blocks, and existing block content as required by SPEC-0001.

## Tests and acceptance

- Unit-test splitting at start, middle, end, and replacing a selection; list continuation; Unicode caret offsets; safe merge and first-block no-op; block ordering and IDs; empty-boundary block round-trips; and serialization after split/merge.
- Verify in macOS UI: controls reveal/hide without shifting text, Return/Backspace caret behavior, Up/Down movement across blocks, undo/redo, drag/drop, delete, and save/reopen.
- Verify that Launch Services does not create a second running process.
- Preserve light/dark appearance and VoiceOver keyboard access.

## Out of scope

No new block types, inline rich-text formatting, or proprietary persistence format is introduced by this refinement.
