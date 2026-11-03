# Tessera

**A local-first Personal Operating System for knowledge, work, and life.**

Tessera is an open-source, native Apple application project exploring a simple idea: **our documents, projects, research, plans, and daily activities should work together, even when they live in different applications and storage systems.**

The long-term vision is a personal environment to **capture information, develop knowledge, organize work, create content, and act on commitments**—without surrendering ownership of the underlying data.

Tessera is also a public engineering project: a place to explore and demonstrate the architecture and execution of a complex, real-world software system.

> **Project status — v0.1.2 (early prototype).** Tessera currently implements a native macOS Markdown editor with block and raw-text editing modes. The broader Personal Operating System described below is a **vision and proposed direction, not an implemented feature set**. This release is experimental and unstable.

## Why Tessera?

A typical project is spread across a Git repository, local folders, cloud drives, documentation tools, diagrams, messages, calendars, and task managers. Personal goals—such as learning a language, reading, writing, or building new skills—are fragmented in much the same way.

The problem is not merely finding files. It is preserving **context**:

- What was collected, and why?
- Which idea, requirement, decision, or project does it support?
- How did the knowledge evolve?
- What needs to be done next, by whom, and when?
- How can the result become a specification, article, diagram, report, or other useful output?

Tessera aims to connect these questions through a unified workspace, rather than replace every application that already answers part of them.

## Two complementary ways to work

Tessera draws inspiration from **CODE** and **PARA**:

| Method | Purpose | In Tessera |
| --- | --- | --- |
| **CODE** — Capture, Organize, Distill, Express | A knowledge lifecycle | Collect sources, connect them to context, extract reusable ideas, and create something from them |
| **PARA** — Projects, Areas, Resources, Archives | A practical organizational model | Navigate active outcomes, ongoing responsibilities, reference material, and completed work |

They serve different purposes: **CODE describes how knowledge develops; PARA describes how information and work can be organized.** Neither should dictate the physical location of a file.

A software project might combine source code, requirements, architecture decisions, diagrams, issues, and delivery reminders. An English-learning project might combine books, notes, exercises, distilled grammar concepts, and recurring practice activities. Both belong in the same system.

For structured engineering work, Tessera also intends to support methodologies such as the **Unified Process**, including requirements, architecture decisions, iterations, and traceability.

## Product vision

Tessera is conceived as a **Personal Operating System (pOS)** built around five architectural layers:

