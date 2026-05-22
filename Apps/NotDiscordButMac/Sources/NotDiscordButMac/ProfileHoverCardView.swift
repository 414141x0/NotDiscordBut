import DiscordKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ProfileHoverController {
    var isPresented = false

    @ObservationIgnored
    private let showDelay: Duration

    @ObservationIgnored
    private let hideDelay: Duration

    @ObservationIgnored
    private var showTask: Task<Void, Never>?

    @ObservationIgnored
    private var dismissTask: Task<Void, Never>?

    @ObservationIgnored
    private var avatarHovered = false

    @ObservationIgnored
    private var cardHovered = false

    init(
        showDelay: Duration = .seconds(1),
        hideDelay: Duration = .milliseconds(220)
    ) {
        self.showDelay = showDelay
        self.hideDelay = hideDelay
    }

    deinit {
        showTask?.cancel()
        dismissTask?.cancel()
    }

    func enterAvatar() {
        avatarHovered = true
        dismissTask?.cancel()

        guard !isPresented else {
            return
        }

        showTask?.cancel()
        if showDelay == .zero {
            isPresented = true
            return
        }
        showTask = Task { [showDelay] in
            try? await Task.sleep(for: showDelay)
            guard !Task.isCancelled, avatarHovered else {
                return
            }
            isPresented = true
        }
    }

    func exitAvatar() {
        avatarHovered = false
        showTask?.cancel()
        scheduleDismissIfNeeded()
    }

    func enterCard() {
        guard isPresented else {
            return
        }
        cardHovered = true
        dismissTask?.cancel()
    }

    func exitCard() {
        cardHovered = false
        scheduleDismissIfNeeded()
    }

    private func scheduleDismissIfNeeded() {
        guard isPresented, !avatarHovered, !cardHovered else {
            return
        }

        dismissTask?.cancel()
        dismissTask = Task { [hideDelay] in
            try? await Task.sleep(for: hideDelay)
            guard !Task.isCancelled, !avatarHovered, !cardHovered else {
                return
            }
            isPresented = false
        }
    }
}

struct ProfileHoverCardView: View {
    let user: DiscordUser
    let projection: UserInspectorProjection?
    let onOpenInspector: () -> Void

    var body: some View {
        let displayName = projection?.guildMember?.nickname ?? user.displayName
        let accent = Color(discordAccent: projection?.displayAccentColor ?? projection?.profile?.accentColor ?? user.accentColor)

        VStack(alignment: .leading, spacing: 0) {
            DiscordBannerView(
                url: DiscordCDN.userBannerURL(
                    userID: user.id,
                    bannerHash: projection?.profile?.bannerHash ?? user.bannerHash,
                    size: 640
                ),
                height: 84,
                accentColor: accent
            )
            .overlay(alignment: .bottomLeading) {
                DiscordAvatarView(user: user, size: 58)
                    .padding(.leading, 16)
                    .offset(y: 26)
            }
            .padding(.bottom, 30)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Button(action: onOpenInspector) {
                        Text(displayName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)

                    Text(user.tag)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let pronouns = projection?.profile?.pronouns, !pronouns.isEmpty {
                        Text(pronouns)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let roles = projection?.resolvedRoles, !roles.isEmpty {
                    ProfileRoleGridView(roles: Array(roles.prefix(4)), compact: true)
                }

                if let bio = projection?.profile?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }

                if let projection {
                    ProfileMutualSummaryView(projection: projection)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 320, alignment: .leading)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.thinMaterial)
        }
    }
}

private struct ProfileMutualSummaryView: View {
    let projection: UserInspectorProjection

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !projection.mutualGuilds.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(projection.mutualGuilds.count) mutual server\(projection.mutualGuilds.count == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(projection.mutualGuilds.prefix(3).map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !projection.mutualFriends.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(projection.mutualFriends.count) mutual friend\(projection.mutualFriends.count == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(projection.mutualFriends.prefix(3).map(\.displayName).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct ProfileRoleGridView: View {
    let roles: [DiscordGuildRole]
    var compact = false

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: compact ? 88 : 108), spacing: 8, alignment: .leading)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(roles, id: \.id) { role in
                Text(role.name)
                    .font(compact ? .caption.weight(.medium) : .callout.weight(.medium))
                    .foregroundStyle(Color(discordAccent: role.color))
                    .padding(.horizontal, 10)
                    .padding(.vertical, compact ? 5 : 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous)
                            .fill(Color(discordAccent: role.color).opacity(compact ? 0.14 : 0.16))
                    )
            }
        }
    }
}
