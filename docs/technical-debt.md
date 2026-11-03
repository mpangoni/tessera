# Technical Debt and Design Follow-ups

## Normalize the semantic AST instead of mirroring parser structure

The current `MarkupAdapter` maps Swift Markdown nodes into `ElementNode` trees
with a general `kind`, `children`, and source range. This is a useful first
bridge, but it can preserve structural wrappers that Tessera may not need in
its own semantic model.

Examples to review:

- A heading could be represented by its level and content directly, instead of
  always containing a separate text child. The representation must still
  support inline formatting such as links, emphasis, and strong text inside a
  heading.
- A list item may be able to contain inline text and decorations directly.
  Paragraph nodes should remain where they express meaningful block structure,
  such as multiple paragraphs or nested blocks within one list item.

Before changing the model, define which distinctions matter to editing,
rendering, and Markdown encoding. Then normalize the adapter output and update
the editor and codec together. Preserve source ranges, inline formatting,
multi-paragraph list items, and Markdown round-tripping in the migration tests.

## Decide how semantic properties and metadata belong on nodes

`ElementPayload` was removed when Markdown text moved to source ranges. This
keeps source-backed text compact, but leaves `ElementNode` without a general
place for properties that are not represented by its kind, children, or source
range.

Future node types may need structured values such as table alignment, equation
options, chart configuration, diagram settings, or custom attributes. Revisit
this before those types are implemented. Prefer typed, extensible properties
with clear ownership and serialization rules; avoid putting ordinary text back
into per-node payloads when it can remain in the source snapshot.