\`\`\`mermaid
flowchart TB
    POS["1. Personal Operating System<br/>Goals · Learning · Agenda · Projects · Communication"]
    KM["2. Knowledge & Work Management<br/>CODE · PARA · Unified Process · Workflows"]
    VFS["3. Virtual Filesystem & Entity Model<br/>Identity · Content · Relationships · Permissions · Provenance"]
    subgraph SERVICES["4. Shared Capabilities"]
        IH["Index & History<br/>Search · Vectors · Graph · Versions"]
        CO["Connectors<br/>Local files · Git · Cloud · Apps"]
        TO["Workbench Tools<br/>Editors · PDF · Diagrams · Data · Visualization"]
    end
    AI["5. Intelligence & Automation Gateway<br/>MCP · Local models · Cloud AI · Agents"]

    POS <--> KM
    KM <--> VFS
    VFS <--> IH
    VFS <--> CO
    VFS <--> TO
    VFS <--> AI
\`\`\`

This diagram is a **conceptual architecture**, not a map of modules already implemented.

### A federated workspace

Tessera should present a **logical view of resources** while respecting where they actually live: local directories, Git checkouts, iCloud, OneDrive, Craft, and other supported providers.

A virtual project could reference a document in one provider, a diagram in another, and a task in a third—without copying all three into a proprietary vault.

The proposed core distinguishes:

- **Entities:** stable identities for documents, projects, requirements, concepts, tasks, and other resources.
- **Content:** document structure, text, blocks, media, and format-specific representations.
- **Relationships:** references, dependencies, provenance, and semantic associations.
- **Activities:** actions, reminders, schedules, and external operations.

Paths are ways to navigate resources; they are not the only way to identify them. The underlying content should remain usable with other applications.

### A connected workbench

Tessera is intended to become a place to **do the work**, not only index it. Proposed tools include:

| Tool | Intended use |
| --- | --- |
| **Document editor** | Markdown-first writing for specifications, research, articles, and stories |
| **PDF workspace** | Read, search, annotate, and reference documents |
| **Diagram studio** | Architecture, UML, entity-relationship, and flow diagrams |
| **Data explorer** | Tables, charts, and structured-data inspection |
| **Knowledge graph** | Explore documents, concepts, projects, and their relationships |
| **Publishing tools** | Prepare portable documents, reports, and articles for external platforms |

Tools should share resource identity, references, search, and permissions while remaining free to use specialized internal models. In particular, a document AST is useful for editing and conversion, but it should not become the universal model for tasks, repositories, or calendar events.

### Discovery and knowledge history

The proposed discovery pipeline would scan authorized sources, extract supported content and metadata, build full-text and semantic indexes, and suggest related resources.

**Semantic similarity is a suggestion, not proof of a relationship.** Tessera should distinguish explicit links and verified associations from relationships inferred by an algorithm.

Git is a candidate for versioned **knowledge artifacts, manifests, and publication snapshots**, not a requirement to store every discovered file in Git. Large index snapshots could use object storage. The system should preserve source provenance, revisions, and the ability to resolve references back to their original content.

### Native Apple experience

The primary platform is **macOS**, using Swift and native Apple frameworks. The architecture is intended to leave room for future iPad, iPhone, and Apple Watch experiences.

Native integrations could connect workspaces with Apple Reminders and Calendar. Heavier indexing and authoring may remain on the Mac while companion devices support capture, review, and timely actions.

### Intelligence, without dependency on AI

Tessera should be useful without a generative AI service. Local indexing, search, explicit relationships, and ordinary editing must work independently.

In later stages, an **MCP server and controlled APIs** could let local models or cloud assistants retrieve project context, propose organizational changes, review documentation, and automate approved actions. Reading context and taking consequential actions—such as editing files, sending email, or publishing data—must be separate, permission-controlled capabilities.

## What works today

**v0.1.2** focuses deliberately on one foundation: a portable, native Markdown editing experience.

Implemented capabilities include:

- A macOS document-based application with native New/Open/Save/Save As behavior.
- A **block editor** and a **raw Markdown editor** for the same document.
- A Swift package, \`TesseraCore\`, containing the block model, Markdown codec, and testable editing commands.
- Block insertion, splitting, safe merging, deletion, movement, and keyboard-oriented editing behavior.
- Basic headings, paragraphs, lists, blockquotes, horizontal rules, and fenced code blocks.
- Preservation of unsupported or complex Markdown through opaque/raw blocks rather than silent data loss.
- Source-preserving no-edit round trips, with defined limitations after supported blocks are modified.
- Unit tests for core document operations and Markdown handling.

**Not implemented in v0.1.2:** the federated virtual filesystem, PARA workspaces, semantic search, embeddings, graph viewer, PDF/diagram/data tools, external connectors, distributed knowledge synchronization, MCP, or AI agents.

See the [implementation report](docs/implementation-report.md) for validation results and known gaps. The current implementation is **not production-ready**.

## Technology and repository

The present application uses **Swift, SwiftUI, AppKit bridges, and native macOS document APIs**. The platform-independent document logic lives in a separate Swift package.

\`\`\`text
Tessera/
├── Apps/                  # Native macOS application
├── Packages/TesseraCore/  # Models, Markdown codec, edit commands, tests
├── Tessera.xcodeproj/     # Xcode project
├── docs/
│   ├── specs/             # Numbered product specifications
│   ├── roadmap.md         # Accepted implementation roadmap
│   └── implementation-report.md
├── Samples/               # Sample Markdown documents
└── AGENTS.md              # Contributor and coding-agent guidance
\`\`\`

The larger architecture above is an intended evolution. It does **not** imply those services or packages already exist.

### Requirements

- **macOS 26.5 or later**
- **Xcode 26.6 / Swift 6.3**

### Build and test

Open \`Tessera.xcodeproj\` in Xcode and run the **Tessera** scheme.

Or use the command line:

\`\`\`sh
swift test --package-path Packages/TesseraCore
xcodebuild -project Tessera.xcodeproj -scheme Tessera -destination 'platform=macOS' build
\`\`\`

The [implementation report](docs/implementation-report.md) records tests and checks performed for v0.1.2, along with verification still needed. The commands above have **not** been rerun as part of this README update.

### Try a sample document

Open [Alice's Adventures in Wonderland](Samples/Alice/Alice-in-Wonderland.md) or the [Markdown basic syntax reference](Samples/Markdown/Markdown-Basic-Syntax-Reference.md) with Tessera.

## Development direction

The following are **exploration themes**, not release commitments:

1. **Editing foundation** — improve native block editing, Markdown fidelity, accessibility, and document reliability.
2. **Discovery and organization** — index existing directories, build search, and introduce project/area/resource views with stable resource identities.
3. **Knowledge modeling** — semantic retrieval, relationship management, provenance, knowledge graphs, and versioned knowledge snapshots.
4. **Integrated workbench** — richer document authoring, PDF reading, diagrams, charts, and other native tools.
5. **Personal workflows and integrations** — activities, reminders, calendars, communication, providers, and secure synchronization.
6. **Intelligence gateway** — controlled MCP/API access, local and cloud model integration, and agent-assisted workflows.

Implementation changes are governed by numbered specifications rather than this vision document. See [the roadmap](docs/roadmap.md) and [foundation specification](docs/specs/SPEC-0001-foundation-and-block-editor.md).

## Local-first, privacy, and security

Tessera is intended to **own the context, not necessarily the content**. Documents should stay in user-controlled locations; external access should be optional and explicit.

Design requirements for future storage, synchronization, and AI integrations include:

- Local operation without requiring an account or remote AI service.
- Least-privilege provider access and user-approved external actions.
- Clear boundaries between private data, shared data, and public knowledge artifacts.
- Encryption and key management for any future sensitive remote snapshots.
- Provenance and explicit publication controls for indexed or transformed data.

**Embeddings are not anonymization.** A vector derived from sensitive text may still leak information about that text. Private embeddings should not be made public simply because their source documents remain local. Remote vector storage requires an appropriate threat model, access controls, and protection.

These are architectural **intentions and requirements**, not claims that encryption, remote access control, or secure sync already exist in the prototype.

## An open engineering project

Tessera has a second mission: to make the engineering of a substantial software system visible.

Beyond a working application, the project aims to document **why** architectural decisions are made and **how** their tradeoffs are evaluated. Topics include:

- Modular architecture and domain boundaries.
- Document parsing, ASTs, conversion, and interoperability.
- Data catalogs, ingestion, indexing, lineage, and graph models.
- Federated resources, synchronization, and consistency.
- Authentication, authorization, encryption, and key management.
- Native performance, usability, automated testing, and observability.
- Semantic retrieval, MCP, AI-agent interfaces, and safe automation.

Where appropriate, features should be accompanied by specifications, architecture decision records, tests, benchmarks, and reproducible demonstrations. This repository is intended to show **engineering work and evidence**, not simply a catalog of technologies.

Contributions and constructive feedback are welcome. Before proposing implementation changes, please read [AGENTS.md](AGENTS.md) and the applicable specifications under [docs/specs/](docs/specs/).

## License

The Tessera source code is offered under the **GNU General Public License, version 3 or any later version (GPL-3.0-or-later)**. See [LICENSE](LICENSE).

A separate commercial license may be obtained by written agreement with the copyright holder, **Marcos Augusto Pangoni** (\`marcos@pangoni.com.br\`). This dual-licensing notice applies to the Tessera source code. Sample documents and third-party materials retain their own notices and licenses; for example, the [Alice sample](Samples/Alice/Alice-in-Wonderland.md) includes its Project Gutenberg notice.

---

**Tessera is starting with a Markdown editor. Its destination is a connected, extensible, user-owned personal workspace.**
