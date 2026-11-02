# Tessera — SPEC-0003: Dual Markdown Editing Views

**Version:** 0.1.2
**Status:** Approved implementation scope
**Date:** 2026-11-02
**Applies to:** Tessera macOS document editor

## Goal

Let users edit one Markdown document either as blocks or as raw Markdown, with a small native view switch in the document's top navigation area.

## Scope and interactions

- Add a compact segmented switch at the top of the document view with **Blocks** and **Raw Markdown** options.
- Keep the bottom navigation area empty in this release.
- Raw Markdown mode edits the document's UTF-8 Markdown text directly in a native text editor.
- Both editing modes use the same document value and the existing native document save, reopen, and unsaved-change behavior.
- When returning to Blocks mode after raw edits, refresh the block model from the edited Markdown.
- Keep the raw view plain text with monospaced system font; do not add preview, rich-text formatting, or a second persistence format.

## Acceptance

- The top switch changes between block and raw Markdown editing without opening another window or document.
- Text changed in raw mode appears when switching to block mode.
- Block edits appear in raw mode and retain normal Markdown serialization.
- Raw edits save and reopen through the existing Markdown document workflow.
- The bottom navigation area contains no controls.
