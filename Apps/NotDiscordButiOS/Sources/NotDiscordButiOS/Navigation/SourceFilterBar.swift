import SwiftUI

struct SourceFilterBar: View {
    @Binding var selected: FilterMode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selected = mode
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mode.systemImage)
                                .font(.caption2)
                            Text(mode.label)
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selected == mode ? Color.accentColor : Color.gray.opacity(0.2))
                        )
                        .foregroundStyle(selected == mode ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}
