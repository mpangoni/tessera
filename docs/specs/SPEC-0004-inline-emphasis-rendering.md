# SPEC-0004: Inline Emphasis Rendering

## Goal

Make bold and italic Markdown easier to scan in the block editor while keeping Markdown as the editable and saved source.

## Scope

- Visually style the text covered by `**bold**`, `__bold__`, `*italic*`, `_italic_`, and combined `***bold italic***` / `___bold italic___` markers.
- Suppress the visual `*` and `_` delimiters in the block editor while retaining them in the underlying text and saved Markdown.
- Keep the raw Markdown editor as the direct way to inspect and edit the delimiter characters.
- Do not rewrite document content or add rich-text metadata; save and reopen must preserve the same Markdown source.
- Leave escaped markers, inline code, fenced code, and opaque raw Markdown unstyled.
- Apply the parser in platform-independent Core code; apply native font attributes in the macOS editor.
- Keep each inline decoration matcher as an independent Core implementation so new styles can be added without changing block editing or source storage.
- Recognize basic inline links and style the visible label while suppressing the surrounding link syntax in block view. Preserve the destination and delimiters in the source; raw Markdown mode remains the way to edit them.

## Acceptance criteria

- [ ] Bold and italic spans receive their matching font traits in paragraph-like blocks.
- [ ] Combined bold-italic spans receive both traits.
- [ ] Emphasis delimiters are not visible in the block editor.
- [ ] Markdown delimiters remain in the model and are serialized unchanged.
- [ ] Escaped delimiters and emphasis markers inside inline code are not styled.
- [ ] Unicode source ranges point to the correct characters.
- [ ] Bold, italic, and link decorations can be matched independently by the Core API.
- [ ] Inline links style only their labels and retain destinations and syntax in the source.
- [ ] Existing block editing and Markdown source-preservation behavior remains intact.

## Validation

- Unit-test detected emphasis ranges, combined and nested emphasis, escaped markers, inline code, underscore word boundaries, and Unicode offsets.
- Build the macOS app to verify attributed styles integrate with the native text view.
