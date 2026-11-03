# ADR-0001: Separate Platform Document Handling from Content Formats

- **Status:** Accepted
- **Date:** 2026-11-03

## Context

Tessera currently opens and saves Markdown files. The macOS app uses
`MarkdownDocument`, a SwiftUI `FileDocument`, to participate in the native
document lifecycle. The content model and Markdown conversion live in
`TesseraCore`.

The editor will author documents directly as Tessera's semantic AST. A new
empty document will start with an empty AST and an in-memory source, rather than
being initialized by parsing an empty Markdown file. The AST may contain
Tessera-specific semantic content and metadata that Markdown cannot express,
including future diagrams, equations, charts, and richer node properties.

Markdown and other document formats are inputs and outputs handled by codecs.
Tessera is also expected to gain a native persistent format for saving its
complete semantic document model.

## Decision

Keep platform file handling and content-format conversion as separate layers:

- `Platform/Document` contains platform-specific file lifecycle adapters such
  as the current `MarkdownDocument`.
- `TesseraCore/Content` owns the format-neutral content artifact and AST.
- `TesseraCore/Services` owns format codecs such as `MarkdownCodec` and, in the
  future, a native Tessera codec.
- The current `MarkdownDocument` remains the macOS adapter for Markdown files;
  it is not Tessera's permanent domain document model.
- Editor-created documents begin as a Tessera AST backed by an in-memory source.
  Their meaning and structure do not depend on a Markdown AST or Markdown
  source snapshot.
- Markdown and other format codecs translate between the Tessera AST and each
  format. Exporting must not make the exported format the editor's canonical
  in-memory model.
- When the native format is designed, add a distinct native-format codec and
  document-file adapter. Do not make Tessera-specific data depend on Markdown
  syntax or silently change the meaning of existing `.md` files.

The native format's file extension, on-disk serialization, versioning scheme,
and import/export workflow remain open decisions. They will be decided when
the native format is specified.

## Consequences

- Core AST and editing code can remain independent of SwiftUI, AppKit, and
  `FileDocument`.
- New documents can use Tessera's own semantic structure from the first edit,
  without a Markdown parse/serialize cycle.
- Markdown remains a portable import/export format with its own source
  preservation and encoding behavior.
- Tessera's native format can represent semantic content and metadata that do
  not have a Markdown equivalent.
- The app may eventually support more than one document file type, but the
  appropriate `DocumentGroup` and file-type registration design is deferred.

## Follow-up

Design an editable `MemorySource` and define how node ranges are updated as
users edit text. The current `SourceSnapshot` represents immutable input bytes
and does not yet provide mutable source storage. Also specify the native format's
AST encoding, metadata ownership, schema versioning and migration behavior, and
Markdown import/export rules. Then add codec round-trip and file lifecycle
contracts for each supported format.
