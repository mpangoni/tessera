import SwiftUI
import TesseraCore
import UniformTypeIdentifiers

struct EditorView: View {
    @Binding var document: TesseraDocument
    @State private var blocks: [TesseraBlock] = []
    @State private var originalSource: String?
    @State private var dropTarget: UUID?
    @State private var lastPublished = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(blocks) { block in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 6)
                        TextField("", text: contentBinding(for: block), axis: .vertical)
                            .font(font(for: block.kind))
                            .textFieldStyle(.plain)
                        Button { add(after: block.id) } label: { Image(systemName: "plus.circle") }
                            .buttonStyle(.plain)
                            .help("Add paragraph below")
                        Button { remove(block.id) } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .help("Delete block")
                    }
                    .padding(.vertical, 4)
                    .background(dropTarget == block.id ? Color.accentColor.opacity(0.12) : .clear)
                    .draggable(block.id.uuidString)
                    .dropDestination(for: String.self) { values, _ in
                        guard let value = values.first, let movingID = UUID(uuidString: value), movingID != block.id,
                              let destination = blocks.firstIndex(where: { $0.id == block.id }) else { return false }
                        var model = BlockDocument(blocks: blocks, hasBeenEdited: true)
                        do {
                            try BlockEditorCommands.move(id: movingID, to: destination, in: &model)
                            blocks = model.blocks
                            dropTarget = nil
                            publish()
                            return true
                        } catch { return false }
                    } isTargeted: { targeted in
                        dropTarget = targeted ? block.id : (dropTarget == block.id ? nil : dropTarget)
                    }
                }
                Button("Add paragraph") { add(after: blocks.last?.id) }
                    .buttonStyle(.borderless)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: load)
        .onChange(of: document.markdown) { _, value in
            if value != lastPublished { load() }
        }
    }

    private func font(for kind: BlockKind) -> Font {
        switch kind {
        case .heading(let level): .system(size: max(16, 30 - Double(level * 2)), weight: .semibold)
        case .fencedCode: .system(.body, design: .monospaced)
        default: .body
        }
    }

    private func load() {
        let model = MarkdownCodec.decode(document.markdown)
        blocks = model.blocks.isEmpty ? [TesseraBlock(kind: .paragraph, content: "")] : model.blocks
        originalSource = model.originalSource
        lastPublished = document.markdown
    }

    private func publish() {
        var model = BlockDocument(blocks: blocks, originalSource: originalSource, hasBeenEdited: true)
        model.lineEnding = document.markdown.contains("\r\n") ? "\r\n" : "\n"
        document.markdown = MarkdownCodec.encode(model)
        lastPublished = document.markdown
        originalSource = nil
    }

    private func remove(_ id: UUID) {
        var model = BlockDocument(blocks: blocks, hasBeenEdited: true)
        do {
            _ = try BlockEditorCommands.delete(id: id, in: &model)
            blocks = model.blocks
            publish()
        } catch { assertionFailure("Could not remove block: \(error)") }
    }

    private func contentBinding(for block: TesseraBlock) -> Binding<String> {
        Binding(
            get: { blocks.first(where: { $0.id == block.id })?.content ?? "" },
            set: { value in
                var model = BlockDocument(blocks: blocks, hasBeenEdited: true)
                do {
                    try BlockEditorCommands.update(id: block.id, content: value, in: &model)
                    blocks = model.blocks
                    publish()
                } catch { assertionFailure("Could not update block: \(error)") }
            }
        )
    }

    private func add(after id: UUID?) {
        var model = BlockDocument(blocks: blocks, hasBeenEdited: true)
        let index = id.flatMap { key in blocks.firstIndex(where: { $0.id == key }) }.map { $0 + 1 } ?? blocks.count
        do {
            _ = try BlockEditorCommands.insert(TesseraBlock(kind: .paragraph, content: ""), at: index, in: &model)
            blocks = model.blocks
            publish()
        } catch { assertionFailure("Could not insert block: \(error)") }
    }
}
