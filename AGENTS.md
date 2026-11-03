# Tessera contributor guidance

- Treat numbered specifications in `docs/specs/` as the product source of truth. Implement only the scope in the applicable accepted specification.
- Keep document models, Markdown conversion, and edit commands platform independent. Put SwiftUI/AppKit and file lifecycle code at the app edges.
- Preserve Markdown source, unsupported constructs, line endings, and trailing newlines. Never trade data integrity for a convenient transformation; choose a safe no-op/raw representation when uncertain.
- Make edits through testable commands. Add focused tests for each behavior before expanding the implementation.
- After each implementation phase, run the available build and tests and record unavailable checks honestly. Do not claim SDK or manual validation that was not performed.
- Keep future block types additive and avoid proprietary metadata or persistence formats.
- Do not commit changes automatically. Commit only when the user explicitly asks for a commit.
- For every commit made by AI Agent, add a Git note to that commit identifying it as a AI Agent commit, naming the model that produced the code, and briefly describing the committed change. Do not rewrite commit history to attach a note; use `git notes add` on the commit.
