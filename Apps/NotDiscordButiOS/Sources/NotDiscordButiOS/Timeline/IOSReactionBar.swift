import DiscordKit
import SwiftUI

struct IOSReactionBar: View {
    let reactions: [DiscordMessageReaction]
    let message: DiscordMessage
    let guildID: GuildID?

    @Environment(IOSAppModel.self) private var model
    @State private var showingReactionPicker = false

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(reactions, id: \.emoji) { reaction in
                reactionPill(reaction)
            }

            addReactionButton
        }
    }

    private func reactionPill(_ reaction: DiscordMessageReaction) -> some View {
        Button {
            Task {
                try? await model.toggleReaction(
                    for: message,
                    emoji: reaction.emoji,
                    guildID: guildID
                )
            }
        } label: {
            HStack(spacing: 3) {
                Text(reaction.emoji.name)
                    .font(.caption)
                Text("\(reaction.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(reaction.me ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
            )
            .overlay(
                Capsule()
                    .strokeBorder(reaction.me ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var addReactionButton: some View {
        Button {
            showingReactionPicker = true
        } label: {
            Image(systemName: "face.smiling")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.gray.opacity(0.2)))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingReactionPicker) {
            ReactionPickerSheet(message: message, guildID: guildID)
        }
    }
}

struct ReactionPickerSheet: View {
    let message: DiscordMessage
    let guildID: GuildID?

    @Environment(IOSAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                    ForEach(filteredEmojis) { option in
                        Button {
                            Task {
                                let emoji = DiscordReactionEmoji(id: nil, name: option.emoji, animated: false)
                                try? await model.toggleReaction(
                                    for: message,
                                    emoji: emoji,
                                    guildID: guildID
                                )
                                dismiss()
                            }
                        } label: {
                            Text(option.emoji)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Add Reaction")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $searchText, prompt: "Search emoji")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
    }

    private var filteredEmojis: [UnicodeReactionOption] {
        ReactionPalette.unicodeOptions.filter { $0.matches(searchText: searchText) }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() where index < subviews.count {
            subviews[index].place(at: CGPoint(
                x: bounds.minX + position.x,
                y: bounds.minY + position.y
            ), proposal: .unspecified)
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions = [CGPoint]()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return LayoutResult(
            size: CGSize(width: maxX, height: y + rowHeight),
            positions: positions
        )
    }
}
