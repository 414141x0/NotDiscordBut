import DiscordKit
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class IOSAppModel {
    struct HydratedProfileKey: Hashable {
        var userID: UserID
        var guildID: GuildID?
    }

    let client: DiscordClient
    let launchProfile: AppLaunchProfile
    let authFlow: AuthFlowModel
    let settings: SettingsModel
    let timeline = TimelineModel()
    let composer = ComposerModel()

    var phase: AppPhase = .launching
    var statusMessage = "Bootstrapping NotDiscordBut…"
    var sidebarProjection = SidebarProjection(guilds: [], privateChannels: [])
    var channelListProjection = ChannelListProjection(guildID: nil, channels: [])
    var filterMode: FilterMode = .all
    var selectedSource: WorkspaceSelection?
    var selectedGuildChannelID: ChannelID?
    var selectedDirectMessageChannelID: ChannelID?
    var profileSheetUserID: UserID?
    var profileSheetProjection: UserInspectorProjection?
    var messageSearchText = ""
    var navigationPath = [IOSNavigationDestination]()

    @ObservationIgnored
    private var hasBootstrapped = false

    @ObservationIgnored
    private var storeObservationTask: Task<Void, Never>?

    @ObservationIgnored
    private var selectionTask: Task<Void, Never>?

    @ObservationIgnored
    private var messageSearchTask: Task<Void, Never>?

    @ObservationIgnored
    private var restoreRefreshTask: Task<Void, Never>?

    @ObservationIgnored
    private var liveRefreshTask: Task<Void, Never>?

    @ObservationIgnored
    private var latestSnapshot = NormalizedState.empty

    @ObservationIgnored
    private var hydratedGuildIDs = Set<GuildID>()

    @ObservationIgnored
    private var hydratedChannelIDs = Set<ChannelID>()

    @ObservationIgnored
    private var hydratedUserProfiles = Set<HydratedProfileKey>()

    @ObservationIgnored
    private var recentSelectionSnapshots: [String: RecentSelectionSnapshot] = [:]

    @ObservationIgnored
    private var collapsedCategoryIDsByGuildID = [GuildID: Set<ChannelID>]()

    @ObservationIgnored
    private let logger = Logger(subsystem: "disc.notdiscordbut.ios", category: "app")

    @ObservationIgnored
    private let defaults = UserDefaults.standard

    init(
        client: DiscordClient,
        launchProfile: AppLaunchProfile,
        runtimeNotice: String? = nil,
        authFlow: AuthFlowModel = AuthFlowModel(),
        settings: SettingsModel = SettingsModel()
    ) {
        self.client = client
        self.launchProfile = launchProfile
        self.authFlow = authFlow
        self.settings = settings
        self.settings.launchProfileLabel = launchProfile.label
        self.settings.runtimeNotice = runtimeNotice
        self.recentSelectionSnapshots = Self.loadRecentSelectionSnapshots(from: defaults)
    }

    convenience init() {
        let profile = AppLaunchProfile.current()
        switch profile {
        case .preview:
            self.init(client: .preview(), launchProfile: .preview)
        case .live:
            let supportURL = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0].appending(path: "NotDiscordBut")
            let configuration = DiscordConfiguration(applicationSupportURL: supportURL)

            do {
                let client = try DiscordClient.live(configuration: configuration)
                self.init(client: client, launchProfile: .live)
            } catch {
                let client = DiscordClient.ephemeral(configuration: configuration)
                self.init(
                    client: client,
                    launchProfile: .live,
                    runtimeNotice: "Persistent client startup failed, so the app is using a transient local store: \(error)"
                )
            }
        }
    }

    deinit {
        storeObservationTask?.cancel()
        selectionTask?.cancel()
        restoreRefreshTask?.cancel()
        liveRefreshTask?.cancel()
    }

    // MARK: - Computed Properties

    var people: [WorkspacePerson] {
        filteredPeople(matching: "")
    }

    var guilds: [DiscordGuild] {
        filteredGuilds(matching: "")
    }

    var isGuildMode: Bool {
        selectedSource?.guildID != nil
    }

    var selectedGuild: DiscordGuild? {
        guard let guildID = selectedSource?.guildID else {
            return nil
        }
        return latestSnapshot.guilds[guildID.rawValue]
    }

    var selectedPerson: WorkspacePerson? {
        guard let userID = selectedSource?.userID else {
            return nil
        }
        return workspacePeople().first { $0.user.id == userID }
    }

    var selectedChannel: DiscordChannel? {
        timeline.selectedChannel
    }

    var reactionPickerGuildEmojis: [DiscordGuildEmoji] {
        client.state.guildEmojiInventoryProjection(for: selectedSource?.guildID, from: latestSnapshot)?.emojis ?? []
    }

    var guildChannelSections: [GuildChannelSectionModel] {
        GuildChannelSectionModel.makeSections(
            from: channelListProjection.channels,
            collapsedCategoryIDs: currentCollapsedCategoryIDs
        )
    }

    var recentSelections: [RecentSelectionEntry] {
        recentSelectionSnapshots.values
            .filter { $0.accessCount >= 2 }
            .sorted { lhs, rhs in
                if lhs.lastAccessDate != rhs.lastAccessDate {
                    return lhs.lastAccessDate > rhs.lastAccessDate
                }
                return lhs.selection.persistenceKey < rhs.selection.persistenceKey
            }
            .prefix(4)
            .compactMap(resolveRecentSelection)
    }

    var mentionedGuilds: [DiscordGuild] {
        let guildIDsWithMentions = Set(
            latestSnapshot.readStates.values
                .filter { $0.mentionCount > 0 }
                .compactMap { readState -> GuildID? in
                    latestSnapshot.channels[readState.channelID.rawValue]?.guildID
                }
        )
        return sidebarProjection.guilds.filter { guildIDsWithMentions.contains($0.id) }
    }

    var filteredSourceItems: [SourceStripItem] {
        switch filterMode {
        case .all:
            let friendItems = people.map { SourceStripItem.friend($0) }
            let guildItems = guilds.map { SourceStripItem.guild($0) }
            return friendItems + guildItems
        case .friends:
            return people.map { SourceStripItem.friend($0) }
        case .servers:
            return guilds.map { SourceStripItem.guild($0) }
        case .recent:
            return recentSelections.map { entry in
                if let user = entry.user {
                    return SourceStripItem.friend(WorkspacePerson(user: user))
                } else if let guild = entry.guild {
                    return SourceStripItem.guild(guild)
                }
                return nil
            }.compactMap { $0 }
        case .mentioned:
            return mentionedGuilds.map { SourceStripItem.guild($0) }
        }
    }

    func channelHasMentions(_ channelID: ChannelID) -> Bool {
        guard let readState = latestSnapshot.readStates[channelID.rawValue] else {
            return false
        }
        return readState.mentionCount > 0
    }

    // MARK: - Bootstrap & Auth

    func bootstrap() async {
        guard !hasBootstrapped else {
            return
        }

        hasBootstrapped = true
        statusMessage = launchProfile == .preview ? "Loading preview workspace…" : "Restoring local session…"
        logger.log("bootstrap starting")

        do {
            try await client.bootstrap()
            startStoreObservation()
            await refreshAuthState()
            await refreshSnapshot()
            scheduleRestoredSessionRefreshIfNeeded()
            logger.log("bootstrap finished")
        } catch {
            phase = .failed(describe(error))
            statusMessage = "Bootstrap failed."
            logger.error("bootstrap failed: \(String(describing: error), privacy: .public)")
        }
    }

    func signIn() async {
        if await authFlow.signIn(using: client) {
            await hydrateAuthenticatedWorkspace()
        } else {
            phase = .signedOut
        }
    }

    func importWebLoginToken(_ token: String) async {
        do {
            _ = try await client.auth.importUserToken(token)
            authFlow.errorMessage = nil
            authFlow.statusMessage = "Imported a web login session."
            await hydrateAuthenticatedWorkspace()
        } catch {
            authFlow.errorMessage = describe(error)
            authFlow.statusMessage = "Importing the web login session failed."
            phase = .signedOut
        }
    }

    func completeMFA() async {
        if await authFlow.completeMFA(using: client) {
            await hydrateAuthenticatedWorkspace()
        }
    }

    func sendMFASMS() async {
        await authFlow.sendMFASMS(using: client)
    }

    func submitCaptcha() async {
        if await authFlow.submitCaptcha(using: client) {
            await hydrateAuthenticatedWorkspace()
        } else {
            phase = .signedOut
        }
    }

    func logout() async {
        guard launchProfile == .live else {
            settings.runtimeNotice = "Preview mode keeps its local sample session active."
            return
        }

        do {
            try await client.auth.logoutCurrentSession()
            try await client.clearLocalCache()
            await RemoteAssetCache.shared.clear()
            authFlow.resetForSignedOut()
            resetWorkspaceState()
            sidebarProjection = SidebarProjection(guilds: [], privateChannels: [])
            phase = .signedOut
            statusMessage = "Session cleared."
        } catch {
            authFlow.errorMessage = describe(error)
        }
    }

    // MARK: - Source Selection

    func setSelectedSource(_ selection: WorkspaceSelection?) {
        if let selection {
            recordSelectionAccess(selection)
        }

        guard selectedSource != selection else {
            return
        }

        selectedSource = selection
        selectedGuildChannelID = selection?.guildID == nil ? nil : selectedGuildChannelID
        selectedDirectMessageChannelID = selection?.userID == nil ? nil : selectedDirectMessageChannelID
        clearMessageSearch()
        refreshWorkspace(using: latestSnapshot)

        selectionTask?.cancel()
        selectionTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.handleSelectionChange(selection)
        }

        startLiveRefreshLoopIfNeeded()
    }

    func selectGuildChannel(_ channelID: ChannelID?) {
        guard let channelID else {
            selectedGuildChannelID = nil
            refreshWorkspace(using: latestSnapshot)
            return
        }

        guard let channel = channelListProjection.channels.first(where: { $0.id == channelID }),
              channel.kind.supportsWorkspaceTimelineInteraction else {
            return
        }

        guard selectedGuildChannelID != channelID else {
            return
        }

        selectedGuildChannelID = channelID
        refreshWorkspace(using: latestSnapshot)

        selectionTask?.cancel()
        selectionTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.hydrateVisibleChannelIfNeeded()
            await self.refreshSnapshot()
        }

        startLiveRefreshLoopIfNeeded()
    }

    func toggleCategory(_ categoryID: ChannelID) {
        guard let guildID = selectedSource?.guildID else {
            return
        }

        var collapsedCategoryIDs = collapsedCategoryIDsByGuildID[guildID] ?? []
        if collapsedCategoryIDs.contains(categoryID) {
            collapsedCategoryIDs.remove(categoryID)
        } else {
            collapsedCategoryIDs.insert(categoryID)
        }
        collapsedCategoryIDsByGuildID[guildID] = collapsedCategoryIDs
    }

    func recordSelectionAccess(_ selection: WorkspaceSelection) {
        let key = selection.persistenceKey
        let currentDate = Date()
        if var existing = recentSelectionSnapshots[key] {
            existing.accessCount += 1
            existing.lastAccessDate = currentDate
            recentSelectionSnapshots[key] = existing
        } else {
            recentSelectionSnapshots[key] = RecentSelectionSnapshot(
                selection: selection,
                accessCount: 1,
                lastAccessDate: currentDate
            )
        }
        persistRecentSelectionSnapshots()
    }

    // MARK: - Profile

    func openProfileSheet(for userID: UserID) {
        profileSheetUserID = userID
        profileSheetProjection = client.state.userInspectorProjection(for: userID, from: latestSnapshot)
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.prefetchProfileIfNeeded(userID)
            self.profileSheetProjection = self.client.state.userInspectorProjection(for: userID, from: self.latestSnapshot)
        }
    }

    func dismissProfileSheet() {
        profileSheetUserID = nil
        profileSheetProjection = nil
    }

    func cachedInspectorProjection(for userID: UserID) -> UserInspectorProjection? {
        client.state.userInspectorProjection(for: userID, from: latestSnapshot)
    }

    // MARK: - Reactions

    func toggleReaction(
        for message: DiscordMessage,
        emoji: DiscordReactionEmoji,
        guildID: GuildID?
    ) async throws {
        guard let currentUserID = await client.currentSession()?.userID else {
            throw ReactionMutationError.sessionUnavailable
        }

        let input = ReactionInput(
            channelID: message.channelID,
            messageID: message.id,
            emoji: emoji
        )
        let update = GatewayReactionUpdate(
            channelID: message.channelID,
            messageID: message.id,
            userID: currentUserID,
            guildID: guildID,
            emoji: emoji
        )

        if message.reactions.first(where: { $0.emoji == emoji })?.me == true {
            try await client.messages.removeReaction(input)
            try await client.processGatewayEvent(.messageReactionRemove(update))
        } else {
            try await client.messages.addReaction(input)
            try await client.processGatewayEvent(.messageReactionAdd(update))
        }
    }

    // MARK: - Timeline

    func loadOlderMessages(before messageID: MessageID) async {
        guard let channelID = currentVisibleChannelID() else { return }
        do {
            _ = try await client.messages.list(
                in: channelID,
                before: messageID,
                limit: 50
            )
            await refreshSnapshot()
        } catch {
            logger.warning("load older messages failed: \(String(describing: error), privacy: .public)")
        }
    }

    func refreshSelectedTimeline(forceFullReload: Bool = false) async {
        guard let channelID = currentVisibleChannelID() else {
            return
        }

        do {
            if forceFullReload || timeline.lastDisplayedMessageID == nil {
                try await client.hydrateChannelTimeline(for: channelID)
            } else if let lastMessageID = timeline.lastDisplayedMessageID {
                _ = try await client.messages.list(
                    in: channelID,
                    after: lastMessageID,
                    limit: 100
                )
            }
            await refreshSnapshot()
            await prefetchVisibleProfilesIfNeeded()
            await refreshSnapshot()
        } catch {
            logger.warning("timeline refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    func jumpToMessageReference(_ reference: DiscordMessageReference) async {
        guard let messageID = reference.messageID else {
            return
        }

        if timeline.displayedClusters.contains(where: { cluster in
            cluster.messages.contains(where: { $0.id == messageID })
        }) {
            timeline.requestJump(to: messageID)
            return
        }

        do {
            _ = try await client.messages.list(
                in: reference.channelID,
                around: messageID,
                limit: 50
            )
            await refreshSnapshot()
            timeline.requestJump(to: messageID)
        } catch {
            logger.warning("jump-to-reference failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Message Search

    func scheduleMessageSearch() {
        messageSearchTask?.cancel()

        let query = messageSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            clearMessageSearch()
            return
        }

        guard let context = currentMessageSearchContext() else {
            timeline.clearSearch()
            return
        }

        timeline.beginSearch(query: query)
        messageSearchTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            do {
                try await Task.sleep(for: .milliseconds(260))
                guard !Task.isCancelled else {
                    return
                }
                await self.performMessageSearch(query: query, context: context)
            } catch {
                return
            }
        }
    }

    // MARK: - Sending Messages

    func sendMessage(attachments: [MessageAttachmentInput] = []) async {
        let nonce = MessageNonce(rawValue: String(UInt64(Date().timeIntervalSince1970 * 1000)))
        guard let input = composer.makeSendInput(nonce: nonce, attachments: attachments) else {
            return
        }

        composer.markSending()

        do {
            _ = try await client.messages.send(input)
            composer.finishSending()
            await refreshSnapshot()
        } catch {
            composer.fail(error)
        }
    }

    // MARK: - Private Implementation

    private func startStoreObservation() {
        storeObservationTask?.cancel()
        storeObservationTask = Task {
            let stream = await client.state.subscribe()
            for await snapshot in stream {
                if Task.isCancelled {
                    return
                }
                await consume(snapshot: snapshot)
            }
        }
    }

    private func scheduleRestoredSessionRefreshIfNeeded() {
        restoreRefreshTask?.cancel()

        guard launchProfile == .live else {
            return
        }

        guard settings.currentSession != nil else {
            return
        }

        restoreRefreshTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await self.refreshWorkspaceFromRestoredSession()
        }
    }

    private func refreshAuthState() async {
        let session = await client.currentSession()
        await refreshSettings(session: session)

        if session == nil {
            phase = .signedOut
            statusMessage = launchProfile == .preview
                ? "Preview workspace ready."
                : "Sign in with a Discord account to open your workspace."
        } else {
            phase = .connected
            statusMessage = launchProfile == .preview
                ? "Preview workspace ready."
                : "Choose a friend or server to start reading."
        }

        startLiveRefreshLoopIfNeeded()
    }

    private func refreshSnapshot() async {
        let snapshot = await client.state.snapshot()
        await consume(snapshot: snapshot)
    }

    private func hydrateAuthenticatedWorkspace() async {
        statusMessage = "Hydrating workspace…"

        do {
            try await client.hydrateHomeState()
            await refreshAuthState()
            await refreshSnapshot()
        } catch {
            authFlow.errorMessage = describe(error)
            await refreshAuthState()
            await refreshSnapshot()
            statusMessage = "Connected, but workspace hydration failed."
        }
    }

    private func refreshWorkspaceFromRestoredSession() async {
        let hadLocalState = !latestSnapshot.guilds.isEmpty || !workspacePeople().isEmpty

        if !hadLocalState {
            statusMessage = "Refreshing workspace…"
        }

        do {
            try await client.hydrateHomeState()
            await refreshSnapshot()

            if !hadLocalState {
                statusMessage = "Choose a friend or server to start reading."
            }
        } catch {
            let message = describe(error)
            logger.warning("restored-session refresh failed: \(message, privacy: .public)")
            if !hadLocalState {
                settings.runtimeNotice = "Session restored, but refreshing the workspace failed: \(message)"
                statusMessage = "Signed in, but refreshing the workspace failed."
            }
        }
    }

    private func handleSelectionChange(_ selection: WorkspaceSelection?) async {
        switch selection {
        case let .friend(userID):
            await openConversation(with: userID)
        case let .guild(guildID):
            await openGuild(guildID)
        case nil:
            await refreshSnapshot()
        }
    }

    private func openConversation(with userID: UserID) async {
        statusMessage = "Opening conversation…"
        if let existingChannelID = directChannelID(for: userID, in: latestSnapshot) {
            selectedDirectMessageChannelID = existingChannelID
        }
        refreshWorkspace(using: latestSnapshot)

        do {
            let channelID = try await client.ensureDirectMessageChannel(with: userID)
            selectedDirectMessageChannelID = channelID
            await hydrateChannelIfNeeded(channelID)
        } catch {
            statusMessage = describe(error)
        }

        await prefetchProfileIfNeeded(userID)
        await prefetchVisibleProfilesIfNeeded()
        await refreshSnapshot()
    }

    private func openGuild(_ guildID: GuildID) async {
        statusMessage = "Loading server…"

        if !hydratedGuildIDs.contains(guildID) {
            do {
                try await client.hydrateGuildState(for: guildID)
                hydratedGuildIDs.insert(guildID)
            } catch {
                statusMessage = describe(error)
            }
        }

        await refreshSnapshot()
        await hydrateVisibleChannelIfNeeded()
        await prefetchVisibleProfilesIfNeeded()
        await refreshSnapshot()
    }

    private func hydrateVisibleChannelIfNeeded() async {
        let channelID: ChannelID?
        switch selectedSource {
        case .friend:
            channelID = selectedDirectMessageChannelID
        case .guild:
            channelID = selectedGuildChannelID
        case nil:
            channelID = nil
        }

        guard let channelID else {
            return
        }

        guard let channel = latestSnapshot.channels[channelID.rawValue],
              channel.kind.supportsTimelineHydration else {
            return
        }

        await hydrateChannelIfNeeded(channelID)
    }

    private func hydrateChannelIfNeeded(_ channelID: ChannelID) async {
        guard !hydratedChannelIDs.contains(channelID) else {
            return
        }

        do {
            try await client.hydrateChannelTimeline(for: channelID)
            hydratedChannelIDs.insert(channelID)
        } catch {
            statusMessage = describe(error)
        }
    }

    private func prefetchVisibleProfilesIfNeeded() async {
        guard let guildID = selectedSource?.guildID else {
            return
        }

        let authorIDs = Set(
            timeline.displayedClusters
                .prefix(24)
                .map(\.author.id)
        )

        for authorID in authorIDs {
            let key = HydratedProfileKey(userID: authorID, guildID: guildID)
            guard !hydratedUserProfiles.contains(key) else {
                continue
            }
            await prefetchProfileIfNeeded(authorID)
        }
    }

    private func prefetchProfileIfNeeded(_ userID: UserID) async {
        let key = HydratedProfileKey(userID: userID, guildID: selectedSource?.guildID)
        guard !hydratedUserProfiles.contains(key) else {
            return
        }

        do {
            try await client.hydrateUserProfile(for: userID, guildID: selectedSource?.guildID)
            hydratedUserProfiles.insert(key)
        } catch {
            logger.warning("profile hydration failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func consume(snapshot: NormalizedState) async {
        latestSnapshot = snapshot
        sidebarProjection = client.state.sidebarProjection(from: snapshot)

        if let selectedChannel = timeline.selectedChannel,
           selectedChannel.kind.supportsTimelineHydration,
           client.state.clusteredTimelineProjection(for: selectedChannel.id, from: snapshot).messageCount > 0 {
            hydratedChannelIDs.insert(selectedChannel.id)
        }

        refreshWorkspace(using: snapshot)

        if selectedSource?.guildID != nil {
            Task { @MainActor [weak self] in
                await self?.prefetchVisibleProfilesIfNeeded()
            }
        }

        let badgeSnapshot = NotificationBadgeSnapshot(
            unreadChannelCount: snapshot.readStates.count,
            pendingMessageCount: snapshot.pendingMessageOperations.count
        )
        await refreshSettings(
            session: settings.currentSession,
            badgeSnapshot: badgeSnapshot
        )

        if phase == .connected &&
            sidebarProjection.guilds.isEmpty &&
            workspacePeople().isEmpty {
            statusMessage = "Connected, but no local conversations have been hydrated yet."
        }

        profileSheetProjection = profileSheetUserID.flatMap {
            client.state.userInspectorProjection(for: $0, from: snapshot)
        }
    }

    private func refreshWorkspace(using snapshot: NormalizedState) {
        switch selectedSource {
        case let .friend(userID):
            channelListProjection = ChannelListProjection(guildID: nil, channels: [])
            selectedGuildChannelID = nil

            if selectedDirectMessageChannelID == nil {
                selectedDirectMessageChannelID = directChannelID(for: userID, in: snapshot)
            }

            let resolvedChannel = selectedDirectMessageChannelID.flatMap { snapshot.channels[$0.rawValue] }
            applyTimeline(for: resolvedChannel, from: snapshot)

            if let person = selectedPerson {
                let count = timeline.projection.messageCount
                statusMessage = count == 0
                    ? "Conversation with \(person.displayName) is ready."
                    : "Showing \(count) messages with \(person.displayName)."
            }

        case let .guild(guildID):
            selectedDirectMessageChannelID = nil
            channelListProjection = client.state.channelListProjection(for: guildID, from: snapshot)

            if selectedGuildChannelID == nil ||
                !channelListProjection.channels.contains(where: { $0.id == selectedGuildChannelID }) {
                selectedGuildChannelID = defaultGuildChannelID(in: channelListProjection.channels)
            }

            let resolvedChannel = selectedGuildChannelID.flatMap { snapshot.channels[$0.rawValue] }
            applyTimeline(for: resolvedChannel, from: snapshot)

            if let guild = snapshot.guilds[guildID.rawValue] {
                statusMessage = channelListProjection.channels.isEmpty
                    ? "Loading channels for \(guild.name)…"
                    : "Browsing \(guild.name)."
            }

        case nil:
            channelListProjection = ChannelListProjection(guildID: nil, channels: [])
            selectedGuildChannelID = nil
            selectedDirectMessageChannelID = nil
            applyTimeline(for: nil, from: snapshot)

            if phase == .connected {
                statusMessage = sidebarProjection.guilds.isEmpty && workspacePeople().isEmpty
                    ? "Connected, but no local conversations have been hydrated yet."
                    : "Choose a friend or server to start reading."
            }
        }
    }

    private func applyTimeline(for channel: DiscordChannel?, from snapshot: NormalizedState) {
        let timelineChannelID = channel?.kind.supportsTimelineHydration == true ? channel?.id : nil
        let projection = timelineChannelID.map {
            client.state.clusteredTimelineProjection(for: $0, from: snapshot)
        } ?? ClusteredTimelineProjection(channelID: nil, clusters: [])

        timeline.apply(channel: channel, projection: projection)
        composer.prepareForChannel(timelineChannelID)
    }

    private func currentVisibleChannelID() -> ChannelID? {
        switch selectedSource {
        case .friend:
            return selectedDirectMessageChannelID
        case .guild:
            return selectedGuildChannelID
        case nil:
            return nil
        }
    }

    private func startLiveRefreshLoopIfNeeded() {
        liveRefreshTask?.cancel()

        guard launchProfile == .live, phase == .connected else {
            return
        }

        guard let channelID = currentVisibleChannelID() else {
            return
        }

        guard latestSnapshot.channels[channelID.rawValue]?.kind.supportsTimelineHydration == true else {
            return
        }

        liveRefreshTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(8))
                guard !Task.isCancelled else {
                    return
                }
                await self.refreshSelectedTimeline()
            }
        }
    }

    private func refreshSettings(
        session: DiscordSession? = nil,
        badgeSnapshot: NotificationBadgeSnapshot? = nil
    ) async {
        let resolvedSession: DiscordSession?
        if let session {
            resolvedSession = session
        } else {
            resolvedSession = await client.currentSession()
        }
        let userSettings = await client.settings.currentUserSettings()
        settings.apply(
            session: resolvedSession,
            userSettings: userSettings,
            badgeSnapshot: badgeSnapshot ?? settings.badgeSnapshot,
            cacheStatus: settings.cacheStatus
        )
    }

    private func currentMessageSearchContext() -> MessageSearchContext? {
        switch selectedSource {
        case .friend:
            guard let channelID = selectedDirectMessageChannelID else {
                return nil
            }
            return .privateChannel(channelID)
        case let .guild(guildID):
            if let channelID = selectedGuildChannelID {
                return .guild(guildID, [channelID])
            }
            return .guild(guildID, [])
        case nil:
            return nil
        }
    }

    private func performMessageSearch(query: String, context: MessageSearchContext) async {
        do {
            let results: DiscordMessageSearchResults
            let channelID: ChannelID?

            switch context {
            case let .privateChannel(selectedChannelID):
                results = try await client.search.searchPrivateChannelMessages(in: selectedChannelID, query: query)
                channelID = selectedChannelID
            case let .guild(guildID, channelIDs):
                results = try await client.search.searchGuildMessages(in: guildID, query: query, channelIDs: channelIDs)
                channelID = channelIDs.first
            }

            let snapshot = await client.state.snapshot()
            let projection = client.state.clusteredTimelineProjection(
                for: results.messages.sorted { $0.timestamp < $1.timestamp },
                channelID: channelID,
                from: snapshot
            )
            timeline.completeSearch(query: query, projection: projection, totalResults: results.totalResults)
        } catch {
            timeline.failSearch(query: query, error: error)
        }
    }

    private func clearMessageSearch() {
        messageSearchTask?.cancel()
        messageSearchText = ""
        timeline.clearSearch()
    }

    func filteredPeople(matching query: String) -> [WorkspacePerson] {
        let people = workspacePeople()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return people
        }

        return people.filter { person in
            person.user.username.localizedCaseInsensitiveContains(trimmedQuery) ||
            person.user.displayName.localizedCaseInsensitiveContains(trimmedQuery) ||
            person.user.tag.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    func filteredGuilds(matching query: String) -> [DiscordGuild] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let guilds = sidebarProjection.guilds.sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        guard !trimmedQuery.isEmpty else {
            return guilds
        }

        return guilds.filter { guild in
            guild.name.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    func workspacePeople() -> [WorkspacePerson] {
        var entriesByUserID = [String: WorkspacePerson]()

        for friend in sidebarProjection.friends {
            entriesByUserID[friend.user.id.rawValue] = WorkspacePerson(
                user: friend.user,
                relationship: friend.relationship,
                existingChannelID: directChannelID(for: friend.user.id, in: latestSnapshot)
            )
        }

        for channel in sidebarProjection.privateChannels where channel.kind == .directMessage {
            guard let recipientID = channel.recipientIDs.first(where: { $0 != settings.currentSession?.userID }),
                  let user = latestSnapshot.users[recipientID.rawValue] else {
                continue
            }

            if var existing = entriesByUserID[user.id.rawValue] {
                existing.user = user
                existing.existingChannelID = existing.existingChannelID ?? channel.id
                entriesByUserID[user.id.rawValue] = existing
            } else {
                entriesByUserID[user.id.rawValue] = WorkspacePerson(
                    user: user,
                    existingChannelID: channel.id
                )
            }
        }

        return entriesByUserID.values.sorted { lhs, rhs in
            let leftPriority = lhs.relationship?.kind.workspaceSortPriority ?? 1
            let rightPriority = rhs.relationship?.kind.workspaceSortPriority ?? 1
            if leftPriority == rightPriority {
                return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            }
            return leftPriority < rightPriority
        }
    }

    private func directChannelID(for userID: UserID, in snapshot: NormalizedState) -> ChannelID? {
        snapshot.channels.values.first(where: { channel in
            channel.kind == .directMessage && channel.recipientIDs.contains(userID)
        })?.id
    }

    private func defaultGuildChannelID(in channels: [DiscordChannel]) -> ChannelID? {
        channels.first(where: { $0.kind.supportsWorkspaceTimelineInteraction })?.id
    }

    private var currentCollapsedCategoryIDs: Set<ChannelID> {
        guard let guildID = selectedSource?.guildID else {
            return []
        }
        return collapsedCategoryIDsByGuildID[guildID] ?? []
    }

    private func resetWorkspaceState() {
        selectionTask?.cancel()
        messageSearchTask?.cancel()
        restoreRefreshTask?.cancel()
        liveRefreshTask?.cancel()
        selectedSource = nil
        selectedGuildChannelID = nil
        selectedDirectMessageChannelID = nil
        profileSheetUserID = nil
        profileSheetProjection = nil
        channelListProjection = ChannelListProjection(guildID: nil, channels: [])
        timeline.apply(channel: nil, projection: ClusteredTimelineProjection(channelID: nil, clusters: []))
        composer.prepareForChannel(nil)
        hydratedGuildIDs.removeAll()
        hydratedChannelIDs.removeAll()
        hydratedUserProfiles.removeAll()
        collapsedCategoryIDsByGuildID.removeAll()
        navigationPath.removeAll()
        latestSnapshot = .empty
    }

    private func resolveRecentSelection(_ snapshot: RecentSelectionSnapshot) -> RecentSelectionEntry? {
        switch snapshot.selection {
        case let .friend(userID):
            if let person = workspacePeople().first(where: { $0.user.id == userID }) {
                return RecentSelectionEntry(
                    selection: snapshot.selection,
                    title: person.displayName,
                    subtitle: person.detailText,
                    user: person.user,
                    guild: nil
                )
            }
            return RecentSelectionEntry(
                selection: snapshot.selection,
                title: userID.rawValue,
                subtitle: "Recent direct message",
                user: nil,
                guild: nil
            )

        case let .guild(guildID):
            if let guild = latestSnapshot.guilds[guildID.rawValue] {
                return RecentSelectionEntry(
                    selection: snapshot.selection,
                    title: guild.name,
                    subtitle: "Recent server",
                    user: nil,
                    guild: guild
                )
            }
            return RecentSelectionEntry(
                selection: snapshot.selection,
                title: guildID.rawValue,
                subtitle: "Recent server",
                user: nil,
                guild: nil
            )
        }
    }

    private func persistRecentSelectionSnapshots() {
        guard let data = try? JSONEncoder().encode(Array(recentSelectionSnapshots.values)) else {
            return
        }
        defaults.set(data, forKey: Self.recentSelectionsDefaultsKey)
    }

    private static func loadRecentSelectionSnapshots(from defaults: UserDefaults) -> [String: RecentSelectionSnapshot] {
        guard let data = defaults.data(forKey: recentSelectionsDefaultsKey),
              let decoded = try? JSONDecoder().decode([RecentSelectionSnapshot].self, from: data) else {
            return [:]
        }

        return decoded.reduce(into: [:]) { partialResult, snapshot in
            partialResult[snapshot.selection.persistenceKey] = snapshot
        }
    }

    private static let recentSelectionsDefaultsKey = "workspace.recentSelections"

    func describe(_ error: some Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription {
            return localized
        }
        return String(describing: error)
    }
}

// MARK: - Supporting Types

enum SourceStripItem: Identifiable, Hashable {
    case friend(WorkspacePerson)
    case guild(DiscordGuild)

    var id: String {
        switch self {
        case let .friend(person):
            return "friend:\(person.user.id.rawValue)"
        case let .guild(guild):
            return "guild:\(guild.id.rawValue)"
        }
    }

    var selection: WorkspaceSelection {
        switch self {
        case let .friend(person):
            return .friend(person.user.id)
        case let .guild(guild):
            return .guild(guild.id)
        }
    }
}

enum IOSNavigationDestination: Hashable {
    case guildChannelList(GuildID)
    case timeline(ChannelID)
}

private enum MessageSearchContext: Sendable {
    case privateChannel(ChannelID)
    case guild(GuildID, [ChannelID])
}

private extension RelationshipKind {
    var workspaceSortPriority: Int {
        switch self {
        case .friend:
            return 0
        case .implicit:
            return 1
        case .incomingRequest:
            return 2
        case .outgoingRequest:
            return 3
        case .blocked:
            return 4
        }
    }
}

private enum ReactionMutationError: LocalizedError {
    case sessionUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionUnavailable:
            return "Session unavailable."
        }
    }
}
