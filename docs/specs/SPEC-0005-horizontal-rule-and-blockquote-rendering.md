# SPEC-0005: Horizontal Rule and Blockquote Rendering

## Goal

Give horizontal rules and blockquotes recognizable block-level visuals in the block editor while preserving standard Markdown in the document.

## Scope

- Render `---`, `***`, and `___` horizontal-rule blocks as a subtle horizontal line.
- Render blockquote content with a subtle leading quote bar and indentation; do not show the `>` marker in block view.
- Keep the original Markdown source and block model unchanged. Raw Markdown mode continues to show and edit the syntax.
- Keep horizontal-rule rows in the document order and available to existing drag and delete controls.
- Do not change Markdown parsing or serialization rules.

## Acceptance criteria

- [ ] All three supported horizontal-rule spellings render as a horizontal line in block view.
- [ ] Blockquotes use a quote bar and inset text in block view.
- [ ] Untouched source retains its original spelling and quote markers after save.
- [ ] Raw Markdown mode continues to expose the source syntax.
- [ ] Existing block focus, drag, delete, and document ordering remain available.

## Validation

- Run the Core Markdown codec tests for horizontal-rule and blockquote recognition and source preservation.
- Build the macOS app to validate native and SwiftUI rendering integration.
