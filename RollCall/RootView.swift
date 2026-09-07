import Foundation
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum RootTab: Hashable {
    case players
    case generalClips
    case gameDay
    case readiness
    case teams
    case settings

    static func sensibleInitialTab(for team: Team?) -> RootTab {
        guard let team, !team.players.isEmpty else { return .players }
        return .gameDay
    }
}

private enum PackageImportContext {
    case settings
    case onboarding
}

private enum WhatsNewPresentation: Identifiable {
    case automatic
    case manual

    var id: String {
        switch self {
        case .automatic: return "automatic"
        case .manual: return "manual"
        }
    }
}

private struct WhatsNewRelease: Identifiable {
    var id: String { version }
    let version: String
    let intro: String?
    let highlights: [WhatsNewHighlight]
    let lookingAhead: WhatsNewHighlight?
}

private struct WhatsNewHighlight: Identifiable {
    let title: String
    let detail: String
    let systemImage: String

    var id: String { title }
}

private struct WhatsNewBundle {
    let family: String
    let releases: [WhatsNewRelease]
    let fullChangelogURL: URL

    static let current = WhatsNewBundle(
        family: "1.3",
        releases: [
            WhatsNewRelease(
                version: "1.3",
                intro: "Make every player feel like the main event—and get to Game Day faster when it matters.",
                highlights: [
                    WhatsNewHighlight(
                        title: "Player Cards",
                        detail: "Create and share a personalized walk-up card with a player's photo, team, number, and music. Open any player to preview and share their Player Card.",
                        systemImage: "rectangle.portrait.on.rectangle.portrait"
                    ),
                    WhatsNewHighlight(
                        title: "Quick Game Day",
                        detail: "Get to Game Day faster from Control Center, the Lock Screen, Action Button, Shortcuts, Siri, or Spotlight on supported devices—without starting playback.",
                        systemImage: "play.rectangle.fill"
                    )
                ],
                lookingAhead: nil
            ),
            WhatsNewRelease(
                version: "1.2",
                intro: "This MAJOR update makes song setup much smoother, adds Custom Clips, and helps you know what's ready before game day starts.",
                highlights: [
                    WhatsNewHighlight(
                        title: "Better Song Setup",
                        detail: "Pick from Apple's familiar Music Library first, search Apple Music when you need to, or import a file. Songs now open as drafts, so you can preview and adjust before replacing a player's Game Day cue.",
                        systemImage: "music.note.list"
                    ),
                    WhatsNewHighlight(
                        title: "Custom Clips",
                        detail: "Create team-specific Custom Clips for quick song cues that are not tied to a player. Copy, reorder, edit, delete, and restore clips without silently changing the original song or clip.",
                        systemImage: "square.grid.2x2.fill"
                    ),
                    WhatsNewHighlight(
                        title: "Safer Song Choices",
                        detail: "Explicit Apple Music search results are hidden by default, and Roll Call asks before using explicit songs selected from the Music Library.",
                        systemImage: "checkmark.shield.fill"
                    ),
                    WhatsNewHighlight(
                        title: "Make Your Clip",
                        detail: "Shape a walk-up clip with a draggable song window, quick length choices, preview, and a clear Save step. When Roll Call can inspect the audio, it shows a simple shape to help find the right moment.",
                        systemImage: "waveform"
                    ),
                    WhatsNewHighlight(
                        title: "Faster Live Switching",
                        detail: "Swipe between Game Day and Clips without stopping playback. The shortcut stays focused on the two live screens.",
                        systemImage: "arrow.left.arrow.right"
                    ),
                    WhatsNewHighlight(
                        title: "Clearer Readiness",
                        detail: "See which songs and clips are ready on this device, which can travel to another device, and which need Apple Music or repair after a team import.",
                        systemImage: "shippingbox.fill"
                    )
                ],
                lookingAhead: nil
            )
        ],
        fullChangelogURL: URL(string: "https://sidelarklabs.com/rollcall/support/roll-call-support#changelog")!
    )
}

private struct PlayingSpeakerSymbol: View {
    let systemImage: String
    var color: Color?
    @State private var isPulsing = false

    var body: some View {
        if #available(iOS 26.0, *) {
            ZStack {
                Image(systemName: resolvedSystemImage)
                    .optionalForegroundStyle(color)
                    .opacity(0.68)
                Image(systemName: resolvedSystemImage)
                    .optionalForegroundStyle(color)
                    .symbolEffect(.drawOn.individually, options: .repeat(.periodic(delay: 3.0)))
            }
        } else {
            Image(systemName: resolvedSystemImage)
                .optionalForegroundStyle(color)
                .scaleEffect(isPulsing ? 1.16 : 0.92)
                .opacity(isPulsing ? 1.0 : 0.62)
                .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear {
                    isPulsing = true
                }
        }
    }

    private var resolvedSystemImage: String {
        if UIImage(systemName: systemImage) != nil {
            return systemImage
        }
        if UIImage(systemName: "speaker.wave.3") != nil {
            return "speaker.wave.3"
        }
        return "speaker.wave.2.fill"
    }
}

private extension View {
    @ViewBuilder
    func optionalForegroundStyle(_ color: Color?) -> some View {
        if let color {
            self.foregroundStyle(color)
        } else {
            self
        }
    }
}

private func liveAccentOutlineColor(
    theme: TeamAccentTheme,
    colorScheme: ColorScheme,
    lightOpacity: Double,
    darkOpacity: Double
) -> Color {
    theme
        .color(colorScheme == .dark ? .subtle : .primary, surface: .live)
        .opacity(colorScheme == .dark ? darkOpacity : lightOpacity)
}

private extension View {
    func teamAccentScope(_ theme: TeamAccentTheme) -> some View {
        rollCallTeamAccentTheme(theme)
            .tint(theme.color(.primary))
    }

    func accentWashBackground(surface: RollCallSurfaceVariant = .standard) -> some View {
        background {
            AccentWashBackground(surface: surface)
                .ignoresSafeArea()
        }
    }

    func accentWashListBackground(surface: RollCallSurfaceVariant = .standard) -> some View {
        scrollContentBackground(.hidden)
            .accentWashBackground(surface: surface)
    }
}

@MainActor
private struct TabBarAccentUpdater: UIViewControllerRepresentable {
    let theme: TeamAccentTheme

    func makeUIViewController(context: Context) -> UIViewController {
        TabBarAccentViewController(theme: theme)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let controller = uiViewController as? TabBarAccentViewController else { return }
        controller.theme = theme
        controller.applyAccent()
    }

    private final class TabBarAccentViewController: UIViewController {
        var theme: TeamAccentTheme

        init(theme: TeamAccentTheme) {
            self.theme = theme
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyAccent()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyAccent()
        }

        func applyAccent() {
            let tintColor = theme.uiColor(.primary).resolvedColor(with: traitCollection)
            var parent = parent
            while let current = parent {
                if let tabBarController = current as? UITabBarController {
                    applyTabBarAccent(tintColor, to: tabBarController.tabBar)
                    return
                }
                parent = current.parent
            }
        }
    }
}

@MainActor
private func applyTabBarAccent(_ theme: TeamAccentTheme) {
    let tintColor = theme.uiColor(.primary)
    UITabBar.appearance().tintColor = tintColor

    for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
        for window in scene.windows {
            applyTabBarAccent(tintColor, below: window.rootViewController)
        }
    }
}

@MainActor
private func applyTabBarAccent(_ tintColor: UIColor, below viewController: UIViewController?) {
    guard let viewController else { return }
    if let tabBarController = viewController as? UITabBarController {
        applyTabBarAccent(tintColor, to: tabBarController.tabBar)
    }
    for child in viewController.children {
        applyTabBarAccent(tintColor, below: child)
    }
    if let presented = viewController.presentedViewController {
        applyTabBarAccent(tintColor, below: presented)
    }
}

@MainActor
private func applyTabBarAccent(_ tintColor: UIColor, to tabBar: UITabBar) {
    tabBar.tintColor = tintColor
    let standardAppearance = tabBar.standardAppearance
    standardAppearance.stackedLayoutAppearance.selected.iconColor = tintColor
    standardAppearance.stackedLayoutAppearance.selected.titleTextAttributes[.foregroundColor] = tintColor
    standardAppearance.inlineLayoutAppearance.selected.iconColor = tintColor
    standardAppearance.inlineLayoutAppearance.selected.titleTextAttributes[.foregroundColor] = tintColor
    standardAppearance.compactInlineLayoutAppearance.selected.iconColor = tintColor
    standardAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes[.foregroundColor] = tintColor
    tabBar.standardAppearance = standardAppearance
    tabBar.scrollEdgeAppearance = standardAppearance
}

fileprivate enum RatingRequestPresentation: String, Identifiable, Equatable {
    case automatic
    case manual

    var id: String { rawValue }
}

private struct LiveSurfaceSwipeGestureInstaller: UIViewRepresentable {
    var isEnabled: Bool
    var selectedTab: RootTab
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat, CGFloat) -> Void
    var onCancelled: () -> Void

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.selectedTab = selectedTab
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
        uiView.coordinator = context.coordinator
        uiView.installIfPossible()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isEnabled: isEnabled,
            selectedTab: selectedTab,
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
    }

    final class InstallerView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            installIfPossible()
        }

        func installIfPossible() {
            guard let window, let coordinator else { return }
            coordinator.install(on: window)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isEnabled: Bool
        var selectedTab: RootTab
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat, CGFloat) -> Void
        var onCancelled: () -> Void

        private weak var installedView: UIView?
        private lazy var panRecognizer: UIPanGestureRecognizer = {
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            recognizer.cancelsTouchesInView = true
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            return recognizer
        }()

        init(
            isEnabled: Bool,
            selectedTab: RootTab,
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat, CGFloat) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.isEnabled = isEnabled
            self.selectedTab = selectedTab
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
        }

        func install(on view: UIView) {
            guard installedView !== view else { return }
            if let installedView {
                installedView.removeGestureRecognizer(panRecognizer)
            }
            installedView = view
            view.addGestureRecognizer(panRecognizer)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled, let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: gestureRecognizer.view)
            let horizontalVelocity = velocity.x
            let verticalVelocity = abs(velocity.y)
            guard abs(horizontalVelocity) > verticalVelocity * 1.25 else { return false }
            return isValidSwipeDirection(horizontalVelocity)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            otherGestureRecognizer.view is UIScrollView
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)
            switch recognizer.state {
            case .began, .changed:
                onChanged(translation.x)
            case .ended:
                onEnded(translation.x, abs(translation.y))
            case .cancelled, .failed:
                onCancelled()
            default:
                break
            }
        }

        private func isValidSwipeDirection(_ horizontalDistance: CGFloat) -> Bool {
            switch (selectedTab, horizontalDistance) {
            case (.gameDay, ..<0), (.generalClips, 0...):
                return true
            default:
                return false
            }
        }
    }
}

struct RootView: View {
    private struct PlayerEditorRoute: Identifiable {
        let id: UUID
    }

    @Environment(\.colorScheme) private var deviceColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var appModel: AppModel
    @ObservedObject private var playbackEngine: CuePlaybackEngine
    @ObservedObject private var openGameDayRequestCenter = OpenGameDayRequestCenter.shared
    @State private var newTeamName = ""
    @State private var playerEditorRoute: PlayerEditorRoute?
    @State private var packageImportPresented = false
    @State private var csvImportPresented = false
    @State private var selectedTab: RootTab = .players
    @State private var showLineupEditor = false
    @State private var showRenameTeamAlert = false
    @State private var showRemoveTeamConfirmation = false
    @State private var renameTeamName = ""
    @State private var packageSharePresented = false
    @State private var packageImportContext: PackageImportContext = .settings
    @State private var hasEnteredOnboardingFlow = false
    @State private var hasResolvedInitialTab = false
    @State private var whatsNewPresentation: WhatsNewPresentation?
    @State private var ratingRequestPresentation: RatingRequestPresentation?
    @State private var ratingPresentationToken: UUID?
    @State private var supportScreenPresented = false
    @State private var quickGameDayHelpPresented = false
    @State private var teamPlaylistPreview: TeamAppleMusicPlaylistSummary?
    @State private var showTeamClips = false
    @State private var customClipRepairPrompt: SongClip?
    @State private var customClipManagerInitialClipID: UUID?
    @State private var liveSurfaceSwipeOffset: CGFloat = 0
    @State private var suppressNextGameDayRecencyUpdate = false

    init(appModel: AppModel) {
        self.appModel = appModel
        _playbackEngine = ObservedObject(initialValue: appModel.playbackEngine)
        _selectedTab = State(initialValue: RootTab.sensibleInitialTab(for: appModel.selectedTeam))
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { appModel.lastError != nil }, set: { newValue in if !newValue { appModel.lastError = nil } })
    }

    private var effectiveLiveColorScheme: ColorScheme {
        if deviceColorScheme == .dark || appModel.state.settings.alwaysUseDarkLiveMode {
            return .dark
        }
        return .light
    }

    private var shouldKeepScreenAwake: Bool {
        guard scenePhase == .active else { return false }
        guard appModel.state.settings.keepScreenAwakeDuringLiveUse else { return false }
        return selectedTab == .gameDay || selectedTab == .generalClips
    }

    private var isSafeNonLiveTabForWhatsNew: Bool {
        switch selectedTab {
        case .players, .readiness, .teams, .settings:
            return true
        case .gameDay, .generalClips:
            return false
        }
    }

    private var hasBlockingWhatsNewPresentation: Bool {
        appModel.riskyOperationCount > 0
            || appModel.lastError != nil
            || appModel.pendingPackageExport != nil
            || appModel.pendingPackageImport != nil
            || appModel.completedPackageImportAudit != nil
            || appModel.pendingRosterImport != nil
            || packageImportPresented
            || csvImportPresented
            || playerEditorRoute != nil
            || showLineupEditor
            || showRenameTeamAlert
            || showRemoveTeamConfirmation
            || packageSharePresented
            || whatsNewPresentation != nil
            || ratingRequestPresentation != nil
            || teamPlaylistPreview != nil
            || showTeamClips
            || customClipRepairPrompt != nil
            || supportScreenPresented
            || quickGameDayHelpPresented
    }

    private var isLiveSurfaceSwipeAvailable: Bool {
        guard selectedTab == .gameDay || selectedTab == .generalClips else { return false }
        return !hasBlockingWhatsNewPresentation
            && !showTeamClips
            && customClipRepairPrompt == nil
    }

    private var liveSurfaceSwipeInstaller: some View {
        LiveSurfaceSwipeGestureInstaller(
            isEnabled: isLiveSurfaceSwipeAvailable,
            selectedTab: selectedTab,
            onChanged: { horizontalDistance in
                handleLiveSurfaceSwipeChange(horizontalDistance: horizontalDistance)
            },
            onEnded: { horizontalDistance, verticalDistance in
                handleLiveSurfaceSwipeEnd(
                    horizontalDistance: horizontalDistance,
                    verticalDistance: verticalDistance
                )
            },
            onCancelled: {
                resetLiveSurfaceSwipeFeedback(animated: true)
            }
        )
    }

    private var canPresentAutomaticWhatsNew: Bool {
        appModel.hasUnseenWhatsNew
            && !appModel.shouldShowOnboarding
            && isSafeNonLiveTabForWhatsNew
            && !hasBlockingWhatsNewPresentation
    }

    private var canPresentAutomaticRatingRequest: Bool {
        appModel.canPresentAutomaticRatingRequest
            && !appModel.hasUnseenWhatsNew
            && !appModel.shouldShowOnboarding
            && isSafeNonLiveTabForWhatsNew
            && !hasBlockingWhatsNewPresentation
    }

    private var automaticRatingRequestDebugStatus: String {
        if !appModel.hasEarnedRatingRequest {
            return "Below threshold"
        }
        if appModel.telemetry.ratingSnapshot.automaticAttemptsConsumed >= 2 {
            return "All automatic attempts spent"
        }
        if appModel.hasUnseenWhatsNew {
            return "Waiting for What's New to clear"
        }
        if appModel.shouldShowOnboarding {
            return "Blocked by onboarding"
        }
        if !isSafeNonLiveTabForWhatsNew {
            return "Blocked on Game Day or Clips"
        }
        if appModel.riskyOperationCount > 0 {
            return "Blocked while app is busy"
        }
        if appModel.lastError != nil {
            return "Blocked by active alert"
        }
        if appModel.pendingPackageImport != nil || appModel.pendingRosterImport != nil {
            return "Blocked by import flow"
        }
        if packageImportPresented || csvImportPresented || playerEditorRoute != nil || showLineupEditor || showRenameTeamAlert || showRemoveTeamConfirmation || packageSharePresented || whatsNewPresentation != nil || teamPlaylistPreview != nil {
            return "Blocked by another sheet or modal"
        }
        return "Eligible now"
    }

    private var clipsSurface: RollCallSurfaceVariant {
        .live
    }

    private var clipsTeamBannerVariant: TeamBannerVariant {
        .liveSide
    }

    private var selectedTeamAccentTheme: TeamAccentTheme {
        appModel.selectedTeam?.accentPreset.theme ?? .rollCallDefault
    }

    private func presentPlayerEditor(for player: Player) {
        appModel.prepareSongClipForPlayerEditor(player.id)
        playerEditorRoute = PlayerEditorRoute(id: player.id)
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = shouldKeepScreenAwake
    }

    private func presentAutomaticWhatsNewIfPossible() {
        guard canPresentAutomaticWhatsNew else { return }
        whatsNewPresentation = .automatic
    }

    private func presentAutomaticRatingRequestIfPossible() {
        guard canPresentAutomaticRatingRequest else { return }
        guard let token = appModel.reserveAutomaticRatingPresentation() else { return }
        ratingPresentationToken = token
        ratingRequestPresentation = .automatic
    }

    private func requestNativeInAppRatingPrompt() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }
        SKStoreReviewController.requestReview(in: windowScene)
    }

    private func requestManualRatingReview() {
        UIApplication.shared.open(AppMetadata.appStoreWriteReviewURL)
    }

    private func requestRatingSupportEmail() {
        UIApplication.shared.open(feedbackEmailURL)
    }

    private func presentManualRatingRequestSheet() {
        guard let token = appModel.reserveManualRatingPresentation() else { return }
        ratingPresentationToken = token
        ratingRequestPresentation = .manual
    }

    private func handleSelectedTabChange(from previousTab: RootTab, to newTab: RootTab) {
        updateIdleTimer()
        appModel.setSongClipPreparationLiveUseThrottled(newTab == .gameDay || newTab == .generalClips)
        if previousTab == .generalClips, newTab != .generalClips {
            showTeamClips = false
        }

        if newTab == .gameDay {
            if suppressNextGameDayRecencyUpdate {
                suppressNextGameDayRecencyUpdate = false
            } else if previousTab != .gameDay {
                appModel.recordIntentionalGameDayEntry()
            }
            appModel.beginGameDayVisitForRatingIfNeeded()
            appModel.refreshGameDayWarmup()
        }
        if previousTab == .gameDay, newTab != .gameDay {
            appModel.finalizeGameDayVisitForRatingIfNeeded()
        }
        if newTab == .readiness {
            appModel.recordReadinessOpened()
            appModel.prepareSongsForReadiness()
        }
    }

    private func handleLiveSurfaceSwipeChange(horizontalDistance: CGFloat) {
        guard isLiveSurfaceSwipeAvailable else { return }

        guard isValidLiveSurfaceSwipeDirection(horizontalDistance) else {
            resetLiveSurfaceSwipeFeedback()
            return
        }
        guard abs(horizontalDistance) >= 28 else {
            resetLiveSurfaceSwipeFeedback()
            return
        }

        let cappedOffset = min(abs(horizontalDistance) * 0.12, 14)
        liveSurfaceSwipeOffset = horizontalDistance < 0 ? -cappedOffset : cappedOffset
    }

    private func handleLiveSurfaceSwipeEnd(horizontalDistance: CGFloat, verticalDistance: CGFloat) {
        defer { resetLiveSurfaceSwipeFeedback(animated: true) }
        guard isLiveSurfaceSwipeAvailable else { return }

        let isDeliberateHorizontalSwipe = abs(horizontalDistance) >= 80
            && abs(horizontalDistance) > verticalDistance * 1.4
        guard isDeliberateHorizontalSwipe else { return }
        guard isValidLiveSurfaceSwipeDirection(horizontalDistance) else { return }

        completeLiveSurfaceSwipe(to: horizontalDistance < 0 ? .generalClips : .gameDay)
    }

    private func isValidLiveSurfaceSwipeDirection(_ horizontalDistance: CGFloat) -> Bool {
        switch (selectedTab, horizontalDistance) {
        case (.gameDay, ..<0):
            return true
        case (.generalClips, 0...):
            return true
        default:
            return false
        }
    }

    private func completeLiveSurfaceSwipe(to tab: RootTab) {
        guard selectedTab != tab else { return }
        selectedTab = tab
        if appModel.state.settings.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func resetLiveSurfaceSwipeFeedback(animated: Bool = false) {
        let reset = {
            liveSurfaceSwipeOffset = 0
        }
        if animated {
            withAnimation(.easeOut(duration: 0.14), reset)
        } else {
            reset()
        }
    }

    private func handleScenePhaseChange(from previousPhase: ScenePhase, to newPhase: ScenePhase) {
        updateIdleTimer()
        if newPhase != .active {
            showTeamClips = false
            if previousPhase == .active {
                Task { await appModel.flushLatestState() }
            }
        }

        if newPhase == .active, selectedTab == .gameDay {
            appModel.refreshGameDayWarmup()
        }
        if newPhase == .active {
            appModel.handleTelemetryActivation(wasAlreadyActive: previousPhase == .active)
            appModel.prepareSongsAfterForeground()
        }

        guard previousPhase == .active, newPhase != .active, selectedTab == .gameDay else { return }
        appModel.finalizeGameDayVisitForRatingIfNeeded()
    }

    private func handleRosterImportResult(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        Task { await appModel.prepareRosterImport(from: url) }
    }

    private func finishLaunchingTask() async {
        appModel.setSongClipPreparationLiveUseThrottled(
            selectedTab == .gameDay || selectedTab == .generalClips
        )
        await appModel.finishLaunchingIfNeeded()
        resolveInitialTabIfNeeded()
        let launchedWithOpenGameDayRequest = openGameDayRequestCenter.pendingRequest != nil
        processPendingOpenGameDayRequestIfPossible()
        appModel.setSongClipPreparationLiveUseThrottled(
            selectedTab == .gameDay || selectedTab == .generalClips
        )
        if selectedTab == .gameDay {
            appModel.beginGameDayVisitForRatingIfNeeded()
            appModel.refreshGameDayWarmup()
        }
        if !launchedWithOpenGameDayRequest,
           openGameDayRequestCenter.pendingRequest == nil {
            presentAutomaticWhatsNewIfPossible()
            presentAutomaticRatingRequestIfPossible()
        }
    }

    private func handlePackageImportPick(_ url: URL) {
        let context = packageImportContext
        packageImportPresented = false
        Task {
            switch context {
            case .settings:
                await appModel.preparePackageImportConfirmation(from: url, opensOnboardingHandoff: false)
            case .onboarding:
                await appModel.preparePackageImportConfirmation(from: url, opensOnboardingHandoff: true)
            }
        }
    }

    private func playerForEditorRoute(_ route: PlayerEditorRoute) -> Player? {
        appModel.selectedTeam?.players.first(where: { $0.id == route.id })
    }

    private func resolveInitialTabIfNeeded() {
        guard !hasResolvedInitialTab else { return }
        hasResolvedInitialTab = true
        let initialTab = RootTab.sensibleInitialTab(for: appModel.selectedTeam)
        if initialTab == .gameDay, selectedTab != .gameDay {
            suppressNextGameDayRecencyUpdate = true
        }
        selectedTab = initialTab
    }

    private func submitOpenGameDayURL(_ url: URL) -> Bool {
        guard let target = url.rollCallOpenGameDayTarget else { return false }
        let explicitTeamID: UUID?
        switch target {
        case .rememberedTeam:
            explicitTeamID = nil
        case .explicitTeam(let teamID):
            explicitTeamID = teamID
        }
        openGameDayRequestCenter.submit(
            OpenGameDayRequest(explicitTeamID: explicitTeamID, source: .systemControl)
        )
        processPendingOpenGameDayRequestIfPossible()
        return true
    }

    private func processPendingOpenGameDayRequestIfPossible() {
        guard hasResolvedInitialTab,
              let request = openGameDayRequestCenter.pendingRequest else { return }

        if whatsNewPresentation == .automatic {
            whatsNewPresentation = nil
        }
        if ratingRequestPresentation == .automatic {
            appModel.cancelRatingSheetBeforeAppearance(token: ratingPresentationToken)
            ratingPresentationToken = nil
            ratingRequestPresentation = nil
        }

        guard !hasBlockingWhatsNewPresentation else { return }
        let resolution = appModel.resolveOpenGameDay(request)
        switch resolution {
        case .gameDay:
            selectedTab = .gameDay
            appModel.recordQuickGameDayReached()
        case .fallback:
            selectedTab = appModel.state.teams.isEmpty ? .players : .teams
        }
        openGameDayRequestCenter.consume(id: request.id)
    }

    @ViewBuilder
    private func playerEditorSheet(for route: PlayerEditorRoute) -> some View {
        if let player = playerForEditorRoute(route) {
            PlayerEditorSheet(appModel: appModel, player: player)
                .teamAccentScope(selectedTeamAccentTheme)
        } else {
            ContentUnavailableView("Player Not Found", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("The selected player is no longer on the current team."))
                .teamAccentScope(selectedTeamAccentTheme)
        }
    }

    var body: some View {
        rootLifecycleContent
    }

    private var rootBaseContent: some View {
        rootContent
            .rollCallTeamAccentTheme(selectedTeamAccentTheme)
            .tint(selectedTeamAccentTheme.color(.primary))
            .task { await finishLaunchingTask() }
            .onOpenURL { url in
                if !submitOpenGameDayURL(url) {
                    appModel.handleIncomingPackage(url)
                }
            }
            .onChange(of: openGameDayRequestCenter.pendingRequest) { _, _ in
                processPendingOpenGameDayRequestIfPossible()
            }
            .onChange(of: hasBlockingWhatsNewPresentation) { _, isBlocked in
                if !isBlocked {
                    processPendingOpenGameDayRequestIfPossible()
                }
            }
            .onChange(of: appModel.shouldShowOnboarding) { _, shouldShowOnboarding in
                if !shouldShowOnboarding {
                    hasEnteredOnboardingFlow = false
                }
            }
            .onChange(of: appModel.completedPackageImportTeamID) { _, importedTeamID in
                guard importedTeamID != nil else { return }
                selectedTab = .teams
            }
            .onChange(of: appModel.pendingRecoveryNavigation) { _, destination in
                guard let destination else { return }
                switch destination {
                case .players:
                    selectedTab = .players
                case .customClip(let clipID):
                    selectedTab = .generalClips
                    showTeamClips = true
                    customClipManagerInitialClipID = clipID
                }
                appModel.pendingRecoveryNavigation = nil
            }
            .onChange(of: canPresentAutomaticWhatsNew) { _, canPresent in
                if canPresent {
                    presentAutomaticWhatsNewIfPossible()
                }
            }
            .onChange(of: canPresentAutomaticRatingRequest) { _, canPresent in
                if canPresent {
                    presentAutomaticRatingRequestIfPossible()
                }
            }
            .overlay(alignment: .top) {
                ZStack(alignment: .top) {
                    if appModel.riskyOperationCount > 0 {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .accessibilityHidden(true)

                        ProgressView("Working…")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .accessibilityAddTraits(.isModal)
                    }

                    VStack(spacing: 8) {
                        if let bannerMessage = appModel.bannerMessage {
                            AppBannerView(message: bannerMessage)
                        }
                    }
                }
                .padding(.top, 8)
            }
    }

    private var rootAlertContent: some View {
        rootBaseContent
            .alert("Roll Call", isPresented: errorBinding) {
                Button("OK") { appModel.lastError = nil }
            } message: {
                Text(appModel.lastError ?? "")
            }
            .alert("Rename Team", isPresented: $showRenameTeamAlert) {
                TextField("Team name", text: $renameTeamName)
                Button("Cancel", role: .cancel) {}
                Button("Rename") {
                    appModel.renameSelectedTeam(to: renameTeamName)
                }
                .disabled(renameTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Update the selected team name.")
            }
            .alert("Remove Team?", isPresented: $showRemoveTeamConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    appModel.removeSelectedTeam()
                }
            } message: {
                if let team = appModel.selectedTeam {
                    Text("Remove \(team.name) from this device? This deletes that team's \(team.players.count) players, lineup state, clips, and custom intros from the app. You can restore it later from Recovery. Existing exports and backups stay untouched.")
                } else {
                    Text("Remove the selected team from this device. You can restore it later from Recovery. Existing exports and backups stay untouched.")
                }
            }
    }

    private var rootSheetContent: some View {
        rootAlertContent
            .sheet(item: Binding(get: { appModel.pendingPackageExport }, set: { appModel.pendingPackageExport = $0 })) { pending in
                PackageExportPreviewSheet(
                    pending: pending,
                    onExport: {
                        Task {
                            await appModel.confirmPendingPackageExport()
                            if appModel.exportURL != nil {
                                packageSharePresented = true
                            }
                        }
                    },
                    onPrepareFirst: {
                        appModel.cancelPendingPackageExport()
                        appModel.prepareSongsForReadiness()
                        selectedTab = .readiness
                    },
                    onCancel: {
                        appModel.cancelPendingPackageExport()
                    }
                )
                .interactiveDismissDisabled()
            }
            .sheet(item: Binding(get: { appModel.pendingPackageImport }, set: { appModel.pendingPackageImport = $0 })) { pending in
                PackageImportConfirmationSheet(
                    pending: pending,
                    onImport: {
                        Task { await appModel.confirmPendingPackageImport() }
                    },
                    onCancel: {
                        appModel.cancelPendingPackageImport()
                    }
                )
                .interactiveDismissDisabled()
            }
            .sheet(item: Binding(get: { appModel.completedPackageImportAudit }, set: { appModel.completedPackageImportAudit = $0 })) { audit in
                PackageImportAuditSheet(
                    audit: audit,
                    onAppleMusicCheck: {
                        Task { await appModel.checkAppleMusicForCompletedPackageImport() }
                    },
                    onRepair: { item in
                        openImportedRepair(item, audit: audit)
                    },
                    onDone: {
                        appModel.completedPackageImportAudit = nil
                    }
                )
            }
            .sheet(item: Binding(get: { appModel.pendingRosterImport }, set: { appModel.pendingRosterImport = $0 })) { pending in
                let duplicateCount = pending.duplicateCount(
                    comparedTo: appModel.state.teams.first(where: { $0.id == pending.targetTeamID })?.players ?? []
                )
                RosterImportPreviewSheet(
                    pending: pending,
                    duplicateCount: duplicateCount,
                    duplicateMessage: PendingRosterImport.duplicateMessage(count: duplicateCount),
                    onCancel: {
                        appModel.discardPendingRosterImport()
                    },
                    onImport: {
                        Task { await appModel.applyPendingRosterImport() }
                    }
                )
            }
            .sheet(isPresented: $packageImportPresented) {
                RollCallPackageImportSheet(
                    onPick: handlePackageImportPick,
                    onCancel: {
                        packageImportPresented = false
                    }
                )
            }
            .sheet(item: $playerEditorRoute) { route in
                playerEditorSheet(for: route)
            }
            .sheet(item: $whatsNewPresentation) { presentation in
                WhatsNewSheet(
                    bundle: .current,
                    onDone: {
                        appModel.markCurrentWhatsNewSeen()
                        whatsNewPresentation = nil
                    }
                )
                .teamAccentScope(selectedTeamAccentTheme)
            }
            .sheet(item: $teamPlaylistPreview) { summary in
                TeamAppleMusicPlaylistPreviewSheet(
                    appModel: appModel,
                    summary: summary,
                    onDone: {
                        teamPlaylistPreview = nil
                    }
                )
                .teamAccentScope(selectedTeamAccentTheme)
            }
            .sheet(isPresented: $showTeamClips, onDismiss: {
                customClipManagerInitialClipID = nil
            }) {
                CustomClipsManagerSheet(
                    appModel: appModel,
                    initialClipID: customClipManagerInitialClipID
                )
                    .teamAccentScope(selectedTeamAccentTheme)
            }
            .alert("Custom Clip Unavailable", isPresented: Binding(
                get: { customClipRepairPrompt != nil },
                set: { if !$0 { customClipRepairPrompt = nil } }
            ), presenting: customClipRepairPrompt) { clip in
                Button("Cancel", role: .cancel) {
                    customClipRepairPrompt = nil
                }
                Button("Repair Clip") {
                    customClipManagerInitialClipID = clip.id
                    customClipRepairPrompt = nil
                    showTeamClips = true
                }
            } message: { clip in
                Text(
                    clip.readinessInputs.playback == .needsAppleMusic
                        ? "This clip needs Apple Music access on this device."
                        : "This clip needs a replacement source before it can play."
                )
            }
            .fileImporter(isPresented: $csvImportPresented, allowedContentTypes: [.commaSeparatedText, .text], allowsMultipleSelection: false) { result in
                handleRosterImportResult(result)
            }
    }

    private var rootLifecycleContent: some View {
        rootSheetContent
            .onAppear {
                updateIdleTimer()
                appModel.setSongClipPreparationLiveUseThrottled(
                    selectedTab == .gameDay || selectedTab == .generalClips
                )
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: selectedTab) { previousTab, newTab in
                handleSelectedTabChange(from: previousTab, to: newTab)
            }
            .onChange(of: scenePhase) { previousPhase, newPhase in
                handleScenePhaseChange(from: previousPhase, to: newPhase)
            }
            .onChange(of: appModel.state.settings.keepScreenAwakeDuringLiveUse) { _, _ in
                updateIdleTimer()
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        if appModel.shouldShowOnboarding {
            if hasEnteredOnboardingFlow {
                OnboardingRootView(
                    appModel: appModel,
                    onImportPackage: {
                        packageImportContext = .onboarding
                        packageImportPresented = true
                    },
                    onOpenGameDay: {
                        appModel.completeOnboarding()
                        selectedTab = .gameDay
                    },
                    onOpenReadiness: {
                        appModel.completeOnboarding()
                        selectedTab = .readiness
                    }
                )
            } else {
                OnboardingWelcomeView {
                    hasEnteredOnboardingFlow = true
                }
            }
        } else {
            mainTabs
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            gameDayTab
                .offset(x: selectedTab == .gameDay ? liveSurfaceSwipeOffset : 0)
                .teamAccentScope(selectedTeamAccentTheme)
                .tag(RootTab.gameDay)
                .tabItem { Label("Game Day", systemImage: "play.rectangle.fill") }

            generalClipsTab
                .offset(x: selectedTab == .generalClips ? liveSurfaceSwipeOffset : 0)
                .teamAccentScope(selectedTeamAccentTheme)
                .tag(RootTab.generalClips)
                .tabItem { Label("Clips", systemImage: "music.note.list") }

            playersTab
                .teamAccentScope(selectedTeamAccentTheme)
                .tag(RootTab.players)
                .tabItem { Label("Players", systemImage: "person.3.fill") }

            teamsTab
                .teamAccentScope(selectedTeamAccentTheme)
                .tag(RootTab.teams)
                .tabItem { Label("Teams", systemImage: "list.number") }

            readinessTab
                .teamAccentScope(selectedTeamAccentTheme)
                .tag(RootTab.readiness)
                .tabItem { Label("Readiness", systemImage: "checklist") }

            settingsTab
                .teamAccentScope(selectedTeamAccentTheme)
                .tag(RootTab.settings)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .teamAccentScope(selectedTeamAccentTheme)
        .background(TabBarAccentUpdater(theme: selectedTeamAccentTheme).frame(width: 0, height: 0))
        .background(liveSurfaceSwipeInstaller)
        .onAppear { applyTabBarAccent(selectedTeamAccentTheme) }
        .onChange(of: selectedTeamAccentTheme) { _, theme in
            applyTabBarAccent(theme)
        }
    }

    private var playersTab: some View {
        NavigationStack {
            List {
                if let team = appModel.selectedTeam {
                    Section {
                        PlayerQuickAddView(appModel: appModel)
                    } header: {
                        PlayersSectionHeader(
                            title: "Add Player",
                            helperText: "Fast roster entry stays here; detailed cue and photo setup opens from each player row."
                        )
                    }

                    Section {
                        ForEach(playersTabRoster(for: team)) { player in
                            let cue = team.cue(for: player)
                            let hasCustomIntro = appModel.hasStoredCustomAnnouncer(for: player)
                            let isCustomIntroMissing = player.customAnnouncerRelativePath != nil && !hasCustomIntro
                            let isPresent = player.isPresent
                            Button {
                                presentPlayerEditor(for: player)
                            } label: {
                                PlayerRosterRow(
                                    player: player,
                                    cue: cue,
                                    isPresent: isPresent,
                                    hasCustomIntro: hasCustomIntro,
                                    isCustomIntroMissing: isCustomIntroMissing
                                )
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(isPresent ? "Mark Out" : "Mark In") { appModel.togglePresent(player) }
                                    .tint(isPresent ? .red : .green)
                            }
                        }
                    } header: {
                        PlayersSectionHeader(
                            title: "Roster",
                            helperText: "\(team.players.count) players sorted by name. Players marked out are hidden from Game Day."
                        )
                    }
                } else {
                    ContentUnavailableView("No Team Selected", systemImage: "person.3.sequence.fill", description: Text("Create or select a team on the Teams tab."))
                }
            }
            .listStyle(.insetGrouped)
            .accentWashListBackground()
            .navigationTitle("Players")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader()
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissesKeyboardOnTap()
        }
    }

    private var playersTabTitle: String {
        if let teamName = appModel.selectedTeam?.name, !teamName.isEmpty {
            return "Players - \(teamName)"
        }
        return "Players"
    }

    private func playersTabRoster(for team: Team) -> [Player] {
        team.players.sorted { lhs, rhs in
            let lhsName = playerSortNameParts(lhs)
            let rhsName = playerSortNameParts(rhs)
            if lhsName.first != rhsName.first {
                return lhsName.first.localizedCaseInsensitiveCompare(rhsName.first) == .orderedAscending
            }
            if lhsName.remainder != rhsName.remainder {
                return lhsName.remainder.localizedCaseInsensitiveCompare(rhsName.remainder) == .orderedAscending
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func playerSortNameParts(_ player: Player) -> (first: String, remainder: String) {
        let trimmedName = player.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let splitIndex = trimmedName.firstIndex(where: \.isWhitespace) else {
            return (trimmedName, "")
        }

        let firstName = String(trimmedName[..<splitIndex])
        let remainder = trimmedName[splitIndex...].trimmingCharacters(in: .whitespacesAndNewlines)
        return (firstName, remainder)
    }

    private func rootTeamBannerHeader(
        variant: TeamBannerVariant = .standard,
        secondaryStatus: TeamBannerSecondaryStatus? = nil
    ) -> some View {
        VStack(spacing: 0) {
            TeamBanner(
                teamName: appModel.selectedTeam?.name,
                secondaryStatus: secondaryStatus ?? selectedTeamBannerStatus,
                accentColor: selectedTeamAccentTheme.color(.primary, surface: variant == .liveSide ? .live : .standard),
                variant: variant
            )
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("root-team-banner")
            .padding(.horizontal, 6)

            Rectangle()
                .fill(Color.rollCall(.neutralStructure, surface: variant == .liveSide ? .live : .standard).opacity(0.55))
                .frame(height: 1)
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background {
            rootTeamBannerBackground(for: variant)
                .ignoresSafeArea(edges: .top)
        }
    }

    @ViewBuilder
    private func rootTeamBannerBackground(for variant: TeamBannerVariant) -> some View {
        RootTeamBannerMaterialBackground(variant: variant)
    }

    private struct RootTeamBannerMaterialBackground: View {
        let variant: TeamBannerVariant

        var body: some View {
            ZStack {
                if #available(iOS 26.0, *) {
                    Rectangle()
                        .fill(.clear)
                        .glassEffect(.regular.tint(materialTint), in: .rect(cornerRadius: 0))
                } else {
                    Rectangle()
                        .fill(.regularMaterial)
                }

                materialTint.opacity(overlayOpacity)
            }
        }

        private var materialTint: Color {
            switch variant {
            case .standard:
                return Color(uiColor: .systemGroupedBackground)
            case .liveSide:
                return Color.rollCall(.neutralSurface, surface: .live)
            }
        }

        private var overlayOpacity: Double {
            switch variant {
            case .standard:
                return 0.72
            case .liveSide:
                return 0.64
            }
        }
    }

    private var generalClipsTab: some View {
        NavigationStack {
            ZStack {
                AccentWashBackground(surface: .live)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if appModel.selectedTeamBuiltInClips.isEmpty && appModel.selectedTeamCustomClips.isEmpty {
                            ClipsEmptyStateCard(surface: clipsSurface)
                        } else {
                            Text("Sound Effects")
                                .rollCallText(.sectionTitle, surface: clipsSurface)

                            LazyVGrid(columns: soundEffectGridColumns, spacing: 8) {
                                ForEach(appModel.selectedTeamBuiltInClips) { clip in
                                    GeneralClipCard(
                                        clip: clip,
                                        surface: clipsSurface,
                                        isPlaying: playbackEngine.activeCueID == clip.cue.id
                                    ) {
                                        Task { await appModel.play(builtInClip: clip) }
                                    }
                                }
                            }

                            Text("Custom Clips")
                                .rollCallText(.sectionTitle, surface: clipsSurface)
                                .padding(.top, 8)

                            if appModel.selectedTeamCustomClips.isEmpty {
                                Text("Use Edit to add quick song clips for live sideline moments.")
                                    .rollCallText(.helperText, surface: clipsSurface)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color.rollCall(.neutralSurface, surface: .live), in: RoundedRectangle(cornerRadius: 12))
                            } else {
                                LazyVGrid(columns: customClipGridColumns, spacing: 10) {
                                    ForEach(appModel.selectedTeamCustomClips) { clip in
                                        CustomClipCard(
                                            clip: clip,
                                            surface: clipsSurface,
                                            isPlayable: appModel.customClipCanPlay(clip),
                                            isPlaying: playbackEngine.activeCueID == clip.playbackCue.id
                                        ) {
                                            if appModel.customClipCanPlay(clip) {
                                                Task { await appModel.play(customClip: clip) }
                                            } else {
                                                customClipRepairPrompt = clip
                                            }
                                        }
                                    }
                                }
                            }

                            HStack {
                                Spacer()
                                Button("Edit") {
                                    appModel.stopPlayback()
                                    customClipManagerInitialClipID = nil
                                    showTeamClips = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.horizontal, 19)
                    .padding(.top, 14)
                    .padding(.bottom, 34)
                }
            }
            .navigationTitle("Clips")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader(variant: clipsTeamBannerVariant)
            }
        }
        .environment(\.colorScheme, effectiveLiveColorScheme)
    }

    private var soundEffectGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: 8), count: 5)
    }

    private var customClipGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    }

    private struct ClipsEmptyStateCard: View {
        let surface: RollCallSurfaceVariant

        var body: some View {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                Image(systemName: "speaker.slash.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.rollCall(.warning, surface: surface))

                VStack(alignment: .leading, spacing: 4) {
                    Text("No clips ready")
                        .rollCallText(.cardTitle, surface: surface)
                    Text("Select a team to use the built-in crowd clip library.")
                        .rollCallText(.helperText, surface: surface)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .rollCallCard(surface == .live ? .live : .utility, surface: surface)
        }
    }

    private struct GeneralClipCard: View {
        let clip: BuiltInClip
        let surface: RollCallSurfaceVariant
        let isPlaying: Bool
        let play: () -> Void

        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

        var body: some View {
            Button(action: play) {
                VStack(spacing: 6) {
                    if isPlaying {
                        PlayingSpeakerSymbol(systemImage: soundSymbol, color: Color.rollCall(.live, surface: .live))
                            .font(.caption.weight(.bold))
                    } else {
                        Image(systemName: soundSymbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(teamAccentTheme.color(.primary, surface: .live))
                    }

                    Text(clip.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(uiColor: .label))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.62)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 68, alignment: .center)
                .background(cardBackground)
                .overlay(cardBorder)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .shadow(color: cardShadowColor, radius: isPlaying ? 8 : 0, y: isPlaying ? 4 : 0)
            .animation(.easeInOut(duration: 0.16), value: isPlaying)
            .accessibilityLabel("Play \(clip.title)")
            .accessibilityValue(isPlaying ? "Currently playing" : "")
            .accessibilityHint(isPlaying ? "Stops the active built-in crowd clip." : "Plays this built-in crowd clip.")
        }

        private var cardBackground: some ShapeStyle {
            if isPlaying {
                return LinearGradient(
                    colors: [
                        Color.rollCall(.live, surface: .live).opacity(0.22),
                        Color.rollCall(.live, surface: .live).opacity(0.14)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            if surface == .live {
                return LinearGradient(
                    colors: [
                        Color.rollCall(.neutralSurface, surface: .live),
                        Color.rollCall(.neutralSurface, surface: .live).opacity(0.82)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [
                    Color(uiColor: .secondarySystemGroupedBackground),
                    Color(uiColor: .secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        private var cardBorder: some View {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(cardBorderColor, lineWidth: isPlaying ? 2 : 1)
        }

        private var cardBorderColor: Color {
            if isPlaying {
                return Color.rollCall(.live, surface: .live).opacity(0.95)
            }
            return liveAccentOutlineColor(theme: teamAccentTheme, colorScheme: colorScheme, lightOpacity: 0.85, darkOpacity: 0.42)
        }

        private var cardShadowColor: Color {
            isPlaying ? Color.rollCall(.live, surface: .live).opacity(0.20) : .clear
        }

        private var soundSymbol: String {
            let title = clip.title.lowercased()
            if title.contains("cheer") {
                return firstAvailableSymbol(["hands.clap.fill", "hand.wave.fill", "speaker.wave.2.fill"])
            }
            if title.contains("victory") || title.contains("roar") {
                return firstAvailableSymbol(["trophy.fill", "megaphone.fill", "speaker.wave.3.fill"])
            }
            if title.contains("stadium") || title.contains("burst") {
                return firstAvailableSymbol(["burst.fill", "sparkles", "speaker.wave.3.fill"])
            }
            if title.contains("clap") || title.contains("rhythmic") {
                return firstAvailableSymbol(["metronome.fill", "hands.clap.fill", "music.note"])
            }
            if title.contains("whistle") {
                return firstAvailableSymbol(["whistle.fill", "speaker.wave.2.fill"])
            }
            return firstAvailableSymbol(["waveform", "speaker.wave.2.fill"])
        }

        private func firstAvailableSymbol(_ symbols: [String]) -> String {
            symbols.first { UIImage(systemName: $0) != nil } ?? "speaker.wave.2.fill"
        }
    }

    private struct CustomClipCard: View {
        let clip: SongClip
        let surface: RollCallSurfaceVariant
        let isPlayable: Bool
        let isPlaying: Bool
        let play: () -> Void

        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

        private var status: (text: String, role: StatusChipRole)? {
            if clip.generatedAsset.status == .pending {
                return ("Preparing", .neutral)
            }
            switch clip.readinessInputs.playback {
            case .needsAppleMusic:
                return ("Needs Apple Music", .warning)
            case .needsRepair:
                return ("Needs Repair", .warning)
            default:
                return nil
            }
        }

        var body: some View {
            Button(action: play) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(clip.displayName ?? clip.playbackCue.rosterDisplayTitle)
                        .font(.callout.weight(.bold))
                        .foregroundStyle(Color(uiColor: .label))
                        .lineLimit(2)
                        .minimumScaleFactor(0.74)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let status {
                        Text(status.text)
                            .font(.caption2.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(statusColor(status.role))
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, minHeight: 82, alignment: .center)
                .background(
                    customClipBackgroundColor,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(
                            customClipBorderColor,
                            lineWidth: isPlaying ? 2 : 1
                        )
                }
            }
            .buttonStyle(.plain)
            .shadow(color: customClipShadowColor, radius: isPlaying ? 8 : 0, y: isPlaying ? 4 : 0)
            .animation(.easeInOut(duration: 0.16), value: isPlaying)
            .accessibilityLabel(clip.displayName ?? clip.playbackCue.rosterDisplayTitle)
            .accessibilityValue(isPlaying ? "Currently playing" : "")
            .accessibilityHint(isPlayable ? "Plays this Custom Clip." : "Explains what this Custom Clip needs before it can play.")
        }

        private func statusColor(_ role: StatusChipRole) -> Color {
            switch role {
            case .live:
                return Color.rollCall(.live, surface: .live)
            case .ready:
                return Color.rollCall(.ready, surface: .live)
            case .warning:
                return Color.rollCall(.warning, surface: surface)
            case .destructive:
                return Color.rollCall(.destructive, surface: surface)
            case .disabled:
                return Color.rollCall(.disabled, surface: surface)
            case .neutral:
                return Color(uiColor: .secondaryLabel)
            }
        }

        private var customClipBackgroundColor: Color {
            if isPlaying {
                return Color.rollCall(.live, surface: .live).opacity(0.22)
            }
            return Color.rollCall(.neutralSurface, surface: .live)
        }

        private var customClipBorderColor: Color {
            if isPlaying {
                return Color.rollCall(.live, surface: .live).opacity(0.95)
            }
            if isPlayable {
                return liveAccentOutlineColor(theme: teamAccentTheme, colorScheme: colorScheme, lightOpacity: 0.85, darkOpacity: 0.42)
            }
            return Color.rollCall(.warning, surface: surface)
        }

        private var customClipShadowColor: Color {
            isPlaying ? Color.rollCall(.live, surface: .live).opacity(0.20) : .clear
        }
    }

    private var gameDayTab: some View {
        NavigationStack {
            ZStack {
                GameDayBackground()
                    .ignoresSafeArea()
                GameDayBoard(appModel: appModel) {
                    showLineupEditor = true
                }
            }
            .navigationTitle("Game Day")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader(variant: .liveSide, secondaryStatus: gameDayTeamBannerStatus)
            }
            .sheet(isPresented: $showLineupEditor) {
                LineupEditorSheet(appModel: appModel, isLiveUse: true)
                    .environment(\.colorScheme, effectiveLiveColorScheme)
            }
        }
        .environment(\.colorScheme, effectiveLiveColorScheme)
    }

    private var readinessTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                    if let readiness = appModel.selectedTeamReadiness {
                        ReadinessOverviewCard(
                            readiness: readiness,
                            team: appModel.selectedTeam,
                            onOpenGameDay: { selectedTab = .gameDay }
                        ) {
                            appModel.refreshReadiness()
                        }

                        ReadinessPlayerAudioCard(
                            checks: playerAudioReadinessChecks(from: readiness.checks),
                            playerForCheck: playerForReadinessCheck,
                            onEditPlayer: presentPlayerEditor
                        )

                        ReadinessEnhancementsCard(
                            checks: announcementReadinessChecks(from: readiness.checks),
                            playerAudioChecks: playerAudioReadinessChecks(from: readiness.checks),
                            playerForCheck: playerForReadinessCheck,
                            onEditPlayer: presentPlayerEditor
                        )

                        ReadinessOptionalUpgradesCard(
                            checks: optionalUpgradeReadinessChecks(from: readiness.checks),
                            playerForCheck: playerForReadinessCheck,
                            onEditPlayer: presentPlayerEditor
                        )

                        ReadinessGameDayChecksCard(
                            checks: gameDayReadinessChecks(from: readiness.checks),
                            onRequestAppleMusicAccess: {
                                Task { await appModel.requestAppleMusicAccess() }
                            }
                        )
                    } else {
                        ReadinessEmptyCard {
                            appModel.refreshReadiness()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, RollCallSpacingTier.tight.value)
                .padding(.bottom, RollCallSpacingTier.large.value)
            }
            .accentWashBackground()
            .navigationTitle("Readiness")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader()
            }
        }
    }

    private var teamsTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                    if let team = appModel.selectedTeam {
                        TeamsSectionGroup(
                            title: "Current Team",
                            helperText: "Lifecycle tools stay here so they do not interrupt normal team selection."
                        ) {
                            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                                SelectedTeamSummary(team: team)

                                VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                                    Text("Team Color")
                                        .rollCallText(.cardTitle)
                                    AccentPresetGrid(selectedAccent: Binding(
                                        get: { team.accentPreset },
                                        set: { appModel.setAccentPreset($0, for: team.id) }
                                    ))
                                }

                                Menu {
                                    Button("Rename Selected Team") {
                                        renameTeamName = appModel.selectedTeam?.name ?? ""
                                        showRenameTeamAlert = true
                                    }
                                    Button("Duplicate Selected Team") { appModel.duplicateTeam() }
                                    Button("Remove Selected Team", role: .destructive) {
                                        showRemoveTeamConfirmation = true
                                    }
                                } label: {
                                    Label("Manage Team", systemImage: "ellipsis.circle")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(RollCallButtonStyle(
                                    family: .secondary,
                                    surface: .standard,
                                    teamAccentTheme: selectedTeamAccentTheme
                                ))

                                Text("Rename, duplicate, or remove the selected team from Manage Team.")
                                    .rollCallText(.helperText)
                            }
                        }
                    }

                    TeamsSectionGroup(
                        title: "Team Setup",
                        helperText: "Bring roster data into the selected team."
                    ) {
                        VStack(spacing: RollCallSpacingTier.standard.value) {
                            Button {
                                csvImportPresented = true
                            } label: {
                                SettingsRowLabel(
                                    title: "Import Roster CSV",
                                    detail: "Add players from a simple roster file.",
                                    systemImage: "tablecells"
                                )
                            }
                            .rollCallButtonStyle(.secondary)
                            .disabled(appModel.selectedTeam == nil)

                            VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                                Text("Roster CSV format: name, number. Use a header row or simple two-column rows; player number is optional.")
                                    .rollCallText(.helperText)
                            }
                        }
                    }

                    TeamsSectionGroup(
                        title: "Share Team",
                        helperText: "Move teams between devices or share them with another coach."
                    ) {
                        VStack(spacing: RollCallSpacingTier.standard.value) {
                            Button {
                                appModel.prepareSelectedTeamExport()
                            } label: {
                                SettingsRowLabel(
                                    title: "Share Team Package",
                                    detail: "Create a portable .rollcall package and choose where to send or save it.",
                                    systemImage: "shippingbox.fill",
                                    style: .filledAction
                                )
                            }
                            .rollCallButtonStyle(.primary)
                            .disabled(appModel.selectedTeam == nil)

                            Button {
                                packageImportContext = .settings
                                packageImportPresented = true
                            } label: {
                                SettingsRowLabel(
                                    title: "Import Team Package",
                                    detail: "Add a shared .rollcall package as a new team. Existing teams stay unchanged.",
                                    systemImage: "tray.and.arrow.down.fill"
                                )
                            }
                            .rollCallButtonStyle(.secondary)

                            Button {
                                appModel.clearAppleMusicPlaylistStatus()
                                teamPlaylistPreview = appModel.selectedTeamAppleMusicPlaylistSummary()
                            } label: {
                                SettingsRowLabel(
                                    title: "Create Apple Music Playlist",
                                    detail: "Create or update a playlist from this team's player songs.",
                                    systemImage: "music.note.list"
                                )
                            }
                            .rollCallButtonStyle(.secondary)
                            .disabled(appModel.selectedTeam == nil)
                        }
                    }

                    TeamsSectionGroup(
                        title: "Teams",
                        helperText: "Choose, create, or import the roster Roll Call should use."
                    ) {
                        VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                            if appModel.state.teams.isEmpty {
                                TeamsEmptyState()
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(appModel.state.teams.enumerated()), id: \.element.id) { index, team in
                                        if index > 0 {
                                            Divider()
                                                .padding(.leading, 46)
                                        }

                                        Button {
                                            appModel.selectTeam(team)
                                        } label: {
                                            TeamSelectionRow(
                                                team: team,
                                                isSelected: appModel.state.selectedTeamID == team.id
                                            )
                                            .padding(.vertical, RollCallSpacingTier.tight.value)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            Divider()

                            TextField("Team name", text: $newTeamName)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                appModel.addTeam(named: newTeamName)
                                newTeamName = ""
                            } label: {
                                SettingsRowLabel(
                                    title: "Create Team",
                                    detail: "Add a new team, then choose it above.",
                                    systemImage: "plus",
                                    style: .filledAction
                                )
                            }
                            .rollCallButtonStyle(.primary)
                            .disabled(newTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, RollCallSpacingTier.tight.value)
                .padding(.bottom, RollCallSpacingTier.large.value)
                .padding(.bottom, 72)
            }
            .accentWashBackground()
            .navigationTitle("Teams")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader()
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissesKeyboardOnTap()
        }
    }

    private var selectedTeamBannerStatus: TeamBannerSecondaryStatus? {
        guard let team = appModel.selectedTeam else {
            return TeamBannerSecondaryStatus(text: "Choose or create a team")
        }
        return TeamBannerSecondaryStatus(
            text: "\(team.players.count) players • \(team.presentPlayersInBattingOrder.count) present"
        )
    }

    private var gameDayTeamBannerStatus: TeamBannerSecondaryStatus? {
        guard let team = appModel.selectedTeam else {
            return TeamBannerSecondaryStatus(text: "Choose or create a team", tone: .warning)
        }
        if hasLiveGameDayWarning(for: team) {
            return TeamBannerSecondaryStatus(text: "Warnings", tone: .warning)
        }
        return TeamBannerSecondaryStatus(
            text: "\(team.players.count) players • \(team.presentPlayersInBattingOrder.count) present"
        )
    }

    private func hasLiveGameDayWarning(for team: Team) -> Bool {
        let presentPlayers = team.presentPlayersInBattingOrder
        if presentPlayers.isEmpty {
            return true
        }

        guard let readiness = appModel.selectedTeamReadiness else { return false }
        return readiness.checks.contains { check in
            guard check.state == .issue else { return false }
            if check.category == .playerPhoto { return false }
            if check.category == .playerAnnouncement {
                return team.session.gameDayAnnouncerMode.usesAnnouncer
            }
            if check.category == .playerAudio {
                return check.playerID.map { playerID in presentPlayers.contains { $0.id == playerID } } ?? false
            }
            if check.category == .volume {
                return !appModel.state.settings.fadeOutVolumeAutomationEnabled
            }
            return [.audioRoute, .network, .appleMusicAccess, .lineup].contains(check.category)
        }
    }

    private var feedbackEmailURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "johnkfisher@mac.com"
        components.queryItems = [
            URLQueryItem(
                name: "subject",
                value: "Roll Call Feedback - Version \(AppMetadata.appVersion) (\(AppMetadata.buildNumber)) \(BuildEnvironment.current.rawValue)"
            )
        ]
        return components.url ?? URL(string: "mailto:johnkfisher@mac.com")!
    }

    private func openSupportScreenFromRatingPrompt() {
        ratingRequestPresentation = nil
        selectedTab = .settings
        supportScreenPresented = true
    }

    private func manageSupportSubscriptions() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            return
        }

        Task {
            try? await AppStore.showManageSubscriptions(in: scene)
        }
    }

    private var settingsTab: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                    SettingsSectionGroup(title: "Roll Call") {
                        NavigationLink {
                            aboutRollCallScreen
                        } label: {
                            SettingsNavigationLabel(
                                title: "About Roll Call",
                                detail: "Version, feedback, release notes, and credits.",
                                systemImage: "baseball.fill"
                            )
                        }
                        .buttonStyle(.plain)

                        Toggle(isOn: Binding(
                            get: { appModel.anonymousUsageAnalyticsEnabled },
                            set: { appModel.setAnonymousUsageAnalyticsEnabled($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Anonymous Usage Analytics",
                                detail: "Share anonymous product-use signals with TelemetryDeck. No team, player, song, photo, recording, or file content is sent. You can turn this off at any time.",
                                systemImage: "chart.bar.xaxis"
                            )
                        }
                        .tint(selectedTeamAccentTheme.color(.primary))

                    }

                    SettingsSectionGroup(
                        title: "Team & Setup",
                        helperText: "Reopen guided setup or jump to team package tools."
                    ) {
                        VStack(spacing: RollCallSpacingTier.standard.value) {
                            Button {
                                appModel.beginSetupGuide()
                            } label: {
                                SettingsRowLabel(
                                    title: "Open Setup Guide",
                                    detail: "Launch onboarding again without changing existing teams.",
                                    systemImage: "sparkles"
                                )
                            }
                            .rollCallButtonStyle(.secondary)

                            Button {
                                selectedTab = .teams
                            } label: {
                                SettingsRowLabel(
                                    title: "Import or Export Teams",
                                    detail: "Team sharing and import tools now live on the Teams tab.",
                                    systemImage: "person.3.sequence.fill"
                                )
                            }
                            .rollCallButtonStyle(.secondary)
                        }
                    }

                    SettingsSectionGroup(
                        title: "Music & Playback",
                        helperText: "Keep songs clear for coaches and playback predictable during live use."
                    ) {
                        Toggle(isOn: Binding(
                            get: { appModel.state.settings.explicitAppleMusicSearchFilteringEnabled },
                            set: { appModel.setExplicitAppleMusicSearchFilteringEnabled($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Hide Explicit Apple Music Results",
                                detail: "Filters explicit songs from Apple Music search. Music Library songs may still need confirmation.",
                                systemImage: "music.note.list"
                            )
                        }
                        .tint(selectedTeamAccentTheme.color(.primary))

                        Toggle(isOn: Binding(
                            get: { appModel.state.settings.fadeOutVolumeAutomationEnabled },
                            set: { appModel.setFadeOutVolumeAutomationEnabled($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Volume Automation",
                                detail: "Fade Apple Music down at end of song clip, then restore your previous volume.",
                                systemImage: "speaker.wave.2.fill"
                            )
                        }
                        .tint(selectedTeamAccentTheme.color(.primary))
                    }

                    SettingsSectionGroup(
                        title: "Game Day",
                        helperText: "Keep live-use preferences simple and predictable."
                    ) {
                        Button {
                            quickGameDayHelpPresented = true
                        } label: {
                            SettingsRowLabel(
                                title: "Quick Game Day",
                                detail: "Open Game Day faster with Control Center, the Lock Screen, Action Button, Shortcuts, Siri, or Spotlight.",
                                systemImage: "play.rectangle.fill"
                            )
                        }
                        .buttonStyle(.plain)

                        Toggle(isOn: Binding(
                            get: { appModel.state.settings.alwaysUseDarkLiveMode },
                            set: { appModel.setAlwaysUseDarkLiveMode($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Always Use Dark Live Screens",
                                detail: "Keep Game Day and Clips dark for field visibility.",
                                systemImage: "sun.max.fill"
                            )
                        }
                        .tint(selectedTeamAccentTheme.color(.primary))

                        Toggle(isOn: Binding(
                            get: { appModel.state.settings.hapticsEnabled },
                            set: { appModel.setHapticsEnabled($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Game Day Haptics",
                                detail: "Use subtle feedback for live controls.",
                                systemImage: "iphone.radiowaves.left.and.right"
                            )
                        }
                        .tint(selectedTeamAccentTheme.color(.primary))

                        Toggle(isOn: Binding(
                            get: { appModel.state.settings.keepScreenAwakeDuringLiveUse },
                            set: { appModel.setKeepScreenAwakeDuringLiveUse($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Keep Screen Awake",
                                detail: "Prevent auto-lock while Game Day or Clips is open. This can use more battery.",
                                systemImage: "lock.open.iphone"
                            )
                        }
                        .tint(selectedTeamAccentTheme.color(.primary))

                        Toggle(isOn: Binding(
                            get: { appModel.state.settings.showLineupProgressHints },
                            set: { appModel.setShowLineupProgressHints($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Show Lineup Progress Hints",
                                detail: "Show the subtle lineup flow animation when you advance batters from Next or On Deck.",
                                systemImage: "sparkles.rectangle.stack.fill"
                            )
                        }
                        .tint(selectedTeamAccentTheme.color(.primary))
                    }

                    SettingsSectionGroup(
                        title: "Recovery",
                        helperText: "Restore deleted teams or players first. Use backups when you need to go back to an earlier app state."
                    ) {
                        NavigationLink {
                            RecoveryCenterView(appModel: appModel)
                        } label: {
                            SettingsNavigationLabel(
                                title: "Recovery",
                                detail: "Restore deleted teams or players, or go back to an earlier app state.",
                                systemImage: "arrow.counterclockwise.circle.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if appModel.featureFlags.showDeveloperSettings {
                        SettingsSectionGroup(
                            title: "Advanced / Developer Tools",
                            helperText: "Experimental and diagnostic features stay out of normal user flows."
                        ) {
                            NavigationLink {
                                DeveloperToolsView(
                                    appModel: appModel,
                                    ratingRequestStatus: automaticRatingRequestDebugStatus,
                                    onTestAutomaticRatingPrompt: requestNativeInAppRatingPrompt,
                                    onShowRatingRequestSheet: presentManualRatingRequestSheet,
                                    onEmailSupport: requestRatingSupportEmail,
                                    onOpenReviewPage: requestManualRatingReview
                                )
                            } label: {
                                SettingsNavigationLabel(
                                    title: "Developer Tools",
                                    detail: "Open experimental settings and support utilities.",
                                    systemImage: "wrench.and.screwdriver.fill"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, RollCallSpacingTier.tight.value)
                .padding(.bottom, RollCallSpacingTier.large.value)
            }
            .accentWashBackground()
            .navigationTitle("Settings")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootTeamBannerHeader()
            }
            .sheet(isPresented: $packageSharePresented) {
                if let exportURL = appModel.exportURL {
                    ActivityShareSheet(items: [exportURL]) { completed in
                        guard completed else { return }
                        appModel.telemetry.recordPackageExportCompleted()
                    }
                }
            }
            .sheet(isPresented: $quickGameDayHelpPresented) {
                QuickGameDayHelpSheet()
            }
        }
        .tint(Color(uiColor: .label))
        .sheet(item: $ratingRequestPresentation, onDismiss: {
            appModel.cancelRatingSheetBeforeAppearance(token: ratingPresentationToken)
            ratingPresentationToken = nil
        }) { presentation in
            RatingRequestSheet(
                onAppeared: {
                    guard let token = ratingPresentationToken else { return }
                    appModel.confirmRatingSheetAppeared(token: token, source: presentation == .automatic ? .automatic : .manual)
                },
                onRate: {
                    appModel.recordRatingAction(.ratingRateSelected, suppressesAutomatic: true)
                    requestManualRatingReview()
                },
                onEmailSupport: {
                    appModel.recordRatingAction(.ratingFeedbackSelected, suppressesAutomatic: true)
                    requestRatingSupportEmail()
                },
                onNotNow: {
                    appModel.recordRatingAction(.ratingNotNowSelected, suppressesAutomatic: false)
                },
                onSupportDevelopment: {
                    appModel.recordRatingAction(.ratingSupportSelected, suppressesAutomatic: true)
                    openSupportScreenFromRatingPrompt()
                }
            )
        }
        .sheet(isPresented: $supportScreenPresented) {
            NavigationStack {
                SupportRollCallScreen(onManageSubscriptions: manageSupportSubscriptions)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            supportScreenPresented = false
                        }
                    }
                }
            }
        }
    }

    private var aboutRollCallScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                SettingsSectionGroup(title: "Roll Call") {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                        HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
                            SettingsIcon(systemImage: "baseball.fill", role: .accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Roll Call")
                                    .rollCallText(.cardTitle)
                                Text("Game day cues for local teams.")
                                    .rollCallText(.helperText)
                            }
                            Spacer()
                            StatusChip(
                                text: "v\(AppMetadata.appVersion) (\(AppMetadata.buildNumber))",
                                role: .neutral,
                                emphasis: .subdued
                            )
                            StatusChip(
                                text: BuildEnvironment.current.rawValue,
                                role: .neutral,
                                emphasis: .subdued
                            )
                        }

                        Text("© 2026 Sidelark Labs; John Kenneth Fisher")
                            .rollCallText(.helperText)
                    }
                }

                SettingsSectionGroup(title: "Support") {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                        Link(destination: URL(string: "https://sidelarklabs.com/rollcall/")!) {
                            SettingsRowLabel(
                                title: "Roll Call Website",
                                detail: "sidelarklabs.com/rollcall",
                                systemImage: "link"
                            )
                        }
                        .buttonStyle(.plain)

                        Link(destination: feedbackEmailURL) {
                            SettingsRowLabel(
                                title: "Email Feedback",
                                detail: "Send feedback to the developer with bugs and suggestions so we can smooth any rough edges.",
                                systemImage: "envelope.fill"
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            whatsNewPresentation = .manual
                        } label: {
                            SettingsRowLabel(
                                title: "What's New",
                                detail: "See the latest Roll Call update notes.",
                                systemImage: "sparkles"
                            )
                        }
                        .buttonStyle(.plain)

                        if appModel.hasEarnedRatingRequest {
                            Button {
                                presentManualRatingRequestSheet()
                            } label: {
                                SettingsRowLabel(
                                    title: "Rate Roll Call",
                                    detail: "If Roll Call has been helpful, leave a quick rating.",
                                    systemImage: "star.bubble.fill"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SettingsSectionGroup(title: "Credits") {
                    NavigationLink {
                        AttributionsView()
                    } label: {
                        SettingsNavigationLabel(
                            title: "Attributions & Licenses",
                            detail: "Credits for bundled clips and third-party software.",
                            systemImage: "doc.text.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, RollCallSpacingTier.tight.value)
            .padding(.bottom, RollCallSpacingTier.large.value)
        }
        .accentWashBackground()
        .navigationTitle("About Roll Call")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func playerAudioReadinessChecks(from checks: [ReadinessCheck]) -> [ReadinessCheck] {
        checks.filter { $0.category == .playerAudio }
    }

    private func openImportedRepair(
        _ item: PackageImportAudit.Item,
        audit: PackageImportAudit
    ) {
        guard let team = appModel.state.teams.first(where: { $0.id == audit.teamID }) else {
            appModel.completedPackageImportAudit = nil
            return
        }
        appModel.selectTeam(team)
        appModel.completedPackageImportAudit = nil
        switch item.destination {
        case .player(let playerID):
            selectedTab = .players
            guard let player = team.players.first(where: { $0.id == playerID }) else { return }
            Task { @MainActor in
                await Task.yield()
                presentPlayerEditor(for: player)
            }
        case .teamClip:
            selectedTab = .generalClips
        }
    }

    private func announcementReadinessChecks(from checks: [ReadinessCheck]) -> [ReadinessCheck] {
        checks.filter { $0.category == .playerAnnouncement }
    }

    private func optionalUpgradeReadinessChecks(from checks: [ReadinessCheck]) -> [ReadinessCheck] {
        checks.filter { $0.category == .playerPhoto }
    }

    private func gameDayReadinessChecks(from checks: [ReadinessCheck]) -> [ReadinessCheck] {
        checks.filter { [.audioRoute, .volume, .network, .appleMusicAccess, .lineup].contains($0.category) }
    }

    private func playerForReadinessCheck(_ check: ReadinessCheck) -> Player? {
        guard let playerID = check.playerID else { return nil }
        return appModel.selectedTeam?.players.first { $0.id == playerID }
    }
}

private struct OnboardingWelcomeView: View {
    let onGetStarted: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("SoftballLaunch")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .ignoresSafeArea()

                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .black.opacity(0.06), location: 0.0),
                        Gradient.Stop(color: .black.opacity(0.18), location: 0.42),
                        Gradient.Stop(color: .black.opacity(0.82), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                welcomeContent
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
            }
        }
        .ignoresSafeArea()
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                Text("Welcome to Roll Call.")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Generate Walk-Up Music Cues for Youth Sports")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(3)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .shadow(color: .black.opacity(0.5), radius: 12, y: 4)

            Button(action: onGetStarted) {
                Text("Let’s Get Started")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, RollCallSpacingTier.tight.value)
        }
    }
}

private struct OnboardingRootView: View {
    @ObservedObject var appModel: AppModel
    let onImportPackage: () -> Void
    let onOpenGameDay: () -> Void
    let onOpenReadiness: () -> Void

    @State private var teamName = ""
    @State private var selectedAccent: TeamAccentPreset = .rollCallOrange
    @State private var playerName = ""
    @State private var playerNumber = ""
    @State private var songPickerMode: SongPickerMode?
    @State private var showSongFileImporter = false
    @State private var pendingImportedSongURL: URL?
    @State private var songImportError: String?
    @State private var showLineupEditor = false
    @State private var showCloseConfirmation = false
    @State private var isAddingAdditionalPlayer = false
    @State private var visibleStepOverride: OnboardingStep?
    @State private var activeAudioPlayerID: UUID?
    @State private var showFinalHandoffOverride = false

    private var activeTeam: Team? {
        appModel.onboardingTeam
    }

    private var primaryPlayer: Player? {
        if let activeAudioPlayerID,
           let player = activeTeam?.players.first(where: { $0.id == activeAudioPlayerID }) {
            return player
        }
        return activeTeam?.players.first
    }

    private var onboardingPlayerCount: Int {
        activeTeam?.players.count ?? 0
    }

    private var recommendedLineupPlayerTarget: Int {
        3
    }

    private var needsMorePlayersForRecommendedLineup: Bool {
        onboardingPlayerCount < recommendedLineupPlayerTarget
    }

    private var hasRecommendedLineupPlayerCount: Bool {
        onboardingPlayerCount >= recommendedLineupPlayerTarget
    }

    private var playersNeededForRecommendedLineup: Int {
        max(0, recommendedLineupPlayerTarget - onboardingPlayerCount)
    }

    private var canCreateTeam: Bool {
        !teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canAddPlayer: Bool {
        !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var activeAccentTheme: TeamAccentTheme {
        activeTeam?.accentPreset.theme ?? selectedAccent.theme
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                    OnboardingMilestonesView(activeStep: activeStep, isComplete: showFinalHandoffOverride)

                    switch appModel.state.onboarding.activeFlow {
                    case .manualChooser:
                        manualChooserContent
                    case .importHandoff:
                        importHandoffContent
                    default:
                        setupContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .accentWashBackground()
            .navigationTitle("Setup Guide")
            .toolbar {
                if canNavigateBack {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            goBackOneStep()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }

                if canCloseSetupGuide {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            showCloseConfirmation = true
                        }
                    }
                }
            }
            .alert("Close Setup Guide?", isPresented: $showCloseConfirmation) {
                Button("Keep Going", role: .cancel) { }
                Button("Close Guide") {
                    appModel.dismissManualSetupGuide()
                }
            } message: {
                Text("Are you sure? If you haven’t used Roll Call before, we strongly recommend going through the onboarding process once so Game Day is ready when you need it.\n\nI promise, it's fast.")
            }
            .fileImporter(
                isPresented: $showSongFileImporter,
                allowedContentTypes: [.audio, .movie],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    pendingImportedSongURL = url
                    songPickerMode = .files
                case .failure(let error):
                    guard !MusicCatalogService.isCancellation(error) else { return }
                    songImportError = error.localizedDescription
                }
            }
            .alert("Import Unavailable", isPresented: Binding(
                get: { songImportError != nil },
                set: { if !$0 { songImportError = nil } }
            )) {
                Button("OK") { }
            } message: {
                Text(songImportError ?? "")
            }
            .sheet(item: $songPickerMode, onDismiss: {
                songPickerMode = nil
                pendingImportedSongURL = nil
            }) { mode in
                SongPickerFlow(
                    appModel: appModel,
                    mode: mode,
                    importedURL: mode == .files ? pendingImportedSongURL : nil,
                    onSave: { cue in
                        guard let player = primaryPlayer else { return }
                        appModel.saveSongCue(cue, to: player.id)
                        visibleStepOverride = .audio
                    }
                )
            }
            .sheet(isPresented: $showLineupEditor, onDismiss: {
                appModel.markOnboardingLineupSeen()
            }) {
                LineupEditorSheet(appModel: appModel, isLiveUse: false)
            }
        }
        .rollCallTeamAccentTheme(activeAccentTheme)
        .tint(activeAccentTheme.color(.primary))
    }

    @ViewBuilder
    private var setupContent: some View {
        if showFinalHandoffOverride {
            finalHandoffContent
        } else {
            switch activeStep {
            case .team:
                if let team = activeTeam {
                    editTeamContent(for: team)
                } else {
                    createTeamContent
                }
            case .player:
                if let player = primaryPlayer, !isAddingAdditionalPlayer {
                    editFirstPlayerContent(for: player)
                } else {
                    firstPlayerContent
                }
            case .audio:
                if let player = primaryPlayer {
                    audioContent(for: player)
                } else {
                    firstPlayerContent
                }
            case .lineup:
                lineupContent
            }
        }
    }

    private var manualChooserContent: some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                StatusChip(text: "Setup Guide", role: .neutral, systemImage: "sparkles", emphasis: .subdued)
                Text("What would you like to set up?")
                    .rollCallText(.screenTitle)
                Text("Use the guide again for a new team or add a team from another user's .rollcall file.")
                    .rollCallText(.body)

                Button {
                    appModel.startOnboardingCreateNewTeam()
                } label: {
                    Label("Create New Team", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.primary)

                Button {
                    onImportPackage()
                } label: {
                    Label("Add Team from .rollcall File", systemImage: "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.secondary)

                if appModel.selectedTeam != nil {
                    Button {
                        appModel.startOnboardingReviewCurrentTeam()
                    } label: {
                        Label("Review Current Team", systemImage: "checklist")
                            .frame(maxWidth: .infinity)
                    }
                    .rollCallButtonStyle(.secondary)
                }

            }
        }
    }

    private var createTeamContent: some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                StatusChip(text: "First Run", role: .live, systemImage: "figure.baseball", emphasis: .subdued)
                Text("Set up your team.")
                    .rollCallText(.screenTitle)
                Text("Roll Call works best when you try it out with your real team. You can hear the first walkup in just a few minutes.")
                    .rollCallText(.body)

                TextField("Team name", text: $teamName)
                    .onboardingTextField()
                    .textInputAutocapitalization(.words)

                VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                    Text("Team color")
                        .rollCallText(.cardTitle)
                    Text("Pick a quick accent, or leave the Roll Call default and change it later.")
                        .rollCallText(.helperText)
                    AccentPresetGrid(selectedAccent: $selectedAccent)
                }

                Button {
                    appModel.addTeam(named: teamName, accentPreset: selectedAccent, forOnboarding: true)
                    teamName = ""
                    selectedAccent = .rollCallOrange
                    visibleStepOverride = nil
                } label: {
                    SettingsRowLabel(
                        title: "Create Team",
                        detail: "Save this team and continue setup.",
                        systemImage: "plus",
                        style: .filledAction
                    )
                }
                .rollCallButtonStyle(.primary)
                .disabled(!canCreateTeam)

                Button {
                    onImportPackage()
                } label: {
                    Label("Add Team from Another User's .rollcall File", systemImage: "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.secondary)
            }
        }
    }

    private func editTeamContent(for team: Team) -> some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                StatusChip(text: "Team", role: .neutral, systemImage: "person.3", emphasis: .subdued)
                Text("Review your team.")
                    .rollCallText(.screenTitle)
                Text("Change the team name or accent, then keep going.")
                    .rollCallText(.body)

                TextField("Team name", text: $teamName)
                    .onboardingTextField()
                    .textInputAutocapitalization(.words)

                VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                    Text("Team color")
                        .rollCallText(.cardTitle)
                    Text("This can still be changed later in the team setup.")
                        .rollCallText(.helperText)
                    AccentPresetGrid(selectedAccent: $selectedAccent)
                }

                Button {
                    appModel.renameSelectedTeam(to: teamName)
                    appModel.setAccentPreset(selectedAccent, for: team.id)
                    visibleStepOverride = .player
                } label: {
                    Label("Continue", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.primary)
                .disabled(!canCreateTeam)
            }
        }
        .onAppear {
            teamName = team.name
            selectedAccent = team.accentPreset
        }
    }

    private var firstPlayerContent: some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                StatusChip(text: activeTeam?.name ?? "Team", role: .neutral, systemImage: "person.3", emphasis: .subdued)
                Text(isAddingAdditionalPlayer ? "Add your \(ordinalWord(for: onboardingPlayerCount)) player." : "Add your first player.")
                    .rollCallText(.screenTitle)
                Text(isAddingAdditionalPlayer ? "Then come back to Lineup to see how the batting order works." : "Start with one player. You can add the full roster after the first walkup works.")
                    .rollCallText(.body)

                TextField("Player name", text: $playerName)
                    .onboardingTextField()
                    .textInputAutocapitalization(.words)
                TextField("Number (optional)", text: $playerNumber)
                    .onboardingTextField()
                    .keyboardType(.numberPad)

                Button {
                    let addedPlayer = appModel.addPlayer(name: playerName, number: playerNumber)
                    playerName = ""
                    playerNumber = ""
                    if isAddingAdditionalPlayer, let addedPlayer {
                        activeAudioPlayerID = addedPlayer.id
                        isAddingAdditionalPlayer = false
                        visibleStepOverride = .audio
                    } else {
                        isAddingAdditionalPlayer = false
                        visibleStepOverride = nil
                    }
                } label: {
                    Label("Add Player", systemImage: "person.crop.circle.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.primary)
                .disabled(!canAddPlayer)
            }
        }
    }

    private func ordinalWord(for index: Int) -> String {
        let ordinals = ["first", "second", "third", "fourth", "fifth"]
        return ordinals.indices.contains(index) ? ordinals[index] : "\(index + 1)th"
    }

    private func playerOrdinal(for player: Player) -> String {
        let index = activeTeam?.players.firstIndex(where: { $0.id == player.id }) ?? 0
        return ordinalWord(for: index)
    }

    private func editFirstPlayerContent(for player: Player) -> some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                StatusChip(text: activeTeam?.name ?? "Team", role: .neutral, systemImage: "person.crop.circle", emphasis: .subdued)
                Text("Review your \(playerOrdinal(for: player)) player.")
                    .rollCallText(.screenTitle)
                Text("Update the name or number, then move back to audio.")
                    .rollCallText(.body)

                TextField("Player name", text: $playerName)
                    .onboardingTextField()
                    .textInputAutocapitalization(.words)
                TextField("Number (optional)", text: $playerNumber)
                    .onboardingTextField()
                    .keyboardType(.numberPad)

                Button {
                    var updatedPlayer = player
                    updatedPlayer.displayName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
                    updatedPlayer.uniformNumber = playerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                    appModel.updatePlayer(updatedPlayer)
                    visibleStepOverride = .audio
                } label: {
                    Label("Continue", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.primary)
                .disabled(!canAddPlayer)
            }
        }
        .onAppear {
            playerName = player.displayName
            playerNumber = player.uniformNumber
        }
    }

    private func audioContent(for player: Player) -> some View {
        let cue = appModel.resolvedCue(for: player)
        return OnboardingCard {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                StatusChip(text: player.displayName, role: cue == nil ? .warning : .ready, systemImage: "music.note", emphasis: .subdued)
                Text(cue == nil ? "Choose the walkup audio." : "\(player.displayName)'s clip is ready.")
                    .rollCallText(.screenTitle)
                if cue == nil {
                    Text("Choose from this iPhone's Music Library, search Apple Music, or import an audio or video file.")
                        .rollCallText(.body)
                    Text("After you pick a song, Make Your Clip lets you drag the waveform, choose the length, preview it, and save.")
                        .rollCallText(.body)
                } else {
                    onboardingCueSummary(cue)
                    Text("To change it, choose another source and shape the replacement in Make Your Clip before continuing. To make changes later, visit the Players tab.")
                        .rollCallText(.body)
                }
                if cue == nil {
                    Text("You can also just select crowd cheering sound effects too, and pick the song later, but where's the fun in that?")
                        .rollCallText(.body)
                }

                if cue != nil {
                    Button {
                        visibleStepOverride = .lineup
                    } label: {
                        Label("Continue", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .rollCallButtonStyle(.primary)
                }

                Button {
                    songPickerMode = .musicLibrary
                } label: {
                    Label("Choose from Music Library", systemImage: "music.note.list")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(cue == nil ? .primary : .secondary)

                Button {
                    songPickerMode = .appleMusic
                } label: {
                    Label("Search Apple Music", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.secondary)

                Button {
                    showSongFileImporter = true
                } label: {
                    Label("Import Audio or Video", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.secondary)

                if cue == nil {
                    Button {
                        appModel.markOnboardingCheerFallbackChosen()
                        visibleStepOverride = nil
                    } label: {
                        Label("Try with a Crowd Cheering", systemImage: "speaker.wave.2.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .rollCallButtonStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func onboardingCueSummary(_ cue: Cue?) -> some View {
        if let cue {
            VStack(alignment: .leading, spacing: 4) {
                switch cue.source {
                case .appleMusic(let source):
                    Text(source.title)
                        .rollCallText(.cardTitle)
                    Text(source.artistName)
                        .rollCallText(.helperText)
                case .localAudio(let source):
                    Text(source.displayName.songTitleWithoutArtistPrefix)
                        .rollCallText(.cardTitle)
                case .builtInClip(let source):
                    Text(source.displayName)
                        .rollCallText(.cardTitle)
                }
                Text("\(formattedCueTime(cue.duration)) clip starting at \(formattedCueTime(cue.startTime))")
                    .rollCallText(.helperText)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var lineupContent: some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                StatusChip(text: "Lineup", role: .neutral, systemImage: "list.number", emphasis: .subdued)
                Text(needsMorePlayersForRecommendedLineup ? "Three players make lineup click." : "Now check the lineup.")
                    .rollCallText(.screenTitle)
                Text(lineupPrimaryMessage)
                    .rollCallText(.body)
                Text(lineupSecondaryMessage)
                    .rollCallText(.body)

                if needsMorePlayersForRecommendedLineup {
                    Button {
                        prepareToAddAnotherOnboardingPlayer()
                    } label: {
                        Label(addRecommendedPlayersButtonTitle, systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .rollCallButtonStyle(.primary)

                    Button {
                        showLineupEditor = true
                    } label: {
                        Label("Open Lineup Anyway", systemImage: "list.bullet")
                            .frame(maxWidth: .infinity)
                    }
                    .rollCallButtonStyle(.secondary)
                } else {
                    Button {
                        showLineupEditor = true
                    } label: {
                        Label("Open Today’s Lineup", systemImage: "list.bullet")
                            .frame(maxWidth: .infinity)
                    }
                    .rollCallButtonStyle(.primary)

                    Button {
                        prepareToAddAnotherOnboardingPlayer()
                    } label: {
                        Label("Add More Players", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .rollCallButtonStyle(.secondary)
                }

                if appModel.state.onboarding.didSeeLineup {
                    Button {
                        appModel.markOnboardingLineupSeen()
                        isAddingAdditionalPlayer = false
                        visibleStepOverride = nil
                        showFinalHandoffOverride = true
                    } label: {
                        Label("Got It", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .rollCallButtonStyle(.secondary)
                }
            }
        }
    }

    private var lineupPrimaryMessage: String {
        if needsMorePlayersForRecommendedLineup {
            return "You have \(onboardingPlayerCount) \(onboardingPlayerCount == 1 ? "player" : "players"). We strongly recommend making a total of three players before you look at Today’s Lineup."
        }
        return "You have \(onboardingPlayerCount) players, which is enough to see how Today’s Lineup controls batting order and who is present."
    }

    private var lineupSecondaryMessage: String {
        if needsMorePlayersForRecommendedLineup {
            return "You can still open the lineup now, but three players make the order and Game Day handoff much clearer."
        }
        return "Open Today’s Lineup once, then you can continue. You can still add more players first if you want a bigger sample."
    }

    private var addRecommendedPlayersButtonTitle: String {
        if playersNeededForRecommendedLineup == 1 {
            return "Add One More Player to Reach Three"
        }
        return "Add \(playersNeededForRecommendedLineup) More Players to Reach Three"
    }

    private func prepareToAddAnotherOnboardingPlayer() {
        playerName = ""
        playerNumber = ""
        isAddingAdditionalPlayer = true
        activeAudioPlayerID = nil
        visibleStepOverride = .player
    }

    private var finalHandoffContent: some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                StatusChip(text: "Ready to Try", role: .ready, systemImage: "checkmark.circle", emphasis: .subdued)
                Text("You’re ready to try Roll Call.")
                    .rollCallText(.screenTitle)
                Text("Setup is done. Open Game Day now and try the walkup flow with the players you created.")
                    .rollCallText(.body)
                Text("After that, go to the Players tab to add more players, fine-tune existing song clips, and fill in more details for existing players, like announcer recordings and photos.")
                    .rollCallText(.body)
                Text("Most importantly - have fun and thanks for trying Roll Call.")
                    .rollCallText(.body)

                Button {
                    onOpenGameDay()
                } label: {
                    Label("Open Game Day", systemImage: "play.rectangle.fill")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.primary)
            }
        }
    }

    private var importHandoffContent: some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                StatusChip(text: "Imported", role: .ready, systemImage: "shippingbox.fill", emphasis: .subdued)
                Text("Team imported.")
                    .rollCallText(.screenTitle)
                Text("Review readiness first if this package came from another device, or jump straight into Game Day.")
                    .rollCallText(.body)

                Button {
                    onOpenReadiness()
                } label: {
                    Label("Review Readiness", systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.primary)

                Button {
                    onOpenGameDay()
                } label: {
                    Label("Open Game Day", systemImage: "play.rectangle.fill")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.secondary)
            }
        }
    }

    private var activeStep: OnboardingStep {
        visibleStepOverride ?? resolvedStep
    }

    private var resolvedStep: OnboardingStep {
        if appModel.state.onboarding.activeFlow == .importHandoff {
            return .lineup
        }
        guard let team = activeTeam else { return .team }
        if team.players.isEmpty { return .player }
        if let player = team.players.first,
           team.cue(for: player) == nil && !appModel.state.onboarding.didChooseCheerFallback {
            return .audio
        }
        return .lineup
    }

    private var canNavigateBack: Bool {
        appModel.state.onboarding.activeFlow != .manualChooser &&
        appModel.state.onboarding.activeFlow != .importHandoff &&
        previousStep != nil
    }

    private var canCloseSetupGuide: Bool {
        appModel.state.onboarding.activeFlow != .importHandoff &&
        !appModel.state.teams.isEmpty
    }

    private var previousStep: OnboardingStep? {
        if showFinalHandoffOverride {
            return .lineup
        }
        switch activeStep {
        case .team:
            return nil
        case .player:
            if isAddingAdditionalPlayer { return .lineup }
            if let primary = primaryPlayer, primary.id != activeTeam?.players.first?.id {
                return .lineup
            }
            return activeTeam == nil ? nil : .team
        case .audio:
            return primaryPlayer == nil ? nil : .player
        case .lineup:
            return primaryPlayer == nil ? nil : .audio
        }
    }

    private func goBackOneStep() {
        let target = previousStep
        showFinalHandoffOverride = false
        if target == .lineup { isAddingAdditionalPlayer = false }
        visibleStepOverride = target
    }

}

private enum OnboardingStep: Int, CaseIterable {
    case team
    case player
    case audio
    case lineup

    var title: String {
        switch self {
        case .team: return "Team"
        case .player: return "Player"
        case .audio: return "Audio"
        case .lineup: return "Lineup"
        }
    }
}

private struct OnboardingMilestonesView: View {
    let activeStep: OnboardingStep
    var isComplete: Bool = false

    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(OnboardingStep.allCases, id: \.self) { step in
                HStack(spacing: 5) {
                    Image(systemName: symbolName(for: step))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(symbolColor(for: step))
                        .frame(width: 14, height: 14)
                    Text(step.title)
                        .font(.caption.weight(isComplete ? .semibold : (step == activeStep ? .bold : .semibold)))
                        .foregroundStyle(textColor(for: step))
                }
                .overlay(alignment: .bottom) {
                    if !isComplete && step == activeStep {
                        Capsule()
                            .fill(teamAccentTheme.color(.fill))
                            .frame(height: 2)
                            .offset(y: 5)
                    }
                }

                if step != OnboardingStep.allCases.last {
                    Rectangle()
                        .fill(Color.rollCall(.neutralStructure).opacity(0.55))
                        .frame(width: 16, height: 1)
                }
            }
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Setup milestones")
    }

    private func symbolName(for step: OnboardingStep) -> String {
        if isComplete { return "checkmark.circle.fill" }
        if step.rawValue < activeStep.rawValue { return "checkmark.circle.fill" }
        if step == activeStep { return "circle.fill" }
        return "circle"
    }

    private func symbolColor(for step: OnboardingStep) -> Color {
        if isComplete { return teamAccentTheme.color(.primary) }
        return step.rawValue <= activeStep.rawValue ? teamAccentTheme.color(.primary) : Color(uiColor: .tertiaryLabel)
    }

    private func textColor(for step: OnboardingStep) -> Color {
        if isComplete { return Color(uiColor: .secondaryLabel) }
        return step == activeStep ? Color(uiColor: .label) : Color(uiColor: .secondaryLabel)
    }
}

private struct OnboardingCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.rollCall(.neutralStructure).opacity(0.55), lineWidth: 1)
        )
    }
}

private struct OnboardingTextFieldModifier: ViewModifier {
    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color(uiColor: .systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(teamAccentTheme.color(.primary).opacity(0.55), lineWidth: 1.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension View {
    func onboardingTextField() -> some View {
        modifier(OnboardingTextFieldModifier())
    }
}

private struct AccentPresetGrid: View {
    @Binding var selectedAccent: TeamAccentPreset

    private let displayOrder: [TeamAccentPreset] = [
        .red,
        .rollCallOrange,
        .gold,
        .green,
        .blue,
        .purple,
        .gray,
        .black
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 8)], spacing: 8) {
            ForEach(displayOrder) { preset in
                Button {
                    selectedAccent = preset
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(preset.color())
                            .frame(width: 16, height: 16)
                        Text(preset.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 9)
                    .background(selectedAccent == preset ? preset.color().opacity(0.16) : Color.rollCall(.neutralSurface))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(selectedAccent == preset ? preset.color() : Color.rollCall(.neutralStructure).opacity(0.45), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ReadinessOverviewCard: View {
    let readiness: ReadinessStatus
    let team: Team?
    let onOpenGameDay: () -> Void
    let onRefresh: () -> Void

    private var presentCount: Int {
        team?.presentPlayersInBattingOrder.count ?? 0
    }

    private var playerChecks: [ReadinessCheck] {
        readiness.checks.filter { check in
            check.id.hasPrefix("player-")
                && !check.id.contains("announcement-upgrade")
                && !check.id.contains("photo-upgrade")
        }
    }

    private var readyCount: Int {
        playerChecks.filter { $0.state == .ready || $0.state == .enhanced }.count
    }

    private var enhancedCount: Int {
        playerChecks.filter { $0.state == .enhanced }.count
    }

    private var needsAudioCount: Int {
        playerChecks.filter { $0.state == .needsAudio }.count
    }

    private var issueCount: Int {
        playerChecks.filter { $0.state == .issue }.count
    }

    private var isReadyForGameDay: Bool {
        presentCount > 0 && needsAudioCount == 0 && issueCount == 0
    }

    var body: some View {
        SectionCard(family: isReadyForGameDay ? .identity : .status) {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
                    VStack(alignment: .leading, spacing: 4) {
                        StatusChip(
                            text: summaryChipText,
                            role: summaryRole,
                            systemImage: summaryIcon,
                            emphasis: .subdued
                        )
                        Text(summaryTitle)
                            .rollCallText(.sectionTitle)
                        Text("Updated \(readiness.generatedAt.formatted(date: .omitted, time: .shortened))")
                            .rollCallText(.helperText)
                    }

                    Spacer(minLength: RollCallSpacingTier.standard.value)

                    ReadinessRefreshButton(action: onRefresh)
                }

                Text(summaryDetail)
                    .rollCallText(.helperText)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 118), spacing: RollCallSpacingTier.tight.value)],
                    alignment: .leading,
                    spacing: RollCallSpacingTier.tight.value
                ) {
                    StatusChip(text: "\(readyCount) ready", role: .ready, systemImage: "checkmark.circle", emphasis: .subdued)
                    if needsAudioCount > 0 {
                        StatusChip(text: "\(needsAudioCount) need audio", role: .warning, systemImage: "music.note", emphasis: .subdued)
                    }
                    if enhancedCount > 0 {
                        StatusChip(text: "\(enhancedCount) enhanced", role: .live, systemImage: "mic.fill", emphasis: .subdued)
                    }
                    if issueCount > 0 {
                        StatusChip(text: "\(issueCount) need repair", role: .destructive, systemImage: "wrench.and.screwdriver", emphasis: .subdued)
                    }
                }

                Button(action: onOpenGameDay) {
                    Label("Open Game Day", systemImage: "play.rectangle.fill")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.primary)
            }
        }
    }

    private var summaryTitle: String {
        if presentCount == 0 {
            return "Choose Today’s Lineup"
        }
        if issueCount > 0 {
            return "Some Audio Needs Repair"
        }
        if needsAudioCount > 0 {
            return "Some Players Need Audio"
        }
        return "Ready for Game Day"
    }

    private var summaryDetail: String {
        if presentCount == 0 {
            return "Mark players present before game day so Roll Call can focus on the lineup you will actually use."
        }
        if issueCount > 0 {
            return "A few assigned audio files need attention before they can be trusted live."
        }
        if needsAudioCount > 0 {
            return "Game Day can still use Small Cheer fallback, but these players need their own audio to feel ready."
        }
        return "Every present player has player-specific audio. Optional upgrades can add more delight, but they are not required."
    }

    private var summaryChipText: String {
        isReadyForGameDay ? "Ready" : "Help Available"
    }

    private var summaryRole: StatusChipRole {
        if issueCount > 0 {
            return .destructive
        }
        if needsAudioCount > 0 || presentCount == 0 {
            return .warning
        }
        return .ready
    }

    private var summaryIcon: String {
        if issueCount > 0 {
            return "wrench.and.screwdriver"
        }
        if needsAudioCount > 0 || presentCount == 0 {
            return "music.note"
        }
        return "checkmark.circle"
    }
}

private struct ReadinessPlayerAudioCard: View {
    let checks: [ReadinessCheck]
    let playerForCheck: (ReadinessCheck) -> Player?
    let onEditPlayer: (Player) -> Void

    var body: some View {
        ReadinessSectionCard(
            title: "Player Audio",
            helperText: "Ready means the player has their own playable audio. Fallback keeps Game Day safe, but it does not count as ready.",
            checks: checks,
            emptyText: "No present players to check yet.",
            playerForCheck: playerForCheck,
            onEditPlayer: onEditPlayer
        )
    }
}

private struct ReadinessEnhancementsCard: View {
    let checks: [ReadinessCheck]
    let playerAudioChecks: [ReadinessCheck]
    let playerForCheck: (ReadinessCheck) -> Player?
    let onEditPlayer: (Player) -> Void

    var body: some View {
        ReadinessSectionCard(
            title: "Announcements",
            helperText: "This list shows players who have songs selected but do not have announcements recorded yet.",
            checks: checks,
            emptyText: emptyText,
            playerForCheck: playerForCheck,
            onEditPlayer: onEditPlayer
        )
    }

    private var emptyText: String {
        let playersWithAudio = playerAudioChecks.filter { check in
            check.state == .ready || check.state == .enhanced
        }
        guard !playersWithAudio.isEmpty else {
            return "Add player audio first, then Roll Call can suggest announcement upgrades."
        }
        return "Every player with audio already has an Announcement Cue."
    }
}

private struct ReadinessOptionalUpgradesCard: View {
    let checks: [ReadinessCheck]
    let playerForCheck: (ReadinessCheck) -> Player?
    let onEditPlayer: (Player) -> Void

    var body: some View {
        ReadinessSectionCard(
            title: "Optional Polish",
            helperText: "Photos and presentation details can make the board cooler. They never make a player incomplete.",
            checks: checks,
            emptyText: "Optional polish looks good for today’s lineup.",
            playerForCheck: playerForCheck,
            onEditPlayer: onEditPlayer
        )
    }
}

private struct ReadinessGameDayChecksCard: View {
    let checks: [ReadinessCheck]
    let onRequestAppleMusicAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Before You Start")
                    .rollCallText(.sectionTitle)
                Text("Phone and setup checks are separate from player readiness.")
                    .rollCallText(.helperText)
            }
            .padding(.horizontal, 2)

            SectionCard(family: checks.contains(where: { $0.state == .issue }) ? .status : .utility) {
                VStack(spacing: 0) {
                    ForEach(Array(checks.enumerated()), id: \.element.id) { index, check in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 42)
                        }
                        ReadinessGameDayCheckRow(
                            check: check,
                            onRequestAppleMusicAccess: onRequestAppleMusicAccess
                        )
                    }
                }
            }
        }
    }
}

private struct ReadinessGameDayCheckRow: View {
    let check: ReadinessCheck
    let onRequestAppleMusicAccess: () -> Void

    var body: some View {
        Group {
            if canRequestAppleMusicAccess {
                Button(action: onRequestAppleMusicAccess) {
                    content(showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Requests Apple Music access.")
            } else {
                content(showsChevron: false)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func content(showsChevron: Bool) -> some View {
        HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
            Image(systemName: status.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(status.color)
                .frame(width: 30, height: 30)
                .background(status.color.opacity(0.13))
                .clipShape(Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: RollCallSpacingTier.tight.value) {
                    Text(check.title)
                        .rollCallText(.cardTitle)
                    Spacer(minLength: RollCallSpacingTier.tight.value)
                    StatusChip(
                        text: canRequestAppleMusicAccess ? status.actionLabel : status.label,
                        role: status.chipRole,
                        emphasis: .subdued
                    )
                }

                Text(detail)
                    .rollCallText(.helperText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .padding(.top, 8)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, RollCallSpacingTier.tight.value)
    }

    private var status: GameDayCheckStatus {
        if check.state == .issue {
            return .needsAttention
        }

        switch check.id {
        case "route":
            return .checkManually
        case "network", "music-auth":
            return check.detail.hasPrefix("No Apple Music") ? .notNeeded : .looksGood
        default:
            return .looksGood
        }
    }

    private var detail: String {
        if check.state == .issue {
            switch check.id {
            case "route":
                return "Roll Call cannot identify the current output. Connect your speaker and play a quick test before starting."
            case "volume":
                return "Turn up the device volume and test it on the speaker you will use."
            case "music-auth" where canRequestAppleMusicAccess:
                return "Apple Music cues need approval. Tap Grant Access to let Roll Call use Apple Music."
            case "music-auth":
                return "\(check.detail) Check iOS Settings if you need Apple Music cues today."
            default:
                return check.detail
            }
        }

        switch check.id {
        case "route":
            return "Detected: \(check.detail). This may be right or wrong; confirm the sound is coming from the speaker you want."
        case "volume":
            return "Device volume is \(check.detail). This looks usable, but confirm it is loud enough on the field."
        case "network" where check.detail.hasPrefix("No Apple Music"):
            return "No Apple Music cues are in today's lineup, so network access is not needed for those cues."
        case "music-auth" where check.detail.hasPrefix("No Apple Music"):
            return "No Apple Music cues are assigned, so Apple Music access is not needed right now."
        case "lineup":
            return "\(check.detail). This is the lineup Roll Call will use in Game Day."
        default:
            return check.detail
        }
    }

    private var canRequestAppleMusicAccess: Bool {
        check.action == .requestAppleMusicAccess
    }
}

private enum GameDayCheckStatus {
    case looksGood
    case checkManually
    case notNeeded
    case needsAttention

    var label: String {
        switch self {
        case .looksGood: return "Looks Good"
        case .checkManually: return "Check This"
        case .notNeeded: return "Not Needed"
        case .needsAttention: return "Needs Attention"
        }
    }

    var actionLabel: String {
        switch self {
        case .needsAttention: return "Grant Access"
        case .checkManually: return "Check This"
        case .notNeeded: return "Not Needed"
        case .looksGood: return "Looks Good"
        }
    }

    var chipRole: StatusChipRole {
        switch self {
        case .looksGood, .notNeeded: return .ready
        case .checkManually: return .warning
        case .needsAttention: return .destructive
        }
    }

    var systemImage: String {
        switch self {
        case .looksGood: return "checkmark.circle.fill"
        case .checkManually: return "questionmark.circle.fill"
        case .notNeeded: return "minus.circle.fill"
        case .needsAttention: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .looksGood, .notNeeded: return Color.rollCall(.ready)
        case .checkManually: return Color.rollCall(.warning)
        case .needsAttention: return Color.rollCall(.destructive)
        }
    }
}

private struct ReadinessSectionCard: View {
    let title: String
    let helperText: String
    let checks: [ReadinessCheck]
    let emptyText: String
    let playerForCheck: (ReadinessCheck) -> Player?
    let onEditPlayer: (Player) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .rollCallText(.sectionTitle)
                Text(helperText)
                    .rollCallText(.helperText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 2)

            SectionCard(family: cardFamily) {
                VStack(spacing: 0) {
                    if checks.isEmpty {
                        Text(emptyText)
                            .rollCallText(.helperText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(Array(checks.enumerated()), id: \.element.id) { index, check in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 42)
                        }
                        if let player = playerForCheck(check) {
                            Button {
                                onEditPlayer(player)
                            } label: {
                                ReadinessCheckDisplayRow(check: check, showsChevron: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens this player’s setup.")
                        } else {
                            ReadinessCheckDisplayRow(check: check)
                        }
                    }
                }
            }
        }
    }

    private var cardFamily: RollCallCardFamily {
        if checks.contains(where: { $0.state == .issue || $0.state == .needsAudio }) {
            return .status
        }
        return .utility
    }
}

private struct ReadinessCheckDisplayRow: View {
    let check: ReadinessCheck
    var showsChevron = false

    var body: some View {
        HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
            Image(systemName: check.state.statusChipIcon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(check.state.semanticColor)
                .frame(width: 30, height: 30)
                .background(check.state.semanticColor.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: RollCallSpacingTier.tight.value) {
                    Text(check.title)
                        .rollCallText(.cardTitle)
                    Spacer(minLength: RollCallSpacingTier.tight.value)
                    StatusChip(
                        text: check.state.readinessLabel,
                        role: check.state.statusChipRole,
                        emphasis: .subdued
                    )
                }
                Text(check.detail)
                    .rollCallText(.helperText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .padding(.top, 8)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, RollCallSpacingTier.tight.value)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct ReadinessEmptyCard: View {
    let onRefresh: () -> Void

    var body: some View {
        SectionCard(family: .status) {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                        StatusChip(text: "Not Checked Yet", role: .neutral, systemImage: "checklist", emphasis: .subdued)
                        Text("Ready for Game Day?")
                            .rollCallText(.sectionTitle)
                    }

                    Spacer(minLength: RollCallSpacingTier.standard.value)

                    ReadinessRefreshButton(action: onRefresh)
                }

                Text("Tap Refresh to check today’s lineup, player audio, optional upgrades, and before-start phone checks.")
                    .rollCallText(.helperText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ReadinessRefreshButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityHint("Updates the readiness report.")
    }
}

private struct TeamsSectionGroup<Content: View>: View {
    let title: String
    let helperText: String
    let content: Content

    init(
        title: String,
        helperText: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.helperText = helperText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .rollCallText(.sectionTitle)
                Text(helperText)
                    .rollCallText(.helperText)
            }
            .padding(.horizontal, 2)

            SectionCard {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct TeamSelectionRow: View {
    let team: Team
    let isSelected: Bool

    private var teamAccentTheme: TeamAccentTheme {
        team.accentPreset.theme
    }

    var body: some View {
        HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
            TeamRowIcon(isSelected: isSelected, teamAccentTheme: teamAccentTheme)

            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .rollCallText(.cardTitle)
                    .lineLimit(2)
                Text("\(team.players.count) players • \(team.presentPlayersInBattingOrder.count) present")
                    .rollCallText(.helperText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelected {
                Label("Current", systemImage: "checkmark.circle")
                    .rollCallText(.chipLabel)
                    .foregroundStyle(teamAccentTheme.color(.primary))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 9)
                    .background(teamAccentTheme.color(.subtle).opacity(0.14), in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(teamAccentTheme.color(.primary).opacity(0.35), lineWidth: 1)
                    }
            }
        }
        .padding(.horizontal, isSelected ? 10 : 0)
        .padding(.vertical, isSelected ? 8 : 0)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(teamAccentTheme.color(.subtle).opacity(0.12))
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(teamAccentTheme.color(.primary).opacity(0.48), lineWidth: 1.4)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct SelectedTeamSummary: View {
    let team: Team

    var body: some View {
        HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
            TeamRowIcon(isSelected: true, teamAccentTheme: team.accentPreset.theme)

            VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                Text(team.name)
                    .rollCallText(.primaryIdentity)
                    .lineLimit(2)

                HStack(spacing: RollCallSpacingTier.tight.value) {
                    StatusChip(
                        text: "\(team.players.count) players",
                        role: .neutral,
                        systemImage: "person.3",
                        emphasis: .subdued
                    )
                    StatusChip(
                        text: "\(team.presentPlayersInBattingOrder.count) present",
                        role: .ready,
                        systemImage: "checkmark.circle",
                        emphasis: .subdued
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TeamRowIcon: View {
    let isSelected: Bool
    let teamAccentTheme: TeamAccentTheme

    var body: some View {
        Image(systemName: isSelected ? "person.3.fill" : "person.3")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(teamAccentTheme.color(.primary))
            .frame(width: 34, height: 34)
            .background(teamAccentTheme.color(.subtle).opacity(isSelected ? 0.18 : 0.13))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct TeamsEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            StatusChip(text: "No teams yet", role: .neutral, systemImage: "person.3", emphasis: .subdued)
            Text("Create a team to start building a roster.")
                .rollCallText(.helperText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CustomClipsManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let initialClipID: UUID?

    @State private var songPickerMode: SongPickerMode?
    @State private var showFileImporter = false
    @State private var importedURL: URL?
    @State private var pendingNewCue: Cue?
    @State private var newClipName = ""
    @State private var editingClip: SongClip?
    @State private var renamingClip: SongClip?
    @State private var renameText = ""
    @State private var deletingClip: SongClip?
    @State private var showExistingClipPicker = false
    @State private var notice: String?
    @State private var editMode: EditMode = .active

    init(appModel: AppModel, initialClipID: UUID? = nil) {
        self.appModel = appModel
        self.initialClipID = initialClipID
        _editingClip = State(
            initialValue: initialClipID.flatMap { id in
                appModel.selectedTeam?.teamClips.first(where: { $0.id == id })
            }
        )
    }

    private var team: Team? {
        appModel.selectedTeam
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let team, !team.teamClips.isEmpty {
                        ForEach(team.teamClips) { clip in
                            customClipRow(clip)
                        }
                        .onMove(perform: appModel.moveCustomClips)
                    } else {
                        ContentUnavailableView(
                            "No Custom Clips",
                            systemImage: "music.note",
                            description: Text("Add quick song clips for live sideline moments.")
                        )
                    }
                } header: {
                    Text("Custom Clips")
                } footer: {
                    Text("Drag to arrange the live Clips grid. Copies remain independent from Player Songs.")
                }

                Section("Add Custom Clip") {
                    Button {
                        songPickerMode = .musicLibrary
                    } label: {
                        Label("Choose from Music Library", systemImage: "music.note.list")
                    }
                    Button {
                        songPickerMode = .appleMusic
                    } label: {
                        Label("Search Apple Music", systemImage: "magnifyingglass")
                    }
                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Import Audio or Video", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        showExistingClipPicker = true
                    } label: {
                        Label("Use Existing Clip", systemImage: "doc.on.doc")
                    }
                    .disabled(existingClipSourceCount == 0)
                }

                if let notice {
                    Section {
                        Label(notice, systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Custom Clips")
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $songPickerMode, onDismiss: {
                songPickerMode = nil
                importedURL = nil
            }) { mode in
                SongPickerFlow(
                    appModel: appModel,
                    mode: mode,
                    importedURL: mode == .files ? importedURL : nil
                ) { cue in
                    pendingNewCue = cue
                    newClipName = cue.rosterDisplayTitle
                }
            }
            .sheet(item: $editingClip) { clip in
                NavigationStack {
                    SongClipEditorView(appModel: appModel, initialCue: clip.editingCue) { cue in
                        appModel.updateCustomClip(
                            clip.id,
                            with: cue,
                            named: clip.displayName ?? ""
                        )
                        editingClip = nil
                    }
                }
            }
            .sheet(isPresented: $showExistingClipPicker) {
                ExistingClipPickerSheet(appModel: appModel, destination: .customClip)
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio, .movie],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    importedURL = url
                    songPickerMode = .files
                case .failure(let error):
                    guard !MusicCatalogService.isCancellation(error) else { return }
                    appModel.lastError = error.localizedDescription
                }
            }
            .alert("Name Custom Clip", isPresented: Binding(
                get: { pendingNewCue != nil },
                set: {
                    if !$0 {
                        pendingNewCue = nil
                    }
                }
            )) {
                TextField("Clip name", text: $newClipName)
                Button("Cancel", role: .cancel) {
                    pendingNewCue = nil
                }
                Button("Save") {
                    savePendingCue()
                }
            } message: {
                Text("Names are optional. If left blank, Roll Call shows the song title.")
            }
            .alert("Rename Custom Clip", isPresented: Binding(
                get: { renamingClip != nil },
                set: { if !$0 { renamingClip = nil } }
            )) {
                TextField("Clip name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    renamingClip = nil
                }
                Button("Rename") {
                    guard let clip = renamingClip else { return }
                    appModel.updateCustomClip(clip.id, with: clip.editingCue, named: renameText)
                    renamingClip = nil
                }
            }
            .confirmationDialog(
                "Delete Custom Clip?",
                isPresented: Binding(
                    get: { deletingClip != nil },
                    set: { if !$0 { deletingClip = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let deletingClip {
                    Button("Move to Recently Deleted", role: .destructive) {
                        appModel.deleteCustomClip(deletingClip.id)
                        self.deletingClip = nil
                    }
                    Button("Cancel", role: .cancel) {
                        self.deletingClip = nil
                    }
                }
            } message: {
                if let deletingClip {
                    Text("\(deletingClip.displayName ?? deletingClip.playbackCue.rosterDisplayTitle) will stay in Recently Deleted for 60 days. Player Songs copied from it will not change.")
                }
            }
        }
    }

    @ViewBuilder
    private func customClipRow(_ clip: SongClip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(clip.displayName ?? clip.playbackCue.rosterDisplayTitle)
                        .font(.headline)
                    Text(clip.playbackCue.rosterDisplayTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button("Edit Clip") {
                        editingClip = clip
                    }
                    Button("Rename") {
                        renameText = clip.displayName ?? clip.playbackCue.rosterDisplayTitle
                        renamingClip = clip
                    }
                    Button("Delete", role: .destructive) {
                        deletingClip = clip
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func savePendingCue() {
        guard let cue = pendingNewCue else { return }
        _ = appModel.saveCustomClip(cue: cue, named: newClipName)
        notice = "Custom Clip saved."
        pendingNewCue = nil
    }

    private var existingClipSourceCount: Int {
        guard let team else { return 0 }
        let playerSongs = team.players.filter { team.songClip(for: $0) != nil }.count
        return playerSongs + team.teamClips.count
    }
}

private struct ExistingClipPickerSheet: View {
    enum Destination {
        case player(UUID)
        case customClip
    }

    private struct Selection: Identifiable {
        let clip: SongClip
        let suggestedCustomClipName: String

        var id: UUID { clip.id }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let destination: Destination
    @State private var selectedClip: Selection?

    var body: some View {
        NavigationStack {
            List {
                if let team = appModel.selectedTeam {
                    Section("Player Songs") {
                        ForEach(team.players.filter { shouldIncludePlayer($0, in: team) }) { player in
                            if let clip = team.songClip(for: player) {
                                let title = player.displayName
                                existingClipButton(
                                    clip: clip,
                                    title: title,
                                    subtitle: clip.playbackCue.rosterDisplayTitle,
                                    suggestedCustomClipName: "\(title) - \(clip.playbackCue.rosterDisplayTitle)"
                                )
                            }
                        }
                    }

                    Section("Custom Clips") {
                        ForEach(team.teamClips) { clip in
                            let title = clip.displayName ?? clip.playbackCue.rosterDisplayTitle
                            existingClipButton(
                                clip: clip,
                                title: title,
                                subtitle: clip.playbackCue.rosterDisplayTitle,
                                suggestedCustomClipName: title
                            )
                        }
                    }
                }
            }
            .overlay {
                if sourceCount == 0 {
                    ContentUnavailableView(
                        "No Existing Clips",
                        systemImage: "music.note",
                        description: Text("Add another Player Song or Custom Clip first.")
                    )
                }
            }
            .navigationTitle("Use Existing Clip")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedClip) { clip in
                NavigationStack {
                    SongClipEditorView(appModel: appModel, initialCue: clip.clip.editingCue) { cue in
                        saveSelectedClip(clip, editedCue: cue)
                        selectedClip = nil
                        dismiss()
                    }
                }
            }
        }
    }

    private var sourceCount: Int {
        guard let team = appModel.selectedTeam else { return 0 }
        let playerSongs = team.players.filter {
            shouldIncludePlayer($0, in: team) && team.songClip(for: $0) != nil
        }.count
        return playerSongs + team.teamClips.count
    }

    private func shouldIncludePlayer(_ player: Player, in team: Team) -> Bool {
        switch destination {
        case .player(let playerID):
            return player.id != playerID
        case .customClip:
            return true
        }
    }

    private func saveSelectedClip(_ selection: Selection, editedCue: Cue) {
        switch destination {
        case .player(let playerID):
            appModel.savePlayerSongCopy(from: selection.clip, editedCue: editedCue, to: playerID)
        case .customClip:
            _ = appModel.saveCustomClipCopy(
                from: selection.clip,
                editedCue: editedCue,
                named: selection.suggestedCustomClipName
            )
        }
    }

    private func existingClipButton(
        clip: SongClip,
        title: String,
        subtitle: String,
        suggestedCustomClipName: String
    ) -> some View {
        Button {
            selectedClip = Selection(clip: clip, suggestedCustomClipName: suggestedCustomClipName)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TeamAppleMusicPlaylistPreviewSheet: View {
    @ObservedObject var appModel: AppModel
    let summary: TeamAppleMusicPlaylistSummary
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var matchingRecovery: AppleMusicPlaylistRecovery? {
        guard appModel.appleMusicPlaylistRecovery?.summary.id == summary.id else { return nil }
        return appModel.appleMusicPlaylistRecovery
    }

    private var primaryButtonTitle: String {
        if appModel.isAppleMusicPlaylistSyncing {
            return "Saving Playlist"
        }
        if matchingRecovery != nil {
            if matchingRecovery?.availableSongIDs.isEmpty == true {
                return "No Available Songs"
            }
            return "Continue With Available Songs"
        }
        return "Create or Update Playlist"
    }

    private var canRunPrimaryAction: Bool {
        guard !appModel.isAppleMusicPlaylistSyncing else { return false }
        if let matchingRecovery {
            return !matchingRecovery.availableSongIDs.isEmpty
        }
        return summary.canUpdatePlaylist
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                    header
                    managedPlaylistWarning
                    includedSection
                    duplicateSection
                    skippedSection
                    recoverySection
                    statusSection
                    actionButtons
                }
                .padding(16)
                .padding(.bottom, RollCallSpacingTier.large.value)
            }
            .accentWashBackground()
            .navigationTitle("Apple Music Playlist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        close()
                    }
                }
            }
        }
    }

    private var header: some View {
        SectionCard {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                StatusChip(text: "Team Playlist", role: .neutral, systemImage: "music.note.list", emphasis: .subdued)
                Text(summary.playlistName)
                    .rollCallText(.primaryIdentity)
                    .lineLimit(3)
                Text("Roll Call will create this Apple Music playlist from \(summary.teamName)'s Apple Music song cues, or replace the existing Roll Call-managed playlist.")
                    .rollCallText(.helperText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var managedPlaylistWarning: some View {
        SectionCard {
            HStack(alignment: .top, spacing: RollCallSpacingTier.tight.value) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.rollCall(.warning))
                    .accessibilityHidden(true)
                Text("Roll Call manages this playlist. Manual edits to an existing Apple Music playlist may be overwritten when you create or update it.")
                    .rollCallText(.helperText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var includedSection: some View {
        PlaylistPreviewSection(
            title: "\(summary.includedSongs.count) \(summary.includedSongs.count == 1 ? "Song" : "Songs") Included",
            helperText: summary.canUpdatePlaylist ? "Apple Music catalog songs are added once." : "Choose Apple Music songs for players before creating or updating this playlist."
        ) {
            if summary.includedSongs.isEmpty {
                PlaylistEmptyMessage(text: "No Apple Music songs to add yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summary.includedSongs.enumerated()), id: \.element.id) { index, song in
                        if index > 0 { Divider() }
                        PlaylistSongRow(song: song)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var duplicateSection: some View {
        if !summary.duplicateSongs.isEmpty {
            PlaylistPreviewSection(
                title: "\(summary.duplicateSongs.count) \(summary.duplicateSongs.count == 1 ? "Duplicate" : "Duplicates") Added Once",
                helperText: "Players can share a song; the Apple Music playlist only needs one copy."
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(summary.duplicateSongs.enumerated()), id: \.element.playerID) { index, song in
                        if index > 0 { Divider() }
                        PlaylistSongRow(song: song)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var skippedSection: some View {
        if !summary.skippedCues.isEmpty {
            PlaylistPreviewSection(
                title: "\(summary.skippedCues.count) \(summary.skippedCues.count == 1 ? "Cue" : "Cues") Skipped",
                helperText: "This Apple Music playlist is a convenience list, not export, sharing, or backup."
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(summary.skippedCues.enumerated()), id: \.element.id) { index, cue in
                        if index > 0 { Divider() }
                        PlaylistSkippedCueRow(cue: cue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recoverySection: some View {
        if let recovery = matchingRecovery {
            PlaylistPreviewSection(
                title: "Apple Music Could Not Find \(recovery.unresolvedSongs.count)",
                helperText: "Cancel leaves Apple Music unchanged. Continue creates or replaces the playlist with the songs Apple Music found."
            ) {
                VStack(spacing: 0) {
                    ForEach(Array(recovery.unresolvedSongs.enumerated()), id: \.element.id) { index, song in
                        if index > 0 { Divider() }
                        PlaylistSongRow(song: song)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if appModel.isAppleMusicPlaylistSyncing {
            SectionCard {
                HStack(spacing: RollCallSpacingTier.tight.value) {
                    ProgressView()
                    Text("Saving Apple Music playlist...")
                        .rollCallText(.helperText)
                }
            }
        } else if let status = appModel.appleMusicPlaylistSyncStatus {
            SectionCard {
                Text(status)
                    .rollCallText(.helperText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: RollCallSpacingTier.tight.value) {
            Button {
                if let recovery = matchingRecovery {
                    Task { await appModel.continueAppleMusicPlaylistUpdate(recovery) }
                } else {
                    Task { await appModel.syncAppleMusicPlaylist(summary: summary) }
                }
            } label: {
                Label(primaryButtonTitle, systemImage: matchingRecovery == nil ? "music.note.list" : "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .rollCallButtonStyle(.primary)
            .disabled(!canRunPrimaryAction)

            if matchingRecovery != nil {
                Button {
                    appModel.cancelAppleMusicPlaylistRecovery()
                } label: {
                    Label("Cancel Update", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .rollCallButtonStyle(.secondary)
                .disabled(appModel.isAppleMusicPlaylistSyncing)
            }
        }
    }

    private func close() {
        appModel.clearAppleMusicPlaylistStatus()
        onDone()
        dismiss()
    }
}

private struct PlaylistPreviewSection<Content: View>: View {
    let title: String
    let helperText: String
    let content: Content

    init(
        title: String,
        helperText: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.helperText = helperText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .rollCallText(.sectionTitle)
                Text(helperText)
                    .rollCallText(.helperText)
            }
            .padding(.horizontal, 2)

            SectionCard {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct PlaylistSongRow: View {
    let song: TeamAppleMusicPlaylistSongRow

    var body: some View {
        HStack(alignment: .top, spacing: RollCallSpacingTier.tight.value) {
            Image(systemName: "music.note")
                .foregroundStyle(Color.rollCall(.ready))
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(song.title)
                    .rollCallText(.cardTitle)
                    .lineLimit(2)
                Text(song.artistName)
                    .rollCallText(.helperText)
                    .lineLimit(2)
                Text(song.playerName)
                    .rollCallText(.helperText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, RollCallSpacingTier.tight.value)
    }
}

private struct PlaylistSkippedCueRow: View {
    let cue: TeamAppleMusicPlaylistSkippedCue

    var body: some View {
        HStack(alignment: .top, spacing: RollCallSpacingTier.tight.value) {
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(cue.playerName)
                    .rollCallText(.cardTitle)
                    .lineLimit(2)
                if let title = cue.title {
                    Text(cue.artistName.map { "\(title) - \($0)" } ?? title)
                        .rollCallText(.helperText)
                        .lineLimit(2)
                }
                Text(cue.reason.explanation)
                    .rollCallText(.helperText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, RollCallSpacingTier.tight.value)
    }
}

private struct PlaylistEmptyMessage: View {
    let text: String

    var body: some View {
        Text(text)
            .rollCallText(.helperText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, RollCallSpacingTier.tight.value)
    }
}

private extension ReadinessState {
    var readinessLabel: String {
        switch self {
        case .ready: return "Ready"
        case .enhanced: return "Enhanced"
        case .needsAudio: return "Needs Audio"
        case .optional: return "Optional"
        case .gameDayCheck: return "Check"
        case .issue: return "Issue"
        }
    }

    var statusChipRole: StatusChipRole {
        switch self {
        case .ready: return .ready
        case .enhanced: return .live
        case .needsAudio: return .warning
        case .optional, .gameDayCheck: return .neutral
        case .issue: return .destructive
        }
    }

    var statusChipIcon: String {
        switch self {
        case .ready: return "checkmark.circle"
        case .enhanced: return "star.circle"
        case .needsAudio: return "music.note"
        case .optional: return "circle"
        case .gameDayCheck: return "checklist"
        case .issue: return "exclamationmark.triangle"
        }
    }

    var semanticColor: Color {
        switch self {
        case .ready: return Color.rollCall(.ready)
        case .enhanced: return Color.rollCall(.live)
        case .needsAudio: return Color.rollCall(.warning)
        case .optional, .gameDayCheck: return Color(uiColor: .secondaryLabel)
        case .issue: return Color.rollCall(.destructive)
        }
    }

    var cardFamily: RollCallCardFamily {
        switch self {
        case .ready, .enhanced, .optional, .gameDayCheck:
            return .utility
        case .needsAudio, .issue:
            return .status
        }
    }
}

private struct AppBannerView: View {
    let message: AppBannerMessage

    private var tint: Color {
        switch message.style {
        case .success:
            return Color.rollCall(.ready)
        case .warning:
            return Color.rollCall(.warning)
        }
    }

    private var symbol: String {
        switch message.style {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(message.text)
                .rollCallText(.helperText)
                .foregroundStyle(Color(uiColor: .label))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

private struct SettingsSectionGroup<Content: View>: View {
    let title: String
    let helperText: String?
    let content: Content

    init(
        title: String,
        helperText: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.helperText = helperText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .rollCallText(.sectionTitle)
                if let helperText {
                    Text(helperText)
                        .rollCallText(.helperText)
                }
            }
            .padding(.horizontal, 2)

            SectionCard {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct WhatsNewSheet: View {
    let bundle: WhatsNewBundle
    let onDone: () -> Void

    private var versionSubline: String {
        "Roll Call \(AppMetadata.appVersion) (build \(AppMetadata.buildNumber))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("What's New in \(bundle.family)")
                            .rollCallText(.screenTitle)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(versionSubline)
                            .rollCallText(.helperText)
                    }

                    ForEach(bundle.releases) { release in
                        releaseSection(release)
                    }

                    Link(destination: bundle.fullChangelogURL) {
                        FullChangelogLinkLabel()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, RollCallSpacingTier.large.value)
                .padding(.top, RollCallSpacingTier.tight.value)
                .padding(.bottom, RollCallSpacingTier.large.value)
            }
            .accentWashBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone)
                }
            }
        }
    }

    @ViewBuilder
    private func releaseSection(_ release: WhatsNewRelease) -> some View {
        if bundle.releases.count == 1 {
            releaseHighlightList(release)
        } else {
            SettingsSectionGroup(title: release.version) {
                releaseHighlightList(release)
            }
        }
    }

    private func releaseHighlightList(_ release: WhatsNewRelease) -> some View {
        VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
            if let intro = release.intro {
                Text(intro)
                    .rollCallText(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(release.highlights) { highlight in
                whatsNewHighlightCard(highlight)
            }

            if let lookingAhead = release.lookingAhead {
                subduedLookingAheadCard(lookingAhead)
            }
        }
    }

    private func whatsNewHighlightCard(_ highlight: WhatsNewHighlight) -> some View {
        SectionCard(family: .utility) {
            HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
                SettingsIcon(systemImage: highlight.systemImage, role: .accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(highlight.title)
                        .rollCallText(.cardTitle)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(highlight.detail)
                        .rollCallText(.helperText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func subduedLookingAheadCard(_ highlight: WhatsNewHighlight) -> some View {
        SectionCard(family: .utility) {
            HStack(alignment: .top, spacing: RollCallSpacingTier.standard.value) {
                SettingsIcon(systemImage: highlight.systemImage, role: .accent)
                    .opacity(0.65)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Looking Ahead")
                        .rollCallText(.helperText)
                    Text(highlight.title)
                        .rollCallText(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(highlight.detail)
                        .rollCallText(.helperText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opacity(0.82)
        }
    }
}

private struct FullChangelogLinkLabel: View {
    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    var body: some View {
        HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
            SettingsIcon(systemImage: "safari.fill", role: .accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Full Changelog")
                    .rollCallText(.cardTitle)
                    .foregroundStyle(teamAccentTheme.color(.primary))
                    .lineLimit(2)
                Text("Open the complete Roll Call update notes on the web.")
                    .rollCallText(.helperText)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.up.forward")
                .font(.footnote.weight(.bold))
                .foregroundStyle(teamAccentTheme.color(.primary))
                .frame(width: 28, height: 28)
                .background(teamAccentTheme.color(.subtle).opacity(0.13))
                .clipShape(Circle())
                .accessibilityHidden(true)
        }
        .padding(RollCallInsets.card)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(teamAccentTheme.color(.primary).opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct AttributionsView: View {
    private let generalClips = [
        "Small Cheer",
        "Victory Roar",
        "Stadium Burst",
        "Rhythmic Clap",
        "Whistle Pop"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                SettingsSectionGroup(title: "Roll Call") {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                        Text("© 2026 Sidelark Labs; John Kenneth Fisher")
                            .rollCallText(.body)

                        Link(destination: URL(string: "https://github.com/JohnKFisher/rollcall")!) {
                            SettingsRowLabel(
                                title: "Public GitHub Project",
                                detail: "github.com/JohnKFisher/rollcall",
                                systemImage: "link"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSectionGroup(
                    title: "Bundled Sound Effects",
                    helperText: "Roll Call includes bundled crowd sound effects from Mixkit."
                ) {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                        SettingsRowLabel(
                            title: "Mixkit Sound Effects",
                            detail: "Licensed under the Mixkit Sound Effects Free License.",
                            systemImage: "waveform"
                        )

                        Text(generalClips.joined(separator: ", "))
                            .rollCallText(.helperText)

                        Link(destination: URL(string: "https://mixkit.co/free-sound-effects/")!) {
                            SettingsRowLabel(
                                title: "Mixkit Sound Effects Catalog",
                                detail: "Source catalog for the bundled clip set.",
                                systemImage: "link"
                            )
                        }
                        .buttonStyle(.plain)

                        Link(destination: URL(string: "https://mixkit.co/license/")!) {
                            SettingsRowLabel(
                                title: "Mixkit License",
                                detail: "License terms for Mixkit sound effects.",
                                systemImage: "doc.text.fill"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSectionGroup(
                    title: "Third-Party Software",
                    helperText: "Roll Call uses ZIPFoundation for packages and TelemetryDeck for optional anonymous usage analytics."
                ) {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                        SettingsRowLabel(
                            title: "ZIPFoundation 0.9.20",
                            detail: "MIT License. Copyright Thomas Zoechling and contributors.",
                            systemImage: "shippingbox.fill"
                        )

                        Link(destination: URL(string: "https://github.com/weichsel/ZIPFoundation")!) {
                            SettingsRowLabel(
                                title: "ZIPFoundation Project",
                                detail: "github.com/weichsel/ZIPFoundation",
                                systemImage: "link"
                            )
                        }
                        .buttonStyle(.plain)

                        SettingsRowLabel(
                            title: "TelemetryDeck Swift SDK 2.14.2",
                            detail: "MIT License. Copyright TelemetryDeck and contributors.",
                            systemImage: "chart.bar.xaxis"
                        )

                        Link(destination: URL(string: "https://github.com/TelemetryDeck/SwiftSDK")!) {
                            SettingsRowLabel(
                                title: "TelemetryDeck Swift SDK Project",
                                detail: "github.com/TelemetryDeck/SwiftSDK",
                                systemImage: "link"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSectionGroup(title: "Special Thanks") {
                    SettingsRowLabel(
                        title: "The Girls of the Piscataway Thunder Softball Team",
                        detail: "For inspiring the unending game-day energy behind Roll Call.",
                        systemImage: "heart.fill"
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, RollCallSpacingTier.tight.value)
            .padding(.bottom, RollCallSpacingTier.large.value)
        }
        .accentWashBackground()
        .navigationTitle("Attributions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsNavigationLabel: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: RollCallSpacingTier.standard.value) {
            SettingsRowLabel(title: title, detail: detail, systemImage: systemImage)
            Spacer(minLength: RollCallSpacingTier.standard.value)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .contentShape(Rectangle())
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let detail: String
    let systemImage: String
    var style: Style = .standard

    enum Style {
        case standard
        case filledAction
    }

    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    private var actionForeground: Color? {
        switch style {
        case .standard:
            return nil
        case .filledAction:
            return teamAccentTheme.color(.onFill)
        }
    }

    private var titleForeground: Color {
        actionForeground ?? Color(uiColor: .label)
    }

    private var detailForeground: Color {
        actionForeground?.opacity(0.74) ?? Color(uiColor: .secondaryLabel)
    }

    var body: some View {
        HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
            SettingsIcon(systemImage: systemImage, role: .accent, colorOverride: actionForeground)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(titleForeground)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(detailForeground)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}

private struct SettingsIcon: View {
    let systemImage: String
    let role: RollCallColorRole
    var colorOverride: Color? = nil

    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    private var color: Color {
        if let colorOverride {
            return colorOverride
        }
        return role == .accent ? teamAccentTheme.color(.primary) : Color.rollCall(role)
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(color.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct PackageExportPreviewSheet: View {
    let pending: PendingPackageExport
    let onExport: () -> Void
    let onPrepareFirst: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Roll Call will include portable local clips. Apple Music-linked songs remain saved as links and may need Apple Music access on the receiving device.")
                        .rollCallText(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("For players with newly selected photos, the package also includes Roll Call's clean working master so profile and Player Card framing can be adjusted after import. That image may show more of the original scene than the visible profile crop.")
                        .rollCallText(.helperText)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PackageTransferSummarySection(summary: pending.summary)

                if pending.summary.stillPreparingCount > 0 {
                    Section {
                        Text("Some clips are still preparing. You can export now, but waiting may allow more portable local clips to be included.")
                            .rollCallText(.helperText)
                            .foregroundStyle(.secondary)
                        Button("Try Preparing Clips First", action: onPrepareFirst)
                    }
                }

                if pending.summary.needsRepairCount > 0 {
                    Section {
                        Text("Some saved audio already needs repair on this device. Its identifying information will remain in the package, but the missing audio cannot be included.")
                            .rollCallText(.helperText)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accentWashListBackground()
            .navigationTitle("Share \(pending.teamName)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share Package", action: onExport)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct PackageImportAuditSheet: View {
    let audit: PackageImportAudit
    let onAppleMusicCheck: () -> Void
    let onRepair: (PackageImportAudit.Item) -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("The team was imported. Roll Call checked what is actually ready on this device and preserved any song choices that still need attention.")
                        .rollCallText(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PackageTransferSummarySection(summary: audit.summary)

                Section("Import Check") {
                    ForEach(audit.items) { item in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.title)
                                    .rollCallText(.cardTitle)
                                Spacer(minLength: 8)
                                if item.state == .needsAppleMusicCheck {
                                    Button(action: onAppleMusicCheck) {
                                        Text(item.state.packageLabel)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(item.state.packageColor)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityHint("Checks Apple Music access for this imported team.")
                                } else {
                                    Text(item.state.packageLabel)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(item.state.packageColor)
                                }
                            }
                            Text(item.detail)
                                .rollCallText(.helperText)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if item.state == .needsAppleMusic
                                || item.state == .needsRepair
                                || item.state == .photoSourceMissing {
                                Button(item.destination.repairButtonTitle) {
                                    onRepair(item)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .accentWashListBackground()
            .navigationTitle("Import Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct PackageTransferSummarySection: View {
    let summary: PackageTransferSummary

    var body: some View {
        Section("Clip Portability") {
            PackageImportStatRow(title: "Local clips included", value: "\(summary.localClipIncludedCount)")
            PackageImportStatRow(title: "Apple Music links", value: "\(summary.sourceReferenceOnlyCount)")
            PackageImportStatRow(title: "Needs Apple Music", value: "\(summary.needsAppleMusicCount)")
            PackageImportStatRow(title: "Still preparing", value: "\(summary.stillPreparingCount)")
            PackageImportStatRow(title: "Needs repair", value: "\(summary.needsRepairCount)")
        }
    }
}

private extension PackageClipTransferState {
    var packageLabel: String {
        switch self {
        case .localClipIncluded: return "Local File Ready"
        case .sourceReferenceOnly: return "Apple Music Ready"
        case .needsAppleMusicCheck: return "Needs Apple Music"
        case .needsAppleMusic: return "Needs Apple Music"
        case .stillPreparing: return "Preparing"
        case .needsRepair: return "Needs Repair"
        case .photoSourceMissing: return "Profile Only"
        }
    }

    var packageColor: Color {
        switch self {
        case .localClipIncluded, .sourceReferenceOnly: return Color.rollCall(.ready)
        case .needsAppleMusicCheck, .stillPreparing: return Color.rollCall(.warning)
        case .needsAppleMusic, .needsRepair: return Color.rollCall(.destructive)
        case .photoSourceMissing: return Color.rollCall(.warning)
        }
    }
}

private extension PackageImportAudit.Item.Destination {
    var repairButtonTitle: String {
        switch self {
        case .player: return "Open Player Repair"
        case .teamClip: return "Open Custom Clips"
        }
    }
}

private struct PackageImportConfirmationSheet: View {
    let pending: PendingPackageImport
    let onImport: () -> Void
    let onCancel: () -> Void

    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    private var teamName: String {
        let trimmed = pending.team.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unnamed Team" : trimmed
    }

    private var formattedExportDate: String {
        pending.manifest.exportedAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.tight.value) {
                        Label("You are importing team \(teamName).", systemImage: "shippingbox.fill")
                            .font(.headline)
                            .foregroundStyle(teamAccentTheme.color(.primary))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Roll Call will add this as a new team and save a backup first. Existing teams stay unchanged.")
                            .rollCallText(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }

                Section("Package") {
                    PackageImportStatRow(title: "Source", value: pending.manifest.deviceLabel)
                    PackageImportStatRow(title: "Exported", value: formattedExportDate)
                    PackageImportStatRow(title: "Version", value: pending.manifest.appVersion)
                }

                Section("Team Contents") {
                    PackageImportStatRow(title: "Players", value: "\(pending.playerCount)")
                    PackageImportStatRow(title: "Players with Audio", value: "\(pending.playersWithAudioCount)")
                    PackageImportStatRow(title: "Apple Music Cues", value: "\(pending.appleMusicCueCount)")
                    PackageImportStatRow(title: "Local Audio Cues", value: "\(pending.localAudioCueCount)")
                    PackageImportStatRow(title: "Built-In Cue Fallbacks", value: "\(pending.builtInCueCount)")
                    PackageImportStatRow(title: "Player Photos", value: "\(pending.photoCount)")
                    PackageImportStatRow(title: "Announcement Cues", value: "\(pending.customAnnouncementCount)")
                    PackageImportStatRow(title: "Built-In Sound Effects", value: "\(pending.team.builtInClips.count)")
                    PackageImportStatRow(title: "Custom Clips", value: "\(pending.customClipCount)")
                }

                PackageTransferSummarySection(summary: pending.transferSummary)

                if pending.transferSummary.hasDeviceDependentClips {
                    Section {
                        Text("Apple Music-linked songs are preserved, but this device still needs its own Apple Music access and song availability.")
                            .rollCallText(.helperText)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .accentWashListBackground()
            .navigationTitle("Import Team?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Don’t Import", role: .cancel) {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct PackageImportStatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .rollCallText(.body)
    }
}

private struct RosterImportPreviewSheet: View {
    let pending: PendingRosterImport
    let duplicateCount: Int
    let duplicateMessage: String
    let onCancel: () -> Void
    let onImport: () -> Void

    private var sectionTitle: String {
        "Importing \(pending.rows.count) players from \(pending.sourceName)"
    }

    private var importButtonTitle: String {
        duplicateCount > 0 ? "Import Anyway" : "Import"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("This will add \(pending.rows.count) players to the team selected when the import started. Roll Call will save a backup first.")
                        .rollCallText(.body)
                    Text("CSV format: use a header row with name and number, or simple two-column rows. Player number is optional.")
                        .rollCallText(.helperText)
                    if duplicateCount > 0 {
                        Label(duplicateMessage, systemImage: "exclamationmark.triangle.fill")
                            .rollCallText(.helperText)
                            .foregroundStyle(Color.rollCall(.warning))
                    }
                }

                Section(sectionTitle) {
                    ForEach(pending.rows) { player in
                        HStack {
                            Text(player.displayName)
                            Spacer()
                            if !player.uniformNumber.isEmpty {
                                Text("#\(player.uniformNumber)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .accentWashListBackground()
            .navigationTitle("Roster Preview")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(importButtonTitle) {
                        onImport()
                    }
                }
            }
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onCompleted: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCompleted: onCompleted) }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onCompleted(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}

    final class Coordinator {
        let onCompleted: (Bool) -> Void
        init(onCompleted: @escaping (Bool) -> Void) { self.onCompleted = onCompleted }
    }
}

private struct QuickGameDayHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(Color.rollCall(.accent))
                        .accessibilityHidden(true)

                    Text("Open Game Day faster")
                        .font(.title2.bold())

                    Text("Add Roll Call's Open Game Day control to Control Center or the Lock Screen, assign it to the Action Button, or run Open Game Day from Shortcuts, Siri, or Spotlight.")

                    Label("The control uses the team you most recently opened intentionally in Game Day.", systemImage: "clock.arrow.circlepath")
                    Label("Shortcuts can optionally choose a specific team.", systemImage: "person.3.fill")
                    Label("Quick Game Day opens the existing Game Day screen. It never starts audio automatically.", systemImage: "speaker.slash.fill")

                    Text("System controls require a supported version of iOS. Roll Call's regular Game Day experience remains available on every supported device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Quick Game Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct RollCallPackageImportSheet: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.rollCallPackage, .data, .folder],
            asCopy: false
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onPick(url)
        }
    }
}

private struct GameDayBackground: View {
    var body: some View {
        AccentWashBackground(surface: .live)
    }
}

private struct AccentWashBackground: View {
    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    var surface: RollCallSurfaceVariant = .standard
    var accentTint: Color? = nil

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            LinearGradient(
                colors: [
                    .clear,
                    (accentTint ?? teamAccentTheme.color(.subtle, surface: surface)).opacity(gradientOpacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var gradientOpacity: Double {
        surface == .live ? 0.18 : 0.12
    }
}

private struct GameDayBoard: View {
    @ObservedObject var appModel: AppModel
    let onLineup: () -> Void

    private enum Layout {
        static let sectionSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 17
        static let topPadding: CGFloat = 12
        static let bottomPadding: CGFloat = 29
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                if let team = appModel.selectedTeam {
                    GameDayTeamStack(appModel: appModel, team: team, onLineup: onLineup)
                } else {
                    GameDayNoTeamStack()
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Layout.topPadding)
            .padding(.bottom, Layout.bottomPadding)
        }
    }
}

private struct GameDayTeamStack: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var playbackEngine: CuePlaybackEngine
    let team: Team
    let onLineup: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lineupProgressFocus: GameDayLineupProgressFocus?
    @State private var lineupProgressTask: Task<Void, Never>?

    init(appModel: AppModel, team: Team, onLineup: @escaping () -> Void) {
        self.appModel = appModel
        self.team = team
        self.onLineup = onLineup
        _playbackEngine = ObservedObject(initialValue: appModel.playbackEngine)
    }

    private var presentPlayers: [Player] {
        team.presentPlayersInBattingOrder
    }

    private var gameDayGridPlayers: [Player] {
        team.gameDayGridPlayers(startingAfter: onDeckPlayer?.id)
    }

    private var activePlayer: Player? {
        presentPlayers.first(where: isActive)
    }

    private var lineupNowPlayer: Player? {
        team.nextBatter
    }

    private var overridePlayer: Player? {
        team.gameDayOverridePlayer(activePlayerID: activePlayer?.id)
    }

    private var displayedNowPlayer: Player? {
        overridePlayer ?? lineupNowPlayer
    }

    private var nowBattingLabel: String {
        overridePlayer == nil ? "Now Batting" : "Lineup Override"
    }

    private var onDeckPlayer: Player? {
        nextPlayer(after: lineupNowPlayer)
    }

    private var hintParticipantPlayers: [Player] {
        let excludedIDs = Set([lineupNowPlayer?.id, onDeckPlayer?.id].compactMap { $0 })
        return gameDayGridPlayers.filter { !excludedIDs.contains($0.id) }
    }

    private var fullLineupProgressSequence: [GameDayLineupProgressFocus] {
        var sequence = hintParticipantPlayers
            .prefix(3)
            .reversed()
            .map { GameDayLineupProgressFocus.grid($0.id) }

        if let onDeckPlayer {
            sequence.append(.onDeck(onDeckPlayer.id))
        }
        if let lineupNowPlayer {
            sequence.append(.nowBatting(lineupNowPlayer.id))
        }
        return sequence
    }

    private var liveWarning: GameDayLiveWarning? {
        if presentPlayers.isEmpty {
            return GameDayLiveWarning(text: "No present players in the lineup", role: .warning)
        }

        guard let readiness = appModel.selectedTeamReadiness else { return nil }
        let issues = readiness.checks.filter(isLiveReadinessIssue)
        guard let firstIssue = issues.first else { return nil }
        if issues.count == 1 {
            return GameDayLiveWarning(text: firstIssue.detail, role: role(for: firstIssue.state))
        }
        return GameDayLiveWarning(text: "\(issues.count) live warnings - \(firstIssue.title)", role: role(for: firstIssue.state))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GameDayAnnouncerModePicker(
                selectedMode: team.session.gameDayAnnouncerMode,
                onSelect: appModel.setGameDayAnnouncerMode
            )

            if let liveWarning {
                GameDayWarningStrip(warning: liveWarning)
            }

            if let displayedNowPlayer {
                GameDayNowBattingHero(
                    appModel: appModel,
                    teamID: team.id,
                    player: displayedNowPlayer,
                    titleLabel: nowBattingLabel,
                    isActive: isActive(displayedNowPlayer),
                    announcerMode: team.session.gameDayAnnouncerMode,
                    isLineupProgressFocused: lineupProgressFocus == .nowBatting(displayedNowPlayer.id)
                )
            } else {
                GameDayEmptyHero(
                    title: "No Present Players",
                    detail: "Open the lineup and mark players present before game day."
                )
            }

            GameDayOnDeckCard(
                appModel: appModel,
                player: onDeckPlayer,
                announcerMode: team.session.gameDayAnnouncerMode,
                isLineupProgressFocused: onDeckPlayer.map { lineupProgressFocus == .onDeck($0.id) } ?? false
            )

            GameDayControlRow(
                appModel: appModel,
                onLineup: onLineup
            )

            GameDayGridDivider()

            GameDayPlayerGrid(
                appModel: appModel,
                teamID: team.id,
                players: gameDayGridPlayers,
                nowPlayerID: lineupNowPlayer?.id,
                onDeckPlayerID: onDeckPlayer?.id,
                announcerMode: team.session.gameDayAnnouncerMode,
                lineupProgressFocusedPlayerID: lineupProgressGridPlayerID
            )
        }
        .onChange(of: appModel.gameDayLineupProgressHintEvent) { _, event in
            guard let event, event.teamID == team.id else { return }
            restartLineupProgressHintIfNeeded(source: event.source)
        }
        .onChange(of: appModel.state.settings.showLineupProgressHints) { _, isEnabled in
            if !isEnabled {
                cancelLineupProgressHint()
            }
        }
        .onChange(of: reduceMotion) { _, shouldReduce in
            if shouldReduce {
                cancelLineupProgressHint()
            }
        }
        .onDisappear {
            cancelLineupProgressHint()
        }
    }

    private var lineupProgressGridPlayerID: UUID? {
        if case .grid(let playerID) = lineupProgressFocus {
            return playerID
        }
        return nil
    }

    private func isActive(_ player: Player) -> Bool {
        if let cueID = team.cue(for: player)?.id {
            return playbackEngine.activeCueID == cueID
        }
        return playbackEngine.activeCueID == player.id
    }

    private func nextPlayer(after player: Player?) -> Player? {
        guard presentPlayers.count > 1 else { return nil }
        guard let player, let index = presentPlayers.firstIndex(where: { $0.id == player.id }) else {
            return presentPlayers.dropFirst().first
        }
        return presentPlayers[(index + 1) % presentPlayers.count]
    }

    private func isLiveReadinessIssue(_ check: ReadinessCheck) -> Bool {
        guard check.state == .issue else { return false }
        if check.category == .playerPhoto { return false }
        if check.category == .playerAnnouncement {
            return team.session.gameDayAnnouncerMode.usesAnnouncer
        }
        if check.category == .playerAudio {
            return check.playerID.map { playerID in presentPlayers.contains { $0.id == playerID } } ?? false
        }
        if check.category == .volume {
            return !appModel.state.settings.fadeOutVolumeAutomationEnabled
        }
        return [.audioRoute, .network, .appleMusicAccess, .lineup].contains(check.category)
    }

    private func willUseFallback(for player: Player) -> Bool {
        switch team.session.gameDayAnnouncerMode {
        case .announcerOnly:
            return !appModel.hasStoredCustomAnnouncer(for: player)
        case .announcerAndSong, .songOnly:
            return team.cue(for: player) == nil
        }
    }

    private func role(for state: ReadinessState) -> StatusChipRole {
        state == .issue ? .destructive : .warning
    }

    private func restartLineupProgressHintIfNeeded(source: GameDayLineupProgressHintSource) {
        cancelLineupProgressHint()
        guard appModel.state.settings.showLineupProgressHints else { return }
        guard !reduceMotion else { return }
        let sequence = lineupProgressSequence(for: source)
        guard !sequence.isEmpty else { return }

        lineupProgressTask = Task { @MainActor in
            defer { lineupProgressTask = nil }
            for focus in sequence {
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.14)) {
                    lineupProgressFocus = focus
                }
                try? await Task.sleep(for: .milliseconds(140))
            }

            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.14)) {
                lineupProgressFocus = nil
            }
        }
    }

    private func cancelLineupProgressHint() {
        lineupProgressTask?.cancel()
        lineupProgressTask = nil
        lineupProgressFocus = nil
    }

    private func lineupProgressSequence(for source: GameDayLineupProgressHintSource) -> [GameDayLineupProgressFocus] {
        switch source {
        case .nextButton:
            // Experimental narrower Next hint: keep only the closest grid slot,
            // then the existing On Deck -> Now Batting handoff.
            return Array(fullLineupProgressSequence.suffix(3))
        case .onDeckCard:
            var sequence: [GameDayLineupProgressFocus] = []
            if let onDeckPlayer {
                sequence.append(.onDeck(onDeckPlayer.id))
            }
            if let lineupNowPlayer {
                sequence.append(.nowBatting(lineupNowPlayer.id))
            }
            return sequence
        }
    }
}

private enum GameDayLineupProgressFocus: Equatable {
    case grid(UUID)
    case onDeck(UUID)
    case nowBatting(UUID)
}

private struct GameDayNoTeamStack: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GameDayWarningStrip(warning: GameDayLiveWarning(text: "No team selected", role: .warning))
            GameDayEmptyHero(
                title: "No Team Selected",
                detail: "Choose or create a team before using live player cues."
            )
        }
    }
}

private struct GameDayLiveWarning {
    let text: String
    let role: StatusChipRole
}

private struct GameDayWarningStrip: View {
    let warning: GameDayLiveWarning

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: warning.role == .destructive ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
            Text(warning.text)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(warning.role == .destructive ? Color.rollCall(.destructive, surface: .live) : Color.rollCall(.warning, surface: .live))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.rollCall(.neutralSurface, surface: .live), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(liveAccentOutlineColor(theme: teamAccentTheme, colorScheme: colorScheme, lightOpacity: 0.75, darkOpacity: 0.37), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct GameDayNowBattingHero: View {
    @ObservedObject var appModel: AppModel
    let teamID: UUID
    let player: Player
    let titleLabel: String
    let isActive: Bool
    let announcerMode: GameDayAnnouncerMode
    let isLineupProgressFocused: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    private var cueTitle: String {
        switch announcerMode {
        case .announcerOnly:
            return hasCustomAnnouncer ? "Announcer Only" : "Fallback: Small Cheer"
        case .announcerAndSong, .songOnly:
            if willUseFallback { return "Fallback: Small Cheer" }
            if let cue = appModel.resolvedCue(for: player) {
                return cue.label
            }
            return "Fallback: Small Cheer"
        }
    }

    private var cueTitleShowsMusicIcon: Bool {
        announcerMode != .announcerOnly && !willUseFallback && appModel.resolvedCue(for: player) != nil
    }

    private var hasCustomAnnouncer: Bool {
        appModel.hasStoredCustomAnnouncer(for: player)
    }

    private var willUseFallback: Bool {
        switch announcerMode {
        case .announcerOnly:
            return !hasCustomAnnouncer
        case .announcerAndSong, .songOnly:
            return appModel.playerWillUseFallback(for: player) || (isActive && appModel.isPlayingFallback(for: player))
        }
    }

    private var statusText: String {
        if isActive { return "Playing" }
        if willUseFallback { return "Fallback available" }
        return "Ready"
    }

    private var actionTitle: String {
        if isActive { return "Tap Again to Stop" }
        if willUseFallback { return "Play Fallback" }
        switch announcerMode {
        case .announcerOnly:
            return "Play Announcer"
        case .announcerAndSong:
            return hasCustomAnnouncer ? "Play Announcer + Song" : "Play Song"
        case .songOnly:
            return "Play Song"
        }
    }

    private var cueIcons: [GameDayTileCueIcon] {
        let hasSong = appModel.resolvedCue(for: player) != nil && !willUseFallback
        let availableColor = Color.rollCall(.ready, surface: .live)
        let missingColor = Color.rollCall(.destructive, surface: .live)

        switch announcerMode {
        case .announcerOnly:
            return [
                GameDayTileCueIcon(
                    id: "announcer",
                    systemImage: hasCustomAnnouncer ? "microphone.fill" : "microphone.slash.fill",
                    color: hasCustomAnnouncer ? availableColor : missingColor
                )
            ]
        case .announcerAndSong:
            return [
                GameDayTileCueIcon(
                    id: "announcer",
                    systemImage: hasCustomAnnouncer ? "microphone.fill" : "microphone.slash.fill",
                    color: hasCustomAnnouncer ? availableColor : missingColor
                ),
                GameDayTileCueIcon(
                    id: "song",
                    systemImage: hasSong ? "music.note" : "music.note.slash",
                    color: hasSong ? availableColor : missingColor
                )
            ]
        case .songOnly:
            return [
                GameDayTileCueIcon(
                    id: "song",
                    systemImage: hasSong ? "music.note" : "music.note.slash",
                    color: hasSong ? availableColor : missingColor
                )
            ]
        }
    }

    private var heroStateIcon: GameDayTileState? {
        GameDayTileState(
            text: statusText,
            systemImage: isActive ? "speaker.wave.3.fill" : "figure.baseball",
            color: isActive ? Color.rollCall(.live, surface: .live) : Color.rollCall(.ready, surface: .live),
            animatesSymbol: isActive
        )
    }

    var body: some View {
        Button {
            if isCurrentlyActive {
                appModel.stopPlayback()
            } else {
                Task { await appModel.play(player: player, teamID: teamID) }
            }
        } label: {
            heroContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PlayerPhotoThumbnail(relativePath: player.photoRelativePath, size: 72, cornerRadius: 18)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(titleLabel)
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))

                        if !player.uniformNumber.isEmpty {
                            Text("•")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                            Text("#\(player.uniformNumber)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(teamAccentTheme.color(.primary, surface: .live))
                        }
                    }

                    Text(player.displayName)
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(Color(uiColor: .label))
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .allowsTightening(true)

                }

                Spacer(minLength: 0)
                GameDayPanelIconRow(tileState: heroStateIcon, cueIcons: cueIcons)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    if cueTitleShowsMusicIcon {
                        Image(systemName: "music.note")
                    }
                    Text(cueTitle)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(uiColor: .label))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            }

            HStack(spacing: 10) {
                Image(systemName: isActive ? "stop.fill" : "play.fill")
                Text(actionTitle)
                    .font(.headline.weight(.bold))
                Spacer(minLength: 0)
                if isActive {
                    Text("Playing")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                }
            }
            .foregroundStyle(isActive ? Color.white : Color(uiColor: .label))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                isActive ? Color.rollCall(.live, surface: .live) : Color.rollCall(.neutralSurface, surface: .live),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isActive ? Color(uiColor: .label).opacity(0.50) : liveAccentOutlineColor(theme: teamAccentTheme, colorScheme: colorScheme, lightOpacity: 0.8, darkOpacity: 0.4), lineWidth: 1)
            )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(heroBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(heroBorderColor, lineWidth: heroBorderWidth)
        )
        .shadow(color: heroShadowColor, radius: isActive ? 14 : 10, y: isActive ? 8 : 6)
        .animation(.easeInOut(duration: 0.18), value: isLineupProgressFocused)
        .accessibilityElement(children: .combine)
    }

    private var accessibilityLabel: String {
        "\(titleLabel), \(player.displayName), \(statusText), \(cueTitle), \(isActive ? "tap again to stop" : actionTitle)"
    }

    private var cueIconRow: some View {
        HStack(spacing: 6) {
            ForEach(cueIcons) { icon in
                Image(systemName: icon.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(icon.color)
            }
        }
    }

    private var isCurrentlyActive: Bool {
        if let cueID = appModel.resolvedCue(for: player)?.id {
            return appModel.playbackEngine.activeCueID == cueID
            }
        return appModel.playbackEngine.activeCueID == player.id
    }

    private var heroBackgroundColor: Color {
        if isActive {
            return Color.rollCall(.live, surface: .live).opacity(0.24)
        }
        if isLineupProgressFocused {
            return teamAccentTheme.color(.primary, surface: .live).opacity(0.22)
        }
        return Color.rollCall(.neutralSurface, surface: .live)
    }

    private var heroBorderColor: Color {
        if isActive {
            return Color.rollCall(.live, surface: .live).opacity(0.95)
        }
        if isLineupProgressFocused {
            return teamAccentTheme.color(.primary, surface: .live).opacity(0.95)
        }
        return liveAccentOutlineColor(theme: teamAccentTheme, colorScheme: colorScheme, lightOpacity: 0.85, darkOpacity: 0.44)
    }

    private var heroBorderWidth: CGFloat {
        if isActive {
            return 2
        }
        return isLineupProgressFocused ? 1.75 : 1
    }

    private var heroShadowColor: Color {
        if isActive {
            return Color.rollCall(.live, surface: .live).opacity(0.20)
        }
        if isLineupProgressFocused {
            return teamAccentTheme.color(.primary, surface: .live).opacity(0.18)
        }
        return .clear
    }
}

private struct GameDayOnDeckCard: View {
    @ObservedObject var appModel: AppModel
    let player: Player?
    let announcerMode: GameDayAnnouncerMode
    let isLineupProgressFocused: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    var body: some View {
        Group {
            if player != nil {
                Button {
                    appModel.advanceNextBatterFromOnDeck()
                } label: {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityHint("Moves this player to Now Batting.")
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            if let player {
                playerContent(for: player)
            } else {
                emptyContent
            }
        }
        .padding(12)
        .background(onDeckBackgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(onDeckBorderColor, lineWidth: isLineupProgressFocused ? 2 : 1)
        )
        .shadow(color: isLineupProgressFocused ? teamAccentTheme.color(.primary, surface: .live).opacity(0.18) : .clear, radius: 10, y: 6)
        .animation(.easeInOut(duration: 0.18), value: isLineupProgressFocused)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func playerContent(for player: Player) -> some View {
        Group {
            PlayerPhotoThumbnail(relativePath: player.photoRelativePath, size: 42, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("On Deck")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color(uiColor: .secondaryLabel))

                    if !player.uniformNumber.isEmpty {
                        Text("•")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        Text("#\(player.uniformNumber)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(teamAccentTheme.color(.primary, surface: .live))
                    }
                }
                Text(player.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(uiColor: .label))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 0)
            GameDayPanelIconRow(
                tileState: GameDayTileState(
                    text: "On Deck",
                    systemImage: "person.crop.circle.badge.clock",
                    color: Color.rollCall(.ready, surface: .live)
                ),
                cueIcons: onDeckCueIcons(for: player)
            )
        }
    }

    private var emptyContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 4) {
                Text("On Deck")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                Text("No on deck player")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(uiColor: .label))
                Text("Mark another player present to show who is next.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            Spacer(minLength: 0)
        }
    }

    private func onDeckCueIcons(for player: Player) -> [GameDayTileCueIcon] {
        let hasCustomAnnouncer = appModel.hasStoredCustomAnnouncer(for: player)
        let hasSong = appModel.resolvedCue(for: player) != nil
        let availableColor = Color.rollCall(.ready, surface: .live)
        let missingColor = Color.rollCall(.destructive, surface: .live)

        switch announcerMode {
        case .announcerOnly:
            return [
                GameDayTileCueIcon(
                    id: "announcer",
                    systemImage: hasCustomAnnouncer ? "microphone.fill" : "microphone.slash.fill",
                    color: hasCustomAnnouncer ? availableColor : missingColor
                )
            ]
        case .announcerAndSong:
            return [
                GameDayTileCueIcon(
                    id: "announcer",
                    systemImage: hasCustomAnnouncer ? "microphone.fill" : "microphone.slash.fill",
                    color: hasCustomAnnouncer ? availableColor : missingColor
                ),
                GameDayTileCueIcon(
                    id: "song",
                    systemImage: hasSong ? "music.note" : "music.note.slash",
                    color: hasSong ? availableColor : missingColor
                )
            ]
        case .songOnly:
            return [
                GameDayTileCueIcon(
                    id: "song",
                    systemImage: hasSong ? "music.note" : "music.note.slash",
                    color: hasSong ? availableColor : missingColor
                )
            ]
        }
    }

    private var onDeckBackgroundColor: Color {
        if isLineupProgressFocused {
            return teamAccentTheme.color(.primary, surface: .live).opacity(0.18)
        }
        return Color.rollCall(.neutralSurface, surface: .live)
    }

    private var onDeckBorderColor: Color {
        if isLineupProgressFocused {
            return teamAccentTheme.color(.primary, surface: .live).opacity(0.95)
        }
        return liveAccentOutlineColor(theme: teamAccentTheme, colorScheme: colorScheme, lightOpacity: 0.8, darkOpacity: 0.4)
    }

    @ViewBuilder
    private func onDeckCueIconRow(for player: Player) -> some View {
        HStack(spacing: 6) {
            ForEach(onDeckCueIcons(for: player)) { icon in
                Image(systemName: icon.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(icon.color)
            }
        }
    }
}

private struct GameDayAnnouncerModePicker: View {
    let selectedMode: GameDayAnnouncerMode
    let onSelect: (GameDayAnnouncerMode) -> Void

    var body: some View {
        Picker("Announcer Mode", selection: Binding(
            get: { selectedMode },
            set: { mode in onSelect(mode) }
        )) {
            ForEach(GameDayAnnouncerMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct GameDayControlRow: View {
    @ObservedObject var appModel: AppModel
    let onLineup: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                appModel.goToPreviousBatter()
            } label: {
                Label("Prev", systemImage: "chevron.left")
            }
            .rollCallButtonStyle(.secondary, surface: .live)

            Button {
                onLineup()
            } label: {
                Label("Edit Lineup", systemImage: "list.number")
            }
            .rollCallButtonStyle(.secondary, surface: .live)

            Button {
                appModel.advanceNextBatter()
            } label: {
                HStack(spacing: 5) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
            }
            .rollCallButtonStyle(.secondary, surface: .live)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct GameDayGridDivider: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    var body: some View {
        Rectangle()
            .fill(liveAccentOutlineColor(theme: teamAccentTheme, colorScheme: colorScheme, lightOpacity: 0.75, darkOpacity: 0.34))
            .frame(height: 1)
            .padding(.vertical, 4)
    }
}

private struct GameDayEmptyHero: View {
    let title: String
    let detail: String

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Now Batting")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Text(title)
                .font(.title.bold())
                .foregroundStyle(Color(uiColor: .label))
            Text(detail)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.rollCall(.neutralSurface, surface: .live), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(liveAccentOutlineColor(theme: teamAccentTheme, colorScheme: colorScheme, lightOpacity: 0.8, darkOpacity: 0.4), lineWidth: 1)
        )
    }
}

private struct GameDayStatePill: View {
    let text: String
    let systemImage: String
    let role: StatusChipRole
    let strong: Bool
    var animatesSymbol: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if animatesSymbol {
                PlayingSpeakerSymbol(systemImage: systemImage)
            } else {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption.weight(.bold))
        .lineLimit(1)
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(background, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(color.opacity(strong ? 0 : 0.45), lineWidth: 1)
        )
    }

    private var foreground: Color {
        strong ? .white : color
    }

    private var background: Color {
        strong ? color : color.opacity(0.16)
    }

    private var color: Color {
        switch role {
        case .live:
            return Color.rollCall(.live, surface: .live)
        case .ready:
            return Color.rollCall(.ready, surface: .live)
        case .warning:
            return Color.rollCall(.warning, surface: .live)
        case .destructive:
            return Color.rollCall(.destructive, surface: .live)
        case .disabled:
            return Color.rollCall(.disabled, surface: .live)
        case .neutral:
            return Color(uiColor: .secondaryLabel)
        }
    }
}

private struct GameDayPlayerGrid: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var playbackEngine: CuePlaybackEngine
    let teamID: UUID
    let players: [Player]
    let nowPlayerID: UUID?
    let onDeckPlayerID: UUID?
    let announcerMode: GameDayAnnouncerMode
    let lineupProgressFocusedPlayerID: UUID?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    init(
        appModel: AppModel,
        teamID: UUID,
        players: [Player],
        nowPlayerID: UUID?,
        onDeckPlayerID: UUID?,
        announcerMode: GameDayAnnouncerMode,
        lineupProgressFocusedPlayerID: UUID?
    ) {
        self.appModel = appModel
        self.teamID = teamID
        self.players = players
        self.nowPlayerID = nowPlayerID
        self.onDeckPlayerID = onDeckPlayerID
        self.announcerMode = announcerMode
        self.lineupProgressFocusedPlayerID = lineupProgressFocusedPlayerID
        _playbackEngine = ObservedObject(initialValue: appModel.playbackEngine)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(players) { player in
                let isActive = isActive(player)
                let tileState = tileState(for: player, isActive: isActive)
                let cueIcons = tileCueIcons(for: player)
                let isLineupProgressFocused = lineupProgressFocusedPlayerID == player.id
                Button {
                    if isCurrentlyActive(player) {
                        appModel.stopPlayback()
                    } else {
                        Task { await appModel.play(player: player, teamID: teamID) }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .center, spacing: 4) {
                            Text(player.uniformNumber.isEmpty ? "--" : "#\(player.uniformNumber)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                            Spacer(minLength: 0)
                            tileIconRow(tileState: tileState, cueIcons: cueIcons)
                        }

                        Text(tileName(for: player))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color(uiColor: .label))
                            .lineLimit(2)
                            .minimumScaleFactor(0.74)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let tileState, tileState.animatesSymbol {
                            Text(tileState.text)
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(tileState.color)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(tileBackground(isActive: isActive, isLineupProgressFocused: isLineupProgressFocused))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(tileBorder(isActive: isActive, isLineupProgressFocused: isLineupProgressFocused), lineWidth: tileBorderWidth(isActive: isActive, isLineupProgressFocused: isLineupProgressFocused))
                    )
                }
                .buttonStyle(.plain)
                .shadow(color: tileShadowColor(isActive: isActive, isLineupProgressFocused: isLineupProgressFocused), radius: isLineupProgressFocused ? 8 : 0, y: isLineupProgressFocused ? 4 : 0)
                .animation(.easeInOut(duration: 0.16), value: isActive)
                .animation(.easeInOut(duration: 0.18), value: isLineupProgressFocused)
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(tileAccessibilityLabel(for: player, tileState: tileState))
                .accessibilityValue(tileAccessibilityValue(for: player, isActive: isActive))
                .accessibilityHint(tileAccessibilityHint(for: player, isActive: isActive))
            }
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    }

    private func isActive(_ player: Player) -> Bool {
        if let cueID = appModel.resolvedCue(for: player)?.id {
            return playbackEngine.activeCueID == cueID
        }
        return playbackEngine.activeCueID == player.id
    }

    private func isCurrentlyActive(_ player: Player) -> Bool {
        if let cueID = appModel.resolvedCue(for: player)?.id {
            return appModel.playbackEngine.activeCueID == cueID
        }
        return appModel.playbackEngine.activeCueID == player.id
    }

    private func tileName(for player: Player) -> String {
        let parts = normalizedPlayerNameParts(player.displayName)
        let first = parts.first.isEmpty ? player.displayName : parts.first
        let duplicateFirstNames = players.filter {
            normalizedPlayerNameParts($0.displayName).first.localizedCaseInsensitiveCompare(first) == .orderedSame
        }.count > 1

        if duplicateFirstNames, !parts.remainder.isEmpty {
            return player.displayName
        }
        return first
    }

    private func tileState(for player: Player, isActive: Bool) -> GameDayTileState? {
        if isActive {
            return GameDayTileState(text: "Playing", systemImage: "speaker.wave.3.fill", color: Color.rollCall(.live, surface: .live), animatesSymbol: true)
        }
        if player.id == onDeckPlayerID {
            return GameDayTileState(text: "On Deck", systemImage: "person.crop.circle.badge.clock", color: teamAccentTheme.color(.primary, surface: .live))
        }
        if player.id == nowPlayerID {
            return GameDayTileState(text: "Now Batting", systemImage: "figure.baseball", color: Color.rollCall(.ready, surface: .live))
        }
        return nil
    }

    private func tileCueIcons(for player: Player) -> [GameDayTileCueIcon] {
        let hasAnnouncer = appModel.hasStoredCustomAnnouncer(for: player)
        let hasSong = appModel.resolvedCue(for: player) != nil && !willUseFallback(for: player)
        let availableColor = Color(uiColor: .secondaryLabel)
        let missingColor = Color(uiColor: .tertiaryLabel)

        switch announcerMode {
        case .announcerOnly:
            return [
                GameDayTileCueIcon(
                    id: "announcer",
                    systemImage: hasAnnouncer ? "microphone.fill" : "microphone.slash.fill",
                    color: hasAnnouncer ? availableColor : missingColor
                )
            ]
        case .announcerAndSong:
            return [
                GameDayTileCueIcon(
                    id: "announcer",
                    systemImage: hasAnnouncer ? "microphone.fill" : "microphone.slash.fill",
                    color: hasAnnouncer ? availableColor : missingColor
                ),
                GameDayTileCueIcon(
                    id: "song",
                    systemImage: hasSong ? "music.note" : "music.note.slash",
                    color: hasSong ? availableColor : missingColor
                )
            ]
        case .songOnly:
            return [
                GameDayTileCueIcon(
                    id: "song",
                    systemImage: hasSong ? "music.note" : "music.note.slash",
                    color: hasSong ? availableColor : missingColor
                )
            ]
        }
    }

    @ViewBuilder
    private func tileIconRow(tileState: GameDayTileState?, cueIcons: [GameDayTileCueIcon]) -> some View {
        HStack(spacing: 4) {
            if let tileState {
                if tileState.animatesSymbol {
                    PlayingSpeakerSymbol(systemImage: tileState.systemImage, color: tileState.color)
                        .font(.caption.weight(.bold))
                } else {
                    Image(systemName: tileState.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tileState.color)
                }
            }

            ForEach(cueIcons) { icon in
                Image(systemName: icon.systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(icon.color)
            }
        }
    }

    private func willUseFallback(for player: Player) -> Bool {
        switch announcerMode {
        case .announcerOnly:
            return !appModel.hasStoredCustomAnnouncer(for: player)
        case .announcerAndSong, .songOnly:
            return appModel.playerWillUseFallback(for: player) || appModel.isPlayingFallback(for: player)
        }
    }

    private func tileAccessibilityLabel(for player: Player, tileState: GameDayTileState?) -> String {
        var parts: [String] = []
        if !player.uniformNumber.isEmpty {
            parts.append("Number \(player.uniformNumber)")
        }
        parts.append(player.displayName)
        if let tileState {
            parts.append(tileState.text)
        }
        return parts.joined(separator: ", ")
    }

    private func tileAccessibilityValue(for player: Player, isActive: Bool) -> String {
        if isActive {
            return "Currently playing"
        }
        if willUseFallback(for: player) {
            return "Will play fallback clip"
        }

        switch announcerMode {
        case .announcerOnly:
            return "Will play announcement cue"
        case .announcerAndSong:
            return appModel.hasStoredCustomAnnouncer(for: player) ? "Will play announcement cue and song" : "Will play song"
        case .songOnly:
            return "Will play song"
        }
    }

    private func tileAccessibilityHint(for player: Player, isActive: Bool) -> String {
        if isActive {
            return "Stops the active cue."
        }
        if willUseFallback(for: player) {
            return "Plays the default fallback crowd clip."
        }
        return "Plays this player's cue."
    }

    private func tileBackground(isActive: Bool, isLineupProgressFocused: Bool) -> Color {
        if isActive {
            return Color.rollCall(.live, surface: .live).opacity(0.22)
        }
        if isLineupProgressFocused {
            return teamAccentTheme.color(.primary, surface: .live).opacity(colorScheme == .dark ? 0.20 : 0.14)
        }
        return Color.rollCall(.neutralSurface, surface: .live)
    }

    private func tileBorder(isActive: Bool, isLineupProgressFocused: Bool) -> Color {
        if isActive {
            return Color.rollCall(.live, surface: .live).opacity(0.95)
        }
        if isLineupProgressFocused {
            return teamAccentTheme.color(.primary, surface: .live).opacity(0.95)
        }
        return liveAccentOutlineColor(theme: teamAccentTheme, colorScheme: colorScheme, lightOpacity: 0.8, darkOpacity: 0.4)
    }

    private func tileBorderWidth(isActive: Bool, isLineupProgressFocused: Bool) -> CGFloat {
        if isActive {
            return 2
        }
        return isLineupProgressFocused ? 1.75 : 1
    }

    private func tileShadowColor(isActive: Bool, isLineupProgressFocused: Bool) -> Color {
        if isActive {
            return Color.rollCall(.live, surface: .live).opacity(0.20)
        }
        if isLineupProgressFocused {
            return teamAccentTheme.color(.primary, surface: .live).opacity(0.16)
        }
        return .clear
    }
}

private struct GameDayTileState {
    let text: String
    let systemImage: String
    let color: Color
    var animatesSymbol: Bool = false
}

private struct GameDayTileCueIcon: Identifiable {
    let id: String
    let systemImage: String
    let color: Color
}

private struct GameDayPanelIconRow: View {
    let tileState: GameDayTileState?
    let cueIcons: [GameDayTileCueIcon]

    private let reservedWidth: CGFloat = 52

    var body: some View {
        HStack(spacing: 4) {
            if let tileState {
                if tileState.animatesSymbol {
                    PlayingSpeakerSymbol(systemImage: tileState.systemImage, color: tileState.color)
                        .font(.caption.weight(.bold))
                } else {
                    Image(systemName: tileState.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tileState.color)
                }
            }

            ForEach(cueIcons) { icon in
                Image(systemName: icon.systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(icon.color)
            }
        }
        .frame(width: reservedWidth, alignment: .trailing)
    }
}

private struct LineupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let isLiveUse: Bool
    @State private var editMode: EditMode = .active

    var body: some View {
        NavigationStack {
            List {
                if let team = appModel.selectedTeam {
                    Section {
                        Text("Turn off players who are not here today, then drag players into batting order. Game Day uses this lineup, so these changes will be reflected when you start the walkups.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Lineup") {
                        HStack(spacing: 12) {
                            Button("Sort A-Z") {
                                appModel.sortBattingOrderAlphabetically(recordLiveActivity: isLiveUse)
                            }
                            .buttonStyle(.bordered)

                            Button("Sort by Number") {
                                appModel.sortBattingOrderByNumber(recordLiveActivity: isLiveUse)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)

                        ForEach(team.battingOrderPlayers) { player in
                            HStack {
                                PlayerPhotoThumbnail(relativePath: player.photoRelativePath, size: 40, cornerRadius: 12)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player.displayName)
                                    if !player.uniformNumber.isEmpty {
                                        Text("#\(player.uniformNumber)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { player.isPresent },
                                    set: { appModel.setPresent(player, isPresent: $0, recordLiveActivity: isLiveUse) }
                                ))
                                .labelsHidden()
                            }
                        }
                        .onMove { offsets, offset in
                            appModel.moveBattingOrder(from: offsets, to: offset, recordLiveActivity: isLiveUse)
                        }
                    }

                    Section("Status") {
                        Text("Manual order is preserved across launches until you sort or move the lineup again.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accentWashListBackground(surface: .live)
            .navigationTitle("Today’s Lineup")
            .environment(\.editMode, $editMode)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct RecoveryCenterView: View {
    @ObservedObject var appModel: AppModel
    @State private var backupPendingRestore: SnapshotRecord?
    @State private var recentlyDeletedPendingPermanentDelete: RecentlyDeletedItem?
    @State private var pendingPartialRestorePrompt: PartialRestorePrompt?

    var body: some View {
        List {
            Section("Recently Deleted") {
                Text("Deleted teams, players, and Custom Clips stay here for 60 days unless you restore or permanently delete them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if appModel.state.recentlyDeleted.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No recently deleted teams, players, or Custom Clips.")
                        Text("If you remove something by mistake, you can restore it here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(appModel.state.recentlyDeleted) { item in
                        recentlyDeletedRow(for: item)
                    }
                }
            }

            Section("Backups") {
                Text("Backups restore an earlier app state. They are separate from Recently Deleted and are best for larger recovery steps.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Create Backup") {
                    appModel.createBackup(reason: "Manual backup")
                }
                .rollCallButtonStyle(.secondary)
            }

            Section("Available Backups") {
                if appModel.state.snapshots.isEmpty {
                    Text("No backups yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appModel.state.snapshots) { snapshot in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(snapshot.reason)
                                .font(.headline)
                            Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Restore Backup") {
                                backupPendingRestore = snapshot
                            }
                            .rollCallButtonStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .accentWashListBackground()
        .navigationTitle("Recovery")
        .onAppear {
            appModel.refreshRecoveryState()
        }
        .alert(item: $backupPendingRestore) { snapshot in
            Alert(
                title: Text("Restore Backup?"),
                message: Text("This will replace your current teams, players, and clips with the selected backup while keeping your current settings. Roll Call will save a safety backup first."),
                primaryButton: .cancel(),
                secondaryButton: .destructive(Text("Restore Backup")) {
                    Task { await appModel.restoreBackup(snapshot) }
                }
            )
        }
        .alert(item: $recentlyDeletedPendingPermanentDelete) { item in
            Alert(
                title: Text("Delete Permanently?"),
                message: Text(permanentDeleteMessage(for: item)),
                primaryButton: .cancel(),
                secondaryButton: .destructive(Text("Delete Permanently")) {
                    appModel.permanentlyDeleteRecentlyDeletedItem(item)
                }
            )
        }
        .alert(item: $pendingPartialRestorePrompt) { prompt in
            Alert(
                title: Text(prompt.title),
                message: Text(prompt.message),
                primaryButton: .cancel(),
                secondaryButton: .default(Text("Restore What We Can")) {
                    guard let item = appModel.state.recentlyDeleted.first(where: { $0.id == prompt.itemID }) else { return }
                    appModel.restoreRecentlyDeletedItem(item, allowPartial: true)
                }
            )
        }
    }

    @ViewBuilder
    private func recentlyDeletedRow(for item: RecentlyDeletedItem) -> some View {
        let restorePreparation = appModel.restorePreparation(for: item)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        StatusChip(
                            text: recoveryItemTypeLabel(for: item),
                            role: .neutral,
                            emphasis: .subdued
                        )

                        Text(recoveryItemTitle(for: item))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }

                    if let subtitle = recoverySubtitle(for: item) {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(recoveryMetadataText(for: item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if canRestore(restorePreparation) {
                    if case .player(let deletedPlayer) = item.payload, !deletedPlayer.player.isPresent {
                        Menu("Restore") {
                            Button("Restore as Absent") {
                                handleRestore(item)
                            }
                            Button("Restore and Mark Present") {
                                handleRestore(item, markPlayerPresent: true)
                            }
                        }
                        .rollCallButtonStyle(.primary)
                    } else {
                        Button("Restore") {
                            handleRestore(item)
                        }
                        .rollCallButtonStyle(.primary)
                    }
                }
            }

            if case .blocked(let message) = restorePreparation {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Delete Permanently", role: .destructive) {
                recentlyDeletedPendingPermanentDelete = item
            }
        }
    }

    private func handleRestore(_ item: RecentlyDeletedItem, markPlayerPresent: Bool = false) {
        switch appModel.restorePreparation(for: item) {
        case .ready:
            appModel.restoreRecentlyDeletedItem(item, markRestoredPlayerPresent: markPlayerPresent)
        case .blocked(let message):
            appModel.lastError = message
        case .partialPrompt(let prompt):
            pendingPartialRestorePrompt = prompt
        }
    }

    private func recoveryItemTypeLabel(for item: RecentlyDeletedItem) -> String {
        switch item.payload {
        case .team:
            return "Team"
        case .player:
            return "Player"
        case .customClip:
            return "Custom Clip"
        }
    }

    private func recoveryItemTitle(for item: RecentlyDeletedItem) -> String {
        switch item.payload {
        case .team(let deletedTeam):
            return deletedTeam.team.name
        case .player(let deletedPlayer):
            return deletedPlayer.player.displayName
        case .customClip(let deletedClip):
            return deletedClip.clip.displayName ?? deletedClip.clip.playbackCue.rosterDisplayTitle
        }
    }

    private func recoverySubtitle(for item: RecentlyDeletedItem) -> String? {
        switch item.payload {
        case .team:
            return nil
        case .player(let deletedPlayer):
            return appModel.recoveryTeamName(for: deletedPlayer)
        case .customClip(let deletedClip):
            return appModel.recoveryTeamName(for: deletedClip)
        }
    }

    private func recoveryMetadataText(for item: RecentlyDeletedItem) -> String {
        "Deleted \(item.deletedAt.formatted(date: .abbreviated, time: .omitted)) • \(recoveryRetentionText(for: item))"
    }

    private func canRestore(_ preparation: RestorePreparation) -> Bool {
        switch preparation {
        case .ready, .partialPrompt:
            return true
        case .blocked:
            return false
        }
    }

    private func recoveryRetentionText(for item: RecentlyDeletedItem) -> String {
        let daysRemaining = max(Calendar.current.dateComponents([.day], from: .now, to: item.expiresAt).day ?? 0, 0)
        if daysRemaining == 0 {
            return "Expires today"
        }
        if daysRemaining == 1 {
            return "1 day left"
        }
        return "\(daysRemaining) days left"
    }

    private func permanentDeleteMessage(for item: RecentlyDeletedItem) -> String {
        switch item.payload {
        case .team(let deletedTeam):
            return "Delete \(deletedTeam.team.name) permanently? You will not be able to restore it from Recently Deleted."
        case .player(let deletedPlayer):
            return "Delete \(deletedPlayer.player.displayName) permanently? You will not be able to restore them from Recently Deleted."
        case .customClip(let deletedClip):
            let name = deletedClip.clip.displayName ?? deletedClip.clip.playbackCue.rosterDisplayTitle
            return "Delete \(name) permanently? You will not be able to restore this Custom Clip from Recently Deleted."
        }
    }
}

private struct DeveloperToolsView: View {
    @ObservedObject var appModel: AppModel
    let ratingRequestStatus: String
    let onTestAutomaticRatingPrompt: () -> Void
    let onShowRatingRequestSheet: () -> Void
    let onEmailSupport: () -> Void
    let onOpenReviewPage: () -> Void
    @State private var showGeneratedClipCleanupConfirmation = false
    @State private var showDuplicatePlayerSongsConfirmation = false
    @State private var duplicatePlayerSongsResultText: String?
    @State private var isInspectingGeneratedClips = false
    @State private var generatedClipLastInspectedAt: Date?

    private var flags: FeatureFlags {
        appModel.featureFlags
    }

    var body: some View {
        Group {
            if flags.isReleaseBuild {
                ContentUnavailableView(
                    "Developer Tools Unavailable",
                    systemImage: "lock.fill",
                    description: Text("Release builds do not expose developer settings or experimental features.")
                )
            } else {
                List {
                    Section("Build Environment") {
                        LabeledContent("Environment", value: flags.environment.rawValue)
                        LabeledContent("App Version", value: "\(AppMetadata.appVersion) (\(AppMetadata.buildNumber))")
                        LabeledContent("What's New Seen", value: appModel.state.lastSeenWhatsNewReleaseID ?? "Not seen")
                    }

                    Section("Environment Gates") {
                        FlagStatusRow(
                            title: "Developer Settings",
                            detail: "Shows this internal settings surface outside production releases.",
                            isEnabled: flags.showDeveloperSettings
                        )
                        FlagStatusRow(
                            title: "Experimental Features",
                            detail: "Allows unfinished or provisional tools to appear for trusted testing.",
                            isEnabled: flags.showExperimentalFeatures
                        )
                    }

                    Section("Runtime Testing Flags") {
                        Toggle(isOn: Binding(
                            get: { appModel.state.experimental.showExperimentalFeatures },
                            set: { appModel.setShowExperimentalFeatures($0) }
                        )) {
                            SettingsRowLabel(
                                title: "Show Experimental Features",
                                detail: flags.isDebugBuild ? "Debug builds force experimental visibility on; this stored value mainly affects Internal builds." : "Internal builds only show experiments when this is enabled.",
                                systemImage: "testtube.2"
                            )
                        }
                        .disabled(flags.isDebugBuild)
                    }

                    Section("Diagnostics") {
                        Button("Reset What's New Prompt") {
                            appModel.resetWhatsNewSeenForTesting()
                        }

                        LabeledContent("Rating Request", value: appModel.ratingRequestDebugSummary)
                        LabeledContent("Probable-Game Dates", value: "\(appModel.telemetry.ratingSnapshot.probableGameDateCount)")
                        LabeledContent("Rating Prompt Status", value: ratingRequestStatus)

                        Button(appModel.hasEarnedRatingRequest ? "Mark Rating Threshold Not Met" : "Mark Rating Threshold Met") {
                            appModel.setRatingThresholdMetForTesting(!appModel.hasEarnedRatingRequest)
                        }

                        Button("Test In-App Rating Prompt") {
                            onTestAutomaticRatingPrompt()
                        }

                        Button("Show Real Rating Request Sheet") {
                            onShowRatingRequestSheet()
                        }

                        Button("Open App Store Review Page") {
                            onOpenReviewPage()
                        }

                        Button("Generate Support Bundle") {
                            Task { await appModel.exportSupportBundle() }
                        }
                        if let supportBundle = appModel.supportBundle {
                            ShareLink(item: supportBundle.url) {
                                Label("Share Latest Support Bundle", systemImage: "square.and.arrow.up")
                            }
                        }
                        Text("Support bundles include app version, schema version, feature flags, aggregate readiness and song-clip counts, cleanup totals, boolean playback state, and redacted team counts. Team names, player names, IDs, filenames, song metadata, media, and other user-created content are excluded.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Custom Clip Utilities") {
                        Button("Duplicate Player Songs to Custom Clips") {
                            showDuplicatePlayerSongsConfirmation = true
                        }
                        .disabled(selectedTeamPlayerSongCount == 0)

                        if let duplicatePlayerSongsResultText {
                            Label(duplicatePlayerSongsResultText, systemImage: "checkmark.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Creates independent Custom Clip copies for Player Songs on the selected team. Players without songs are skipped.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Generated Clip Storage") {
                        Button("Inspect Generated Clips") {
                            inspectGeneratedClips()
                        }
                        .disabled(isInspectingGeneratedClips)

                        if isInspectingGeneratedClips {
                            HStack {
                                ProgressView()
                                Text("Inspecting generated clips...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let generatedClipLastInspectedAt {
                            Label(
                                "Last inspected \(generatedClipLastInspectedAt.formatted(date: .omitted, time: .shortened))",
                                systemImage: "clock"
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }

                        if let report = appModel.generatedClipCleanupReport {
                            LabeledContent("Stored Files", value: "\(report.discoveredFileCount)")
                            LabeledContent(
                                "Storage Used",
                                value: ByteCountFormatter.string(
                                    fromByteCount: report.discoveredByteCount,
                                    countStyle: .file
                                )
                            )
                            LabeledContent("Safe to Remove", value: "\(report.orphanedFileCount)")

                            if let blockedReason = report.blockedReason {
                                Label(blockedReason, systemImage: "lock.shield")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else if report.orphanedFileCount == 0 {
                                Label("No unreferenced generated clips found.", systemImage: "checkmark.circle")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                Button(
                                    "Remove \(report.orphanedFileCount) Unreferenced \(report.orphanedFileCount == 1 ? "Clip" : "Clips")",
                                    role: .destructive
                                ) {
                                    showGeneratedClipCleanupConfirmation = true
                                }
                            }

                            if report.removedFileCount > 0 {
                                Text("Removed \(report.removedFileCount) files and recovered \(ByteCountFormatter.string(fromByteCount: report.removedByteCount, countStyle: .file)).")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("Cleanup only examines Roll Call's GeneratedClips folder. Files referenced by teams, Custom Clips, Recently Deleted, preparation work, or readable backups are retained. If anything is uncertain, cleanup stops without deleting files.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .accentWashListBackground()
            }
        }
        .accentWashBackground()
        .navigationTitle("Developer Tools")
        .confirmationDialog(
            "Duplicate Player Songs to Custom Clips?",
            isPresented: $showDuplicatePlayerSongsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Duplicate \(selectedTeamPlayerSongCount) \(selectedTeamPlayerSongCount == 1 ? "Clip" : "Clips")") {
                duplicatePlayerSongsToCustomClips()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Roll Call will create independent Custom Clip copies for Player Songs on the selected team. Existing Player Songs will not be changed.")
        }
        .confirmationDialog(
            "Remove Unreferenced Generated Clips?",
            isPresented: $showGeneratedClipCleanupConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Files", role: .destructive) {
                Task { await appModel.cleanGeneratedClipsNow() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let report = appModel.generatedClipCleanupReport {
                Text("Roll Call will remove \(report.orphanedFileCount) files using \(ByteCountFormatter.string(fromByteCount: report.orphanedByteCount, countStyle: .file)). This cannot be undone.")
            }
        }
    }

    private var selectedTeamPlayerSongCount: Int {
        guard let team = appModel.selectedTeam else { return 0 }
        return team.players.filter { team.songClip(for: $0) != nil }.count
    }

    private func duplicatePlayerSongsToCustomClips() {
        let result = appModel.duplicateSelectedTeamPlayerSongsToCustomClips()
        if result.copiedCount == 0 {
            duplicatePlayerSongsResultText = result.skippedCount == 0
                ? "No selected team found."
                : "No Player Songs found to duplicate."
        } else if result.skippedCount == 0 {
            duplicatePlayerSongsResultText = "Created \(result.copiedCount) Custom \(result.copiedCount == 1 ? "Clip" : "Clips")."
        } else {
            duplicatePlayerSongsResultText = "Created \(result.copiedCount) Custom \(result.copiedCount == 1 ? "Clip" : "Clips"); skipped \(result.skippedCount) \(result.skippedCount == 1 ? "player" : "players") without songs."
        }
    }

    private func inspectGeneratedClips() {
        guard !isInspectingGeneratedClips else { return }
        isInspectingGeneratedClips = true
        Task { @MainActor in
            await appModel.refreshGeneratedClipCleanupReport()
            generatedClipLastInspectedAt = .now
            isInspectingGeneratedClips = false
        }
    }
}

private struct SupportRollCallScreen: View {
    let onManageSubscriptions: () -> Void

    @StateObject private var supportStore = StoreKitSupportStore()
    @State private var selectedKind: SupportContributionKind = .oneTime

    private var visibleOptions: [SupportProductOption] {
        switch selectedKind {
        case .oneTime:
            return supportStore.oneTimeOptions
        case .recurring:
            return supportStore.recurringOptions
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RollCallSpacingTier.large.value) {
                SettingsSectionGroup(title: "Support Roll Call") {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                        Text("Roll Call is free, ad-free, and fully functional for every team.")
                            .rollCallText(.body)
                        Text("Optional support helps keep the app maintained, compatible with iOS updates, and improving over time.")
                            .rollCallText(.body)
                        Text("Support never unlocks Game Day features, teams, imports, exports, or reliability.")
                            .rollCallText(.helperText)
                    }
                }

                if supportStore.activeSubscriptionTitle != nil || supportStore.hasVerifiedSupport {
                    SettingsSectionGroup(title: "Thank You") {
                        VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                            if let activeSubscriptionTitle = supportStore.activeSubscriptionTitle {
                                SupportStatusRow(
                                    title: "\(activeSubscriptionTitle) Active",
                                    detail: "Thanks for helping maintain Roll Call for every team.",
                                    systemImage: "checkmark.seal.fill"
                                )
                            } else {
                                SupportStatusRow(
                                    title: "Thanks for supporting Roll Call",
                                    detail: "Your contribution is appreciated.",
                                    systemImage: "heart.fill"
                                )
                            }
                        }
                    }
                }

                Picker("Support Type", selection: $selectedKind) {
                    Text("One-Time").tag(SupportContributionKind.oneTime)
                    Text("Recurring").tag(SupportContributionKind.recurring)
                }
                .pickerStyle(.segmented)

                SettingsSectionGroup(title: selectedKind == .oneTime ? "One-Time Support" : "Recurring Support") {
                    VStack(alignment: .leading, spacing: RollCallSpacingTier.standard.value) {
                        if supportStore.isLoadingProducts {
                            ProgressView("Loading support options...")
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if visibleOptions.isEmpty {
                            Text(supportStore.productLoadMessage ?? "Support options are unavailable right now. Please try again later.")
                                .rollCallText(.helperText)
                            Button("Retry") {
                                Task { await supportStore.retryLoadingProducts() }
                            }
                            .buttonStyle(.bordered)
                        } else {
                            ForEach(visibleOptions) { option in
                                SupportProductButton(
                                    option: option,
                                    isPurchasing: supportStore.purchaseInProgressProductID == option.id,
                                    onPurchase: {
                                        Task { await supportStore.purchase(option) }
                                    }
                                )
                            }

                            if let productLoadMessage = supportStore.productLoadMessage {
                                Text(productLoadMessage)
                                    .rollCallText(.helperText)
                            }
                        }

                        if selectedKind == .recurring {
                            Text("Recurring support renews automatically until canceled in your Apple ID subscriptions. You can manage or cancel anytime. Support does not unlock features.")
                                .rollCallText(.helperText)

                            VStack(spacing: RollCallSpacingTier.tight.value) {
                                Button {
                                    Task { await supportStore.restoreSupportSubscription() }
                                } label: {
                                    SupportUtilityActionRow(
                                        title: "Restore Support",
                                        detail: "Check this Apple ID for an active subscription.",
                                        systemImage: "arrow.clockwise",
                                        isLoading: supportStore.isRestoring
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(supportStore.isRestoring)

                                Button {
                                    onManageSubscriptions()
                                } label: {
                                    SupportUtilityActionRow(
                                        title: "Manage Subscriptions",
                                        detail: "Open Apple ID subscription settings.",
                                        systemImage: "person.crop.circle.badge.checkmark",
                                        isLoading: false
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if let purchaseMessage = supportStore.purchaseMessage {
                    Text(purchaseMessage)
                        .rollCallText(.helperText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("One-time contributions can be made again any time. If Roll Call can see past support on this Apple ID, it will show a thank-you here.")
                    .rollCallText(.helperText)
            }
            .padding(.horizontal, 16)
            .padding(.top, RollCallSpacingTier.tight.value)
            .padding(.bottom, RollCallSpacingTier.large.value)
        }
        .accentWashBackground()
        .navigationTitle("Support Roll Call")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await supportStore.refreshOnAppear()
        }
    }
}

private struct SupportProductButton: View {
    let option: SupportProductOption
    let isPurchasing: Bool
    let onPurchase: () -> Void

    var body: some View {
        Button(action: onPurchase) {
            HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
                SettingsIcon(systemImage: option.definition.kind == .oneTime ? "heart.fill" : "arrow.clockwise.circle.fill", role: .accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.definition.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(uiColor: .label))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(option.definition.subtitle)
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(Color(uiColor: .secondaryLabel))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: RollCallSpacingTier.standard.value)

                if isPurchasing {
                    ProgressView()
                } else {
                    Text(option.priceText)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(uiColor: .label))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }
}

private extension SupportProductOption {
    var priceText: String {
        if let priceSuffix = definition.priceSuffix {
            return "\(displayPrice)\(priceSuffix)"
        }
        return displayPrice
    }
}

private struct SupportUtilityActionRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let isLoading: Bool

    var body: some View {
        HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
            if isLoading {
                ProgressView()
                    .frame(width: 34, height: 34)
            } else {
                SettingsIcon(systemImage: systemImage, role: .accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(uiColor: .label))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: RollCallSpacingTier.standard.value)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

private struct SupportStatusRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
            SettingsIcon(systemImage: systemImage, role: .accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(uiColor: .label))
                Text(detail)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(Color(uiColor: .secondaryLabel))
            }
        }
    }
}

private struct RatingRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var didReportAppearance = false

    let onAppeared: () -> Void
    let onRate: () -> Void
    let onEmailSupport: () -> Void
    let onNotNow: () -> Void
    let onSupportDevelopment: () -> Void

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer(minLength: 12)

                    VStack(spacing: 18) {
                        Image(systemName: "star.bubble.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.yellow, Color.accentColor)

                        VStack(spacing: 8) {
                            Text("Enjoying Roll Call?")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color(uiColor: .label))
                                .multilineTextAlignment(.center)

                            Text("Roll Call is free to use. If it has helped your team, a quick App Store rating is a great way to say thanks.")
                                .font(.body)
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 10) {
                            ForEach(0..<5, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.title3)
                                    .foregroundStyle(.yellow)
                            }
                        }

                        VStack(spacing: 12) {
                            Button("Rate Roll Call") {
                                dismiss()
                                onRate()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                            Button("Email Me Instead") {
                                dismiss()
                                onEmailSupport()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)

                            Button("Not Now") {
                                onNotNow()
                                dismiss()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 360)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: cardShape)
                    .overlay(
                        cardShape
                            .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 18, y: 8)

                    VStack(spacing: 10) {
                        Text("If something isn't working right, email me and I'll take a look.")
                            .font(.footnote)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .multilineTextAlignment(.center)

                        Button {
                            dismiss()
                            onSupportDevelopment()
                        } label: {
                            Text("You can also contribute in Settings.")
                                .font(.footnote.weight(.semibold))
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: 360)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .navigationTitle("Rate Roll Call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard !didReportAppearance else { return }
                didReportAppearance = true
                onAppeared()
            }
        }
    }
}

private struct FlagStatusRow: View {
    let title: String
    let detail: String
    let isEnabled: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isEnabled ? .green : .secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct PlayerQuickAddView: View {
    private enum Field: Hashable {
        case name
        case number
    }

    @ObservedObject var appModel: AppModel
    @State private var name = ""
    @State private var number = ""
    @FocusState private var focusedField: Field?
    
    private var canAddPlayer: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        TextField("Player name", text: $name)
            .focused($focusedField, equals: .name)
            .submitLabel(.next)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled(true)
            .onSubmit {
                focusedField = .number
            }
        TextField("Number", text: $number)
            .focused($focusedField, equals: .number)
            .keyboardType(.numberPad)
            .submitLabel(.done)
        HStack {
            Button {
                focusedField = nil
            } label: {
                Label("Dismiss Keyboard", systemImage: "keyboard.chevron.compact.down")
            }
            .rollCallButtonStyle(.secondary)

            Spacer()

            Button {
                addPlayerAndReset()
            } label: {
                Label("Add Player", systemImage: "plus")
            }
            .rollCallButtonStyle(.primary)
            .disabled(!canAddPlayer)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button("Done") {
                    focusedField = nil
                }
                Spacer()
                Button("Add") {
                    addPlayerAndReset()
                }
                .disabled(!canAddPlayer)
            }
        }
    }

    private func addPlayerAndReset() {
        appModel.addPlayer(name: name, number: number)
        name = ""
        number = ""
        focusedField = .name
    }
}

private struct PlayersSectionHeader: View {
    let title: String
    let helperText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .rollCallText(.sectionTitle)
            Text(helperText)
                .rollCallText(.helperText)
                .textCase(nil)
        }
        .padding(.top, 2)
        .textCase(nil)
    }
}

private struct PlayerRosterRow: View {
    let player: Player
    let cue: Cue?
    let isPresent: Bool
    let hasCustomIntro: Bool
    let isCustomIntroMissing: Bool

    var body: some View {
        HStack(alignment: .center, spacing: RollCallSpacingTier.standard.value) {
            PlayerPhotoThumbnail(relativePath: player.photoRelativePath, size: 44, cornerRadius: 12)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: RollCallSpacingTier.tight.value) {
                    Text(player.displayName)
                        .rollCallText(.cardTitle)
                        .lineLimit(2)
                    if !player.uniformNumber.isEmpty {
                        Text("#\(player.uniformNumber)")
                            .rollCallText(.helperText)
                            .lineLimit(1)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    cueSummary

                    operationalSummary
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens player details.")
    }

    @ViewBuilder
    private var cueSummary: some View {
        if let cue {
            PlayerRosterMetadataLine(
                title: cue.rosterDisplayTitle,
                systemImage: "music.note",
                color: Color.rollCall(.ready),
                font: .footnote
            )
        } else {
            PlayerRosterMetadataLine(
                title: "Song not selected",
                systemImage: "music.note",
                color: Color.rollCall(.warning),
                font: .footnote
            )
        }
    }

    private var operationalSummary: some View {
        HStack(alignment: .center, spacing: RollCallSpacingTier.tight.value) {
            if !isPresent {
                PlayerRosterMetadataLine(
                    title: "Hidden from Game Day",
                    systemImage: "eye.slash",
                    color: Color(uiColor: .secondaryLabel),
                    font: .caption
                )
            }

            if isCustomIntroMissing {
                PlayerRosterMetadataLine(
                    title: "Announcer missing",
                    systemImage: "exclamationmark.triangle.fill",
                    color: Color.rollCall(.destructive),
                    font: .caption
                )
            } else if hasCustomIntro {
                PlayerRosterMetadataLine(
                    title: "Announcement recorded",
                    systemImage: "mic.fill",
                    color: Color.rollCall(.ready),
                    font: .caption
                )
            } else if !hasCustomIntro {
                PlayerRosterMetadataLine(
                    title: "Announcement not recorded",
                    systemImage: "mic.slash",
                    color: Color(uiColor: .tertiaryLabel),
                    font: .caption
                )
            }
        }
        .lineLimit(1)
    }
}

private struct PlayerRosterMetadataLine: View {
    let title: String
    let systemImage: String
    let color: Color
    let font: Font

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: RollCallSpacingTier.tight.value) {
            Image(systemName: systemImage)
                .font(font.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 22, alignment: .center)

            Text(title)
                .font(font)
                .fontWeight(.medium)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}

private struct PlayerEditorSheet: View {
    private enum PhotoFramingTarget: String, Identifiable {
        case profile
        case playerCard

        var id: String { rawValue }
    }

    private struct SongReadinessExplanation: Identifiable {
        let id: String
        let title: String
        let detail: String
        let role: StatusChipRole
        let systemImage: String
    }

    private enum Field: Hashable {
        case displayName
        case uniformNumber
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    @State var player: Player
    @State private var photoItem: PhotosPickerItem?
    @State private var isPreparingPhoto = false
    @State private var photoFramingTarget: PhotoFramingTarget?
    @State private var photoFramingImage: UIImage?
    @State private var playerCardPreviewPresented = false
    @State private var pendingPhotoDetectionResult: PlayerPhotoDetectionResult?
    @State private var didAdjustProfileFraming = false
    @State private var didAdjustCardFraming = false
    @State private var songPickerMode: SongPickerMode?
    @State private var showSongFileImporter = false
    @State private var pendingImportedSongURL: URL?
    @State private var songImportError: String?
    @State private var trimMode: TrimSuggestionMode = .suggestedHook
    @State private var showAdvancedTrim = false
    @State private var liveScrubTask: Task<Void, Never>?
    @State private var pendingClearAction: PendingClearAction?
    @State private var songReadinessExplanation: SongReadinessExplanation?
    @State private var showDiscardChangesConfirmation = false
    @State private var isStartTrimEditingEnabled = false
    @State private var showExistingClipPicker = false
    @State private var draftPhotoRelativePaths: Set<String> = []
    @State private var didCommitDraft = false
    @FocusState private var focusedField: Field?

    private let lengthOptions: [Double] = [6, 8, 10, 12, 15]

    var body: some View {
        let hasStoredCustomIntro = appModel.hasStoredCustomAnnouncer(for: player)
        let isCustomIntroMissing = player.customAnnouncerRelativePath != nil && !hasStoredCustomIntro

        NavigationStack {
            AnyView(Form {
                Section {
                    setupSummaryView
                        .rollCallCard(.status)
                }
                .playerEditorListRow()

                Section {
                    let photoRelativePath = player.photoRelativePath
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Display Name", text: $player.displayName)
                                    .rollCallText(.body)
                                    .focused($focusedField, equals: .displayName)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .uniformNumber
                                    }

                                Divider()

                                TextField("Uniform Number", text: $player.uniformNumber)
                                    .rollCallText(.body)
                                    .focused($focusedField, equals: .uniformNumber)
                                    .submitLabel(.done)
                            }

                            PhotosPicker(selection: $photoItem, matching: .images) {
                                PlayerEditorPhotoPickerLabel(photoRelativePath: photoRelativePath)
                            }
                            .disabled(isPreparingPhoto)
                        }

                        if isPreparingPhoto {
                            Label("Finding a good profile and Player Card framing…", systemImage: "viewfinder")
                                .rollCallText(.helperText)
                        } else if photoRelativePath != nil {
                            Button {
                                presentPhotoFraming(.profile)
                            } label: {
                                Label("Adjust Profile Photo", systemImage: "crop")
                            }
                            .rollCallButtonStyle(.secondary)
                            .accessibilityHint("Changes the compact photo used throughout Roll Call.")
                        }
                    }
                    .rollCallCard(.identity)
                } header: {
                    PlayerEditorSectionHeader("Identity")
                }
                .playerEditorListRow()

                Section {
                    Button {
                        appModel.telemetry.record(.playerCardOpened)
                        playerCardPreviewPresented = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(appModel.selectedTeam?.accentPreset.color() ?? Color.rollCall(.accent))
                                .frame(width: 42, height: 52)
                                .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Player Card")
                                    .rollCallText(.cardTitle)
                                Text("Create a shareable walk-up card")
                                    .rollCallText(.helperText)
                            }
                            Spacer()
                            Text("Preview & Share")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(appModel.selectedTeam?.accentPreset.color() ?? Color.rollCall(.accent))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens a full preview before sharing.")
                    .rollCallCard(.utility)
                }
                .playerEditorListRow()

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        if let cue = effectiveCue {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 10) {
                                    PlayerEditorSectionIcon(systemImage: "music.note", role: .accent)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Selected Cue")
                                            .rollCallText(.cardTitle)
                                        selectedCueSummary(for: cue)
                                    }
                                }

                                Button {
                                    songPickerMode = .musicLibrary
                                } label: {
                                    Label("Choose from Music Library", systemImage: "music.note.list")
                                }
                                .rollCallButtonStyle(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 10) {
                                    PlayerEditorSectionIcon(systemImage: "music.note", role: .accent)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("No Song Cue")
                                            .rollCallText(.cardTitle)
                                        Text("Choose the song this player uses in Game Day.")
                                            .rollCallText(.helperText)
                                    }
                                }

                                Button {
                                    songPickerMode = .musicLibrary
                                } label: {
                                    Label("Choose from Music Library", systemImage: "music.note")
                                        .frame(maxWidth: .infinity)
                                }
                                .rollCallButtonStyle(.primary)
                            }
                        }

                        Button {
                            showExistingClipPicker = true
                        } label: {
                            Label("Use Existing Clip", systemImage: "doc.on.doc")
                        }
                        .rollCallButtonStyle(.secondary)
                        .disabled(existingClipSourceCount == 0)

                        Button {
                            songPickerMode = .appleMusic
                        } label: {
                            Label("Search Apple Music", systemImage: "magnifyingglass")
                        }
                        .rollCallButtonStyle(.secondary)

                        Button {
                            showSongFileImporter = true
                        } label: {
                            Label("Import Audio or Video", systemImage: "square.and.arrow.down")
                        }
                        .rollCallButtonStyle(.secondary)

                        Text("Choose or change the song, shape the clip, then save it before returning here.")
                            .rollCallText(.helperText)

                        if effectiveCue != nil {
                            Button {
                                pendingClearAction = .song
                            } label: {
                                Label("Clear Song", systemImage: "xmark.circle")
                            }
                            .rollCallButtonStyle(.quiet)
                            .foregroundStyle(Color.rollCall(.destructive))
                        }
                    }
                    .rollCallCard(.utility)
                } header: {
                    PlayerEditorSectionHeader("Song Cue")
                }
                .playerEditorListRow()

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 10) {
                            PlayerEditorSectionIcon(systemImage: "mic.fill", role: .live)
                            Text("Optional. Record a quick custom intro, like \"Now batting for the Niners, number 47, Kasidy Yates!\" In Game Day, it can play by itself in Announcer Only or before the player's song in Announcer+Song.")
                                .rollCallText(.helperText)
                        }

                        if isCustomIntroMissing {
                            Label("Roll Call still has an Announcement Cue reference for this player, but the audio file is missing from app storage.", systemImage: "exclamationmark.triangle.fill")
                                .rollCallText(.helperText)
                                .foregroundStyle(Color.rollCall(.destructive))
                        }

                        if appModel.isRecordingCustomAnnouncer(for: player) {
                            Button {
                                let currentPlayer = player
                                Task {
                                    await appModel.stopRecordingCustomAnnouncer(forPlayerID: currentPlayer.id)
                                    await MainActor.run { synchronizeCustomAnnouncerFromModel() }
                                }
                            } label: {
                                Label("Stop Recording", systemImage: "stop.circle.fill")
                            }
                            .rollCallButtonStyle(.destructive)
                        } else {
                            Button {
                                let currentPlayer = player
                                Task {
                                    await appModel.startRecordingCustomAnnouncer(forPlayerID: currentPlayer.id)
                                }
                            } label: {
                                Label(appModel.customAnnouncerButtonTitle(for: player), systemImage: "mic.fill")
                            }
                            .rollCallButtonStyle(.secondary)
                            .disabled(appModel.isCustomAnnouncerTransitioning(for: player))
                        }

                        if hasStoredCustomIntro {
                            Button {
                                appModel.previewCustomAnnouncer(for: player)
                            } label: {
                                Label("Preview Announcement Cue", systemImage: "play.fill")
                            }
                            .rollCallButtonStyle(.secondary)
                        }

                        if player.customAnnouncerRelativePath != nil {
                            Button {
                                pendingClearAction = .customAnnouncer
                            } label: {
                                Label("Clear Announcement Cue", systemImage: "xmark.circle")
                            }
                            .rollCallButtonStyle(.quiet)
                            .foregroundStyle(Color.rollCall(.destructive))
                        }

                        Text("Recording or clearing an Announcement Cue saves right away.")
                            .rollCallText(.helperText)
                    }
                    .rollCallCard(.utility)
                } header: {
                    PlayerEditorSectionHeader("Announcement Cue")
                }
                .playerEditorListRow()

                Section {
                    Button(role: .destructive) {
                        pendingClearAction = .player
                    } label: {
                        Label("Remove Player", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .rollCallButtonStyle(.quiet)
                    .foregroundStyle(Color.rollCall(.destructive))
                }
                .playerEditorListRow()
            })
            .disabled(isPreparingPhoto)
            .listStyle(.insetGrouped)
            .accentWashListBackground()
            .navigationTitle(player.displayName.isEmpty ? "Player" : player.displayName)
            .interactiveDismissDisabled(hasUnsavedChanges || isPreparingPhoto)
            .scrollDismissesKeyboard(.interactively)
            .dismissesKeyboardOnTap()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { closeEditor() }
                        .disabled(isPreparingPhoto)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveAndDismiss()
                    }
                    .disabled(isPreparingPhoto)
                }
            }
            .onChange(of: photoItem) { _, _ in
                Task { await importPhoto() }
            }
            .onAppear {
                normalizeTrimModeForCurrentCue()
            }
            .task {
                let draftAtRefreshStart = PlayerEditorDraftState(player: player)
                await appModel.refreshAppleMusicPlaybackCapability()
                if await appModel.refreshAppleMusicCueMetadata(for: player.id) {
                    await MainActor.run {
                        guard PlayerEditorDraftState(player: player) == draftAtRefreshStart else { return }
                        synchronizeSongAssignmentFromModel()
                    }
                }
            }
            .onDisappear {
                if appModel.isRecordingCustomAnnouncer(for: player) {
                    appModel.cancelRecordingCustomAnnouncer()
                }
                if !didCommitDraft {
                    discardDraftPhotoAssets()
                }
            }
            .alert("Are you sure?", isPresented: Binding(
                get: { pendingClearAction != nil },
                set: { if !$0 { pendingClearAction = nil } }
            ), presenting: pendingClearAction) { action in
                Button("Cancel", role: .cancel) {
                    pendingClearAction = nil
                }
                Button(action.confirmButtonTitle, role: .destructive) {
                    performClearAction(action)
                }
            } message: { action in
                Text(action.confirmationMessage)
            }
            .alert("Discard Changes?", isPresented: $showDiscardChangesConfirmation) {
                Button("Keep Editing", role: .cancel) { }
                Button("Discard Changes", role: .destructive) {
                    discardDraftAndDismiss()
                }
            } message: {
                Text("Closing now will lose unsaved name, number, photo, and any unsaved advanced trim edits. Song clips you saved in Make Your Clip and Announcement Cue changes are already saved.")
            }
            .fileImporter(
                isPresented: $showSongFileImporter,
                allowedContentTypes: [.audio, .movie],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    pendingImportedSongURL = url
                    songPickerMode = .files
                case .failure(let error):
                    guard !MusicCatalogService.isCancellation(error) else { return }
                    songImportError = error.localizedDescription
                }
            }
            .alert("Import Unavailable", isPresented: Binding(
                get: { songImportError != nil },
                set: { if !$0 { songImportError = nil } }
            )) {
                Button("OK") { }
            } message: {
                Text(songImportError ?? "")
            }
            .sheet(item: $songPickerMode, onDismiss: {
                songPickerMode = nil
                pendingImportedSongURL = nil
            }) { mode in
                SongPickerFlow(
                    appModel: appModel,
                    mode: mode,
                    importedURL: mode == .files ? pendingImportedSongURL : nil,
                    onSave: { cue in
                        appModel.saveSongCue(cue, to: player.id)
                        player.updatePrivateSongClip(with: cue)
                    }
                )
            }
            .sheet(isPresented: $showExistingClipPicker, onDismiss: {
                synchronizeSongAssignmentFromModel()
            }) {
                ExistingClipPickerSheet(appModel: appModel, destination: .player(player.id))
            }
            .sheet(isPresented: $showAdvancedTrim) {
                if editableCue != nil {
                    AdvancedTrimSheet(
                        cue: Binding(
                            get: { editableCue! },
                            set: { player.updatePrivateSongClip(with: $0) }
                        ),
                        cueTimeLimit: cueTimeLimit,
                        cueDurationLimit: cueDurationLimit
                    )
                    .presentationDetents([.medium])
                }
            }
            .sheet(isPresented: $playerCardPreviewPresented) {
                if let team = appModel.selectedTeam {
                    PlayerCardPreviewSheet(
                        player: $player,
                        team: team,
                        onGenerated: {
                            appModel.telemetry.record(.playerCardGenerated)
                        },
                        onGenerationFailed: { reason in
                            appModel.telemetry.record(.playerCardGenerationFailed, properties: [.reason: reason])
                        },
                        onSharePresented: {
                            appModel.telemetry.record(.playerCardShareInitiated)
                        },
                        onCardFramingAdjusted: {
                            didAdjustCardFraming = true
                        }
                    )
                }
            }
            .fullScreenCover(item: $photoFramingTarget) { target in
                if let photoFramingImage {
                    photoFramingEditor(for: target, image: photoFramingImage)
                }
            }
        }
    }

    private var cueTimeLimit: Double {
        guard let cue = editableCue else { return 30 }
        return appModel.cueTimelineLength(for: cue)
    }

    private var effectiveSongClip: SongClip? {
        appModel.resolvedSongClip(for: player)
    }

    private var effectiveCue: Cue? {
        effectiveSongClip?.playbackCue
    }

    private var editableCue: Cue? {
        player.songAssignment?.privateClip?.editingCue
    }

    private var existingClipSourceCount: Int {
        guard let team = appModel.selectedTeam else { return 0 }
        let otherPlayerSongs = team.players.filter { $0.id != player.id && team.songClip(for: $0) != nil }.count
        return otherPlayerSongs + team.teamClips.count
    }

    private var cueDurationLimit: Double {
        guard let cue = editableCue else { return 30 }
        return appModel.cueDurationLimit(for: cue)
    }

    private var setupSummary: (status: String, nextStep: String?, role: StatusChipRole, systemImage: String) {
        if effectiveCue == nil {
            return ("Song cue needed", "Next need: song cue", .warning, "music.note")
        }

        if player.customAnnouncerRelativePath != nil && !appModel.hasStoredCustomAnnouncer(for: player) {
            return ("Song cue set", "Next need: valid Announcement Cue", .warning, "exclamationmark.triangle")
        }

        if appModel.hasStoredCustomAnnouncer(for: player) {
            return ("Song and Announcement Cue set", nil, .ready, "checkmark.circle")
        }

        return ("Song cue set", nil, .ready, "checkmark.circle")
    }

    @ViewBuilder
    private var setupSummaryView: some View {
        let summary = setupSummary

        if summary.nextStep == nil {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Color.rollCall(.ready))
                    .accessibilityHidden(true)

                Text("Ready")
                    .rollCallText(.cardTitle)

                StatusChip(
                    text: summary.status,
                    role: summary.role,
                    systemImage: summary.systemImage,
                    emphasis: .subdued
                )

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        } else {
            HStack(alignment: .top, spacing: 10) {
                PlayerEditorSectionIcon(systemImage: "checklist", role: .ready)
                VStack(alignment: .leading, spacing: 7) {
                    Text("Setup Summary")
                        .rollCallText(.cardTitle)
                    StatusChip(
                        text: summary.status,
                        role: summary.role,
                        systemImage: summary.systemImage,
                        emphasis: .subdued
                    )
                    if let nextStep = summary.nextStep {
                        Text(nextStep)
                            .rollCallText(.helperText)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func selectedCueSummary(for cue: Cue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch cue.source {
            case .appleMusic(let source):
                Text(source.title)
                    .rollCallText(.body)
                Text(source.artistName)
                    .rollCallText(.helperText)
            case .localAudio(let source):
                Text(source.displayName.songTitleWithoutArtistPrefix)
                    .rollCallText(.body)
            case .builtInClip(let source):
                Text(source.displayName)
                    .rollCallText(.body)
            }
            cueSourceChip(for: cue)
            savedSongReadinessChip
        }
    }

    @ViewBuilder
    private var savedSongReadinessChip: some View {
        if let savedPlayer = appModel.selectedTeam?.players.first(where: { $0.id == player.id }),
           let clip = appModel.resolvedSongClip(for: savedPlayer) {
            let explanation = songReadinessExplanation(for: clip)
            Button {
                songReadinessExplanation = explanation
            } label: {
                StatusChip(
                    text: explanation.title,
                    role: explanation.role,
                    systemImage: explanation.systemImage,
                    emphasis: .subdued
                )
            }
            .buttonStyle(.plain)
            .help(explanation.detail)
            .accessibilityHint("Shows what this song readiness status means.")
            .popover(item: $songReadinessExplanation) { explanation in
                VStack(alignment: .leading, spacing: 10) {
                    Label(explanation.title, systemImage: explanation.systemImage)
                        .font(.headline)
                        .foregroundStyle(explanation.role == .destructive ? Color.rollCall(.destructive) : .primary)
                    Text(explanation.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(idealWidth: 300, alignment: .leading)
                .presentationCompactAdaptation(.popover)
            }
        }
    }

    private func songReadinessExplanation(for clip: SongClip) -> SongReadinessExplanation {
        if clip.generatedAsset.status == .pending {
            return SongReadinessExplanation(
                id: "preparing",
                title: "Preparing",
                detail: "Roll Call is checking this song and preparing the most reliable playback option it can. You can keep using the app while this finishes.",
                role: .neutral,
                systemImage: "clock"
            )
        }

        switch clip.readinessInputs.playback {
        case .localClipReady:
            return SongReadinessExplanation(
                id: "ready-any-device",
                title: "Ready on Any Device",
                detail: "Roll Call has its own local copy of this clip. It does not depend on Apple Music and can travel with the team when you export and import it on another device.",
                role: .ready,
                systemImage: "checkmark.circle"
            )
        case .sourceBackedReady:
            return SongReadinessExplanation(
                id: "ready-this-device",
                title: "Ready on This Device",
                detail: "This song can play on this iPhone from its original source, but Roll Call does not have a portable local copy. It may depend on Apple Music, connectivity, and the song remaining available here.",
                role: .ready,
                systemImage: "iphone"
            )
        case .sourceBackedDownloaded:
            return SongReadinessExplanation(
                id: "ready-this-device-downloaded",
                title: "Ready on This Device",
                detail: "This song is currently available on this iPhone, including its downloaded Music Library copy, but Roll Call does not own a portable clip to include with the team on another device.",
                role: .ready,
                systemImage: "iphone"
            )
        case .needsAppleMusic:
            return SongReadinessExplanation(
                id: "needs-apple-music",
                title: "Needs Apple Music",
                detail: "The song link is saved, but Roll Call cannot use it right now. Allow Music access and make sure the required Apple Music subscription and song availability are present on this device.",
                role: .warning,
                systemImage: "music.note"
            )
        case .needsRepair:
            return SongReadinessExplanation(
                id: "needs-repair",
                title: "Needs Repair",
                detail: "Roll Call cannot currently read or play this song source. Choose the song again or import a replacement before relying on it in Game Day.",
                role: .destructive,
                systemImage: "wrench.and.screwdriver"
            )
        }
    }

    private func cueSourceChip(for cue: Cue) -> StatusChip {
        switch cue.source {
        case .appleMusic:
            return StatusChip(text: "Apple Music", role: .neutral, systemImage: "music.note", emphasis: .subdued)
        case .localAudio:
            return StatusChip(text: "Imported audio", role: .neutral, systemImage: "folder", emphasis: .subdued)
        case .builtInClip:
            return StatusChip(text: "Built-in clip", role: .neutral, systemImage: "speaker.wave.2", emphasis: .subdued)
        }
    }

    private func importPhoto() async {
        guard let photoItem else { return }
        await MainActor.run { isPreparingPhoto = true }
        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self) else {
                throw PlayerPhotoPreparationError.unreadableImage
            }
            let prepared = try await PlayerPhotoPreparationService().prepare(data: data)
            try await MainActor.run {
                try savePreparedPlayerPhoto(prepared)
                pendingPhotoDetectionResult = prepared.detectionResult
                isPreparingPhoto = false
            }
        } catch {
            await MainActor.run {
                isPreparingPhoto = false
                appModel.lastError = error.localizedDescription
            }
        }
    }

    private func savePreparedPlayerPhoto(_ prepared: PreparedPlayerPhoto) throws {
        let assetsDir = try AppPaths.assetsDirectory()
        let masterName = "\(UUID().uuidString)-photo-master.jpg"
        let profileName = "\(UUID().uuidString)-photo-profile.jpg"
        do {
            try prepared.masterJPEG.write(to: assetsDir.appendingPathComponent(masterName), options: .atomic)
            try prepared.profileJPEG.write(to: assetsDir.appendingPathComponent(profileName), options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: assetsDir.appendingPathComponent(masterName))
            try? FileManager.default.removeItem(at: assetsDir.appendingPathComponent(profileName))
            throw error
        }
        discardReplacedDraftPhotoAssets()
        player.photoSourceRelativePath = masterName
        player.photoRelativePath = profileName
        player.profilePhotoCrop = prepared.profileCrop
        player.playerCardPhotoCrop = prepared.cardCrop
        draftPhotoRelativePaths.formUnion([masterName, profileName])
    }

    private func discardReplacedDraftPhotoAssets() {
        for path in draftPhotoRelativePaths {
            appModel.discardUncommittedAsset(relativePath: path)
        }
        draftPhotoRelativePaths.removeAll()
    }

    private func presentPhotoFraming(_ target: PhotoFramingTarget) {
        let configuredSourcePath = player.photoSourceRelativePath
        let candidatePaths = [configuredSourcePath, player.photoRelativePath]
            .compactMap { $0 }
            .reduce(into: [String]()) { paths, path in
                if !paths.contains(path) { paths.append(path) }
            }
        let loaded = candidatePaths.lazy.compactMap { path -> (String, UIImage)? in
            guard let url = try? AppPaths.assetURL(relativePath: path),
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { return nil }
            return (path, image)
        }.first
        guard let (loadedPath, image) = loaded else {
            appModel.lastError = "Roll Call could not load this player's photo."
            return
        }
        if configuredSourcePath != nil, loadedPath != configuredSourcePath {
            player.photoSourceRelativePath = nil
            player.profilePhotoCrop = nil
            player.playerCardPhotoCrop = nil
        }
        photoFramingImage = image
        photoFramingTarget = target
    }

    private func framingCrop(for target: PhotoFramingTarget, image: UIImage) -> NormalizedPhotoCrop {
        switch target {
        case .profile:
            return player.profilePhotoCrop
                ?? PlayerPhotoFramingGeometry.centeredCrop(aspectRatio: 1, imageSize: image.size)
        case .playerCard:
            return player.playerCardPhotoCrop
                ?? PlayerPhotoFramingGeometry.centeredCrop(
                    aspectRatio: PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio,
                    imageSize: image.size
                )
        }
    }

    private func photoFramingEditor(for target: PhotoFramingTarget, image: UIImage) -> some View {
        let aspectRatio = target == .profile ? 1.0 : PlayerPhotoFramingGeometry.playerCardPhotoAspectRatio
        let title = target == .profile ? "Adjust Profile Photo" : "Adjust Player Card Photo"

        return PhotoFramingEditorSheet(
            image: image,
            initialCrop: framingCrop(for: target, image: image),
            aspectRatio: aspectRatio,
            title: title,
            onCancel: {
                photoFramingTarget = nil
                photoFramingImage = nil
            },
            onApply: { crop in
                applyPhotoFraming(crop, target: target, image: image)
                photoFramingTarget = nil
                photoFramingImage = nil
            }
        )
    }

    private func applyPhotoFraming(_ crop: NormalizedPhotoCrop, target: PhotoFramingTarget, image: UIImage?) {
        switch target {
        case .profile:
            guard let image,
                  let profileImage = image.cropped(to: crop, outputSize: PlayerPhotoPreparationService.profilePixelSize),
                  let jpeg = profileImage.jpegData(compressionQuality: 0.86) else {
                appModel.lastError = "Roll Call could not apply that profile framing."
                return
            }
            let legacySourcePath = player.photoSourceRelativePath ?? player.photoRelativePath
            let profileName = "\(UUID().uuidString)-photo-profile.jpg"
            do {
                let assetsDir = try AppPaths.assetsDirectory()
                try jpeg.write(to: assetsDir.appendingPathComponent(profileName), options: .atomic)
                if let previousPath = player.photoRelativePath,
                   draftPhotoRelativePaths.contains(previousPath) {
                    appModel.discardUncommittedAsset(relativePath: previousPath)
                    draftPhotoRelativePaths.remove(previousPath)
                }
                player.photoSourceRelativePath = legacySourcePath
                player.photoRelativePath = profileName
                player.profilePhotoCrop = crop
                draftPhotoRelativePaths.insert(profileName)
                didAdjustProfileFraming = true
            } catch {
                appModel.lastError = error.localizedDescription
            }
        case .playerCard:
            player.playerCardPhotoCrop = crop
        }
    }

    private func refreshPlayerFromModel() {
        player = appModel.selectedTeam?.players.first(where: { $0.id == player.id }) ?? player
        isStartTrimEditingEnabled = false
        normalizeTrimModeForCurrentCue()
    }

    private func synchronizeSongAssignmentFromModel() {
        guard let savedPlayer else { return }
        player.songAssignment = savedPlayer.songAssignment
        isStartTrimEditingEnabled = false
        normalizeTrimModeForCurrentCue()
    }

    private func synchronizeCustomAnnouncerFromModel() {
        guard let savedPlayer else { return }
        player.customAnnouncerRelativePath = savedPlayer.customAnnouncerRelativePath
    }

    private func discardDraftPhotoAssets() {
        for path in draftPhotoRelativePaths {
            appModel.discardUncommittedAsset(relativePath: path)
        }
        draftPhotoRelativePaths.removeAll()
    }

    private func refreshPlayerFromModel(enableStartTrimForCueReplacing previousCueID: UUID?) {
        player = appModel.selectedTeam?.players.first(where: { $0.id == player.id }) ?? player
        isStartTrimEditingEnabled = editableCue?.id != nil && editableCue?.id != previousCueID
        normalizeTrimModeForCurrentCue()
    }

    private func performClearAction(_ action: PendingClearAction) {
        switch action {
        case .song:
            appModel.clearSong(forPlayerID: player.id)
            player.songAssignment = nil
        case .customAnnouncer:
            appModel.clearCustomAnnouncer(forPlayerID: player.id)
            player.customAnnouncerRelativePath = nil
        case .player:
            appModel.removePlayer(player)
            pendingClearAction = nil
            dismiss()
            return
        }
        pendingClearAction = nil
    }

    private var savedPlayer: Player? {
        appModel.selectedTeam?.players.first(where: { $0.id == player.id })
    }

    private var hasUnsavedChanges: Bool {
        guard let savedPlayer else { return false }
        return PlayerEditorDraftState(player: savedPlayer) != PlayerEditorDraftState(player: player)
    }

    private func closeEditor() {
        focusedField = nil
        if hasUnsavedChanges {
            showDiscardChangesConfirmation = true
        } else {
            discardDraftAndDismiss()
        }
    }

    private func saveAndDismiss() {
        appModel.commitPlayerEditorDraft(player)
        if let pendingPhotoDetectionResult {
            appModel.telemetry.record(
                .playerPhotoDetectionCompleted,
                properties: [.detection: pendingPhotoDetectionResult.rawValue]
            )
        }
        if didAdjustProfileFraming {
            appModel.telemetry.record(.playerPhotoProfileFramingAdjusted)
        }
        if didAdjustCardFraming {
            appModel.telemetry.record(.playerPhotoCardFramingAdjusted)
        }
        didCommitDraft = true
        draftPhotoRelativePaths.removeAll()
        dismiss()
    }

    private func discardDraftAndDismiss() {
        discardDraftPhotoAssets()
        dismiss()
    }

    private func secondsText(_ value: Double) -> String {
        formattedCueTime(value)
    }

    @ViewBuilder
    private func cueTrimSection(for cue: Cue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let trimHelpText = appModel.appleMusicTrimHelpText(for: cue) {
                Text(trimHelpText)
                    .rollCallText(.helperText)
                HStack(spacing: 8) {
                    ForEach(TrimSuggestionMode.allCases) { mode in
                        Button(mode.title) {
                            trimMode = mode
                            applyTrimSuggestion(mode: mode)
                        }
                        .buttonStyle(PlayerEditorChipButtonStyle(isSelected: trimMode == mode))
                    }
                }
            }

            Button {
                guard let cue = editableCue else { return }
                Task { await appModel.previewCue(cue) }
            } label: {
                Label("Preview Clip", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .rollCallButtonStyle(.primary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Start")
                        .rollCallText(.cardTitle)
                    Spacer()
                    Button(isStartTrimEditingEnabled ? "Done" : "Enable") {
                        isStartTrimEditingEnabled.toggle()
                    }
                    .rollCallButtonStyle(.quiet)
                    Text(secondsText(cue.startTime))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                StartScrubControl(
                    progress: cueTimeLimit <= 0 ? 0 : cue.startTime / cueTimeLimit,
                    displayRange: cueTimeLimit,
                    currentValueText: secondsText(cue.startTime),
                    onSeek: { progress in
                        updateCueStart(progress: progress)
                    },
                    onLiveScrub: { progress in
                        updateCueStart(progress: progress)
                        scheduleLiveScrubPreview()
                    }
                )
                .allowsHitTesting(isStartTrimEditingEnabled)
                .opacity(isStartTrimEditingEnabled ? 1 : 0.45)
                .overlay(alignment: .center) {
                    if !isStartTrimEditingEnabled {
                        Text("Tap Enable to adjust start")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Length")
                        .rollCallText(.cardTitle)
                    Spacer()
                    Text(secondsText(cue.duration))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                FlowChipRow(options: lengthOptions, selected: cue.duration) { option in
                    updateCueDuration(option)
                    appModel.rememberPreferredLength(option)
                }
            }

            Button {
                showAdvancedTrim = true
            } label: {
                Label("Advanced", systemImage: "slider.horizontal.3")
            }
            .rollCallButtonStyle(.secondary)
        }
    }

    private func normalizeTrimModeForCurrentCue() {
        guard let cue = editableCue, case .appleMusic = cue.source else { return }
        let beginningCue = appModel.chooseStartAtBeginning(for: cue)
        trimMode = abs(beginningCue.startTime - cue.startTime) < 0.01 ? .startAtBeginning : .suggestedHook
    }

    private func applyTrimSuggestion(mode: TrimSuggestionMode) {
        guard let cue = editableCue, case .appleMusic = cue.source else { return }
        switch mode {
        case .suggestedHook:
            player.updatePrivateSongClip(with: appModel.chooseSuggestedHook(for: cue))
        case .startAtBeginning:
            player.updatePrivateSongClip(with: appModel.chooseStartAtBeginning(for: cue))
        }
    }

    private func updateCueStart(progress: Double) {
        guard var cue = editableCue else { return }
        let maxStart = max(0, cueTimeLimit - cue.duration)
        cue.startTime = min(max(0, progress * cueTimeLimit), maxStart)
        player.updatePrivateSongClip(with: cue)
    }

    private func updateCueDuration(_ duration: Double) {
        guard var cue = editableCue else { return }
        cue.duration = min(duration, cueDurationLimit)
        cue.duration = min(cue.duration, cueTimeLimit - cue.startTime)
        cue.duration = max(0.5, cue.duration)
        player.updatePrivateSongClip(with: cue)
    }

    private func scheduleLiveScrubPreview() {
        liveScrubTask?.cancel()
        guard let cue = editableCue else { return }
        liveScrubTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            await appModel.previewCue(cue)
        }
    }
}

private struct PlayerEditorSectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .rollCallText(.chipLabel)
            .textCase(.uppercase)
            .foregroundStyle(Color(uiColor: .secondaryLabel))
    }
}

private struct PlayerEditorPhotoPickerLabel: View {
    let photoRelativePath: String?

    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    var body: some View {
        VStack(spacing: 6) {
            PlayerPhotoThumbnail(relativePath: photoRelativePath, size: 64, cornerRadius: 18)
            Text(photoRelativePath == nil ? "Add Photo" : "Change")
                .font(.caption.weight(.semibold))
                .foregroundStyle(teamAccentTheme.color(.primary))
        }
        .frame(width: 78)
    }
}

private struct PlayerEditorSectionIcon: View {
    let systemImage: String
    let role: RollCallColorRole

    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    private var color: Color {
        role == .accent ? teamAccentTheme.color(.primary) : Color.rollCall(role)
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct PlayerEditorChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? teamAccentTheme.color(.onFill) : Color(uiColor: .label))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(background(isPressed: configuration.isPressed))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(teamAccentTheme.color(.primary).opacity(isSelected ? 0 : 0.35), lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }

    private func background(isPressed: Bool) -> Color {
        let base = isSelected ? teamAccentTheme.color(.fill) : Color.rollCall(.neutralSurface)
        return isPressed ? base.opacity(0.78) : base
    }
}

private extension View {
    func playerEditorListRow() -> some View {
        listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 7, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

private func formattedCueTime(_ value: Double) -> String {
    let clamped = max(0, value)
    if clamped >= 60 {
        let minutes = Int(clamped) / 60
        let seconds = clamped.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, seconds)
    }
    return String(format: "%.2fs", clamped)
}

private struct BasicPhotoCropperSheet: View {
    let image: UIImage
    let onReady: () -> Void
    let onCancel: () -> Void
    let onApply: (UIImage) -> Void

    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 280

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Pinch to zoom, drag to position.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ZStack {
                    Rectangle()
                        .fill(Color.black.opacity(0.92))

                    GeometryReader { geometry in
                        let side = min(cropSize, min(geometry.size.width, geometry.size.height))
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: side, height: side)
                                .scaleEffect(zoom)
                                .offset(offset)
                                .clipped()
                                .gesture(dragGesture(maxSide: side))
                                .simultaneousGesture(magnifyGesture(maxSide: side))

                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.88), lineWidth: 2)
                                .frame(width: side, height: side)
                                .allowsHitTesting(false)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: cropSize)
                }
                .frame(height: cropSize + 24)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button("Reset") {
                        zoom = 1
                        lastZoom = 1
                        offset = .zero
                        lastOffset = .zero
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            .navigationTitle("Adjust Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Use Photo") {
                        onApply(croppedImage() ?? image)
                    }
                }
            }
            .onAppear {
                onReady()
            }
        }
    }

    private func magnifyGesture(maxSide: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(max(lastZoom * value, 1), 4)
                clampOffset(maxSide: maxSide)
            }
            .onEnded { _ in
                lastZoom = zoom
                clampOffset(maxSide: maxSide)
                lastOffset = offset
            }
    }

    private func dragGesture(maxSide: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                clampOffset(maxSide: maxSide)
            }
            .onEnded { _ in
                clampOffset(maxSide: maxSide)
                lastOffset = offset
            }
    }

    private func clampOffset(maxSide: CGFloat) {
        let normalized = image.normalizedUpImage()
        let baseScale = max(maxSide / normalized.size.width, maxSide / normalized.size.height)
        let scaledWidth = normalized.size.width * baseScale * zoom
        let scaledHeight = normalized.size.height * baseScale * zoom
        let maxX = max((scaledWidth - maxSide) / 2, 0)
        let maxY = max((scaledHeight - maxSide) / 2, 0)
        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
    }

    private func croppedImage() -> UIImage? {
        let normalized = image.normalizedUpImage()
        guard let cgImage = normalized.cgImage else { return nil }

        let side = cropSize
        let baseScale = max(side / normalized.size.width, side / normalized.size.height)
        let effectiveScale = baseScale * zoom
        let displayedWidth = normalized.size.width * effectiveScale
        let displayedHeight = normalized.size.height * effectiveScale

        let originX = (side - displayedWidth) / 2 + offset.width
        let originY = (side - displayedHeight) / 2 + offset.height

        var cropRect = CGRect(
            x: (0 - originX) / effectiveScale,
            y: (0 - originY) / effectiveScale,
            width: side / effectiveScale,
            height: side / effectiveScale
        ).integral

        cropRect.origin.x = max(0, min(cropRect.origin.x, normalized.size.width - cropRect.width))
        cropRect.origin.y = max(0, min(cropRect.origin.y, normalized.size.height - cropRect.height))
        cropRect.size.width = min(cropRect.width, normalized.size.width - cropRect.origin.x)
        cropRect.size.height = min(cropRect.height, normalized.size.height - cropRect.origin.y)

        guard let cropped = cgImage.cropping(to: cropRect), cropped.width > 0, cropped.height > 0 else {
            return nil
        }
        return UIImage(cgImage: cropped, scale: normalized.scale, orientation: .up)
    }
}

private extension UIImage {
    func normalizedUpImage() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private extension PlayerEditorSheet {
    enum PendingClearAction: Identifiable {
        case song
        case customAnnouncer
        case player

        var id: String {
            switch self {
            case .song:
                return "song"
            case .customAnnouncer:
                return "customAnnouncer"
            case .player:
                return "player"
            }
        }

        var confirmButtonTitle: String {
            switch self {
            case .song:
                return "Clear Song"
            case .customAnnouncer:
                return "Clear Announcement Cue"
            case .player:
                return "Remove Player"
            }
        }

        var confirmationMessage: String {
            switch self {
            case .song:
                return "This will remove the current cue for this player."
            case .customAnnouncer:
                return "This will remove only the Announcement Cue recording for this player."
            case .player:
                return "This will remove this player from the roster, lineup, and Game Day. You can restore them later from Recovery."
            }
        }
    }
}

private extension Cue {
    var rosterDisplayTitle: String {
        switch source {
        case .appleMusic(let source):
            return source.title
        case .localAudio(let source):
            return source.displayName.songTitleWithoutArtistPrefix
        case .builtInClip(let source):
            return source.displayName
        }
    }
}

private extension String {
    var songTitleWithoutArtistPrefix: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let separators = [" - ", " — ", " – "]
        for separator in separators {
            guard let range = trimmed.range(of: separator) else { continue }
            let candidate = trimmed[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                return candidate
            }
        }
        return trimmed
    }
}

private enum TrimSuggestionMode: String, CaseIterable, Identifiable {
    case suggestedHook
    case startAtBeginning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .suggestedHook:
            return "Suggested Hook"
        case .startAtBeginning:
            return "Start at Beginning"
        }
    }
}

private struct AppleMusicPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel
    let onSelect: (MusicSearchResult) -> Void

    @State private var searchTerm = ""
    @State private var results: [MusicSearchResult] = []
    @State private var isLoading = false
    @State private var hasSearched = false
    @State private var searchTask: Task<Void, Never>?
    @State private var searchError: String?

    private var showsRecents: Bool {
        searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isExplicitFilteringEnabled: Bool {
        appModel.state.settings.explicitAppleMusicSearchFilteringEnabled
    }

    private var visibleResults: [MusicSearchResult] {
        isExplicitFilteringEnabled
            ? results.filter { $0.isExplicit != true }
            : results
    }

    private var hiddenExplicitResultsInCurrentSearch: Bool {
        isExplicitFilteringEnabled && results.contains { $0.isExplicit == true }
    }

    var body: some View {
        NavigationStack {
            List {
                capabilityBanner
                if isExplicitFilteringEnabled {
                    Section {
                        Text("Explicit songs are hidden from Apple Music search. You can change this in Settings > Music.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if showsRecents {
                    Section("Recent Songs") {
                        if appModel.recentAppleMusicSelections.isEmpty {
                            Text("Your recent songs will show up here.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(appModel.recentAppleMusicSelections) { recent in
                                AppleMusicRow(
                                    title: recent.title,
                                    artistName: recent.artistName,
                                    badge: recent.isCatalogBacked == false ? "Preview" : "Full Song",
                                    isExplicit: recent.isExplicit == true && !isExplicitFilteringEnabled,
                                    onSelect: {
                                        onSelect(recent.asSearchResult)
                                    },
                                    onPreview: {
                                        Task { await appModel.previewAppleMusicSearchResult(recent.asSearchResult) }
                                    }
                                )
                            }
                        }
                    }
                } else {
                    Section("Search Results") {
                        if isLoading {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Searching Apple Music…")
                                    .foregroundStyle(.secondary)
                            }
                        } else if results.isEmpty, hasSearched {
                            Text(searchError ?? "No songs found. Try a different search.")
                                .foregroundStyle(.secondary)
                        } else if visibleResults.isEmpty, hasSearched, hiddenExplicitResultsInCurrentSearch {
                            Text("No visible songs found. Try a different search or turn off explicit filtering in Settings > Music.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(visibleResults) { result in
                                AppleMusicRow(
                                    title: result.title,
                                    artistName: result.artistName,
                                    badge: result.isCatalogBacked ? "Full Song" : "Preview",
                                    isExplicit: result.isExplicit == true && !isExplicitFilteringEnabled,
                                    onSelect: {
                                        onSelect(result)
                                    },
                                    onPreview: {
                                        Task { await appModel.previewAppleMusicSearchResult(result) }
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .accentWashListBackground()
            .navigationTitle("Choose Song")
            .searchable(text: $searchTerm, prompt: "Search Apple Music")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await appModel.refreshAppleMusicPlaybackCapability()
            }
            .onChange(of: searchTerm) { _, newValue in
                queueSearch(for: newValue)
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    @ViewBuilder
    private var capabilityBanner: some View {
        Section {
            switch appModel.appleMusicPlaybackCapability {
            case .fullSong:
                Text("Full-song playback depends on your Apple Music subscription and song availability on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            case .previewOnly, .unknown:
                Text("Full-song playback depends on your Apple Music subscription and song availability on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func queueSearch(for rawValue: String) {
        searchTask?.cancel()
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isLoading = false
            hasSearched = false
            searchError = nil
            return
        }

        isLoading = true
        hasSearched = false
        searchError = nil
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                let fetched = try await appModel.searchAppleMusic(term: trimmed)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = fetched
                    isLoading = false
                    hasSearched = true
                    searchError = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    results = []
                    isLoading = false
                    hasSearched = true
                    searchError = error.localizedDescription
                    appModel.lastError = error.localizedDescription
                }
            }
        }
    }
}

private struct AppleMusicRow: View {
    let title: String
    let artistName: String
    let badge: String
    let isExplicit: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(artistName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(badge == "Full Song" ? .green : .orange)
                    if isExplicit {
                        Text("Explicit")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onPreview) {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview \(title)")
            .accessibilityHint("Plays a short preview without selecting this song.")
        }
        .padding(.vertical, 4)
    }
}

private struct StartScrubControl: View {
    let progress: Double
    let displayRange: Double
    let currentValueText: String
    let onSeek: (Double) -> Void
    let onLiveScrub: (Double) -> Void

    @GestureState private var isPressing = false
    @GestureState private var isDragging = false
    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let thumbOffset = max(0, min(width - 28, width * progress - 14))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.18))
                    .frame(height: 18)
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(teamAccentTheme.color(.fill).opacity(0.82))
                    .frame(width: max(14, width * progress), height: 18)
                if isDragging {
                    Text(currentValueText)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .offset(x: max(0, min(width - 72, width * progress - 36)), y: -30)
                }
                Circle()
                    .fill(teamAccentTheme.color(.fill))
                    .frame(width: 28, height: 28)
                    .offset(x: thumbOffset)
                    .shadow(radius: 2)
            }
            .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        let newProgress = min(max(0, value.location.x / width), 1)
                        onSeek(newProgress)
                        if isPressing {
                            onLiveScrub(newProgress)
                        }
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35)
                    .updating($isPressing) { current, state, _ in
                        state = current
                    }
            )
        }
        .frame(height: 40)
        .accessibilityValue(Text("\(Int(progress * displayRange)) seconds"))
    }
}

private struct FlowChipRow: View {
    let options: [Double]
    let selected: Double
    let onSelect: (Double) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button("\(Int(option))s") {
                    onSelect(option)
                }
                .buttonStyle(PlayerEditorChipButtonStyle(isSelected: abs(selected - option) < 0.01))
            }
        }
    }
}

private struct AdvancedTrimSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var cue: Cue
    let cueTimeLimit: Double
    let cueDurationLimit: Double

    var body: some View {
        NavigationStack {
            Form {
                Section("Fine Tune") {
                    nudgeRow(title: "Start", value: cue.startTime) { delta in
                        let maxStart = max(0, cueTimeLimit - cue.duration)
                        cue.startTime = min(max(0, cue.startTime + delta), maxStart)
                    }
                    nudgeRow(title: "Length", value: cue.duration) { delta in
                        cue.duration = min(max(0.5, cue.duration + delta), cueDurationLimit)
                        cue.duration = min(cue.duration, cueTimeLimit - cue.startTime)
                    }
                }

                Section("Fade Out") {
                    nudgeRow(title: "Fade", value: cue.fadeOutDuration) { delta in
                        cue.fadeOutDuration = min(max(0.1, cue.fadeOutDuration + delta), 3.0)
                    }
                    Text("Fade timing is baked into generated local clips. For source-backed Apple Music or Music Library songs, it applies when Volume Automation is enabled in Settings.")
                        .rollCallText(.helperText)
                }
            }
            .navigationTitle("Advanced Trim")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func nudgeRow(title: String, value: Double, apply: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            Button("-0.25") { apply(-0.25) }
                .buttonStyle(.bordered)
            Text(formattedCueTime(value))
                .monospacedDigit()
                .frame(minWidth: 68)
            Button("+0.25") { apply(0.25) }
                .buttonStyle(.bordered)
        }
    }
}

private extension RecentAppleMusicSelection {
    var asSearchResult: MusicSearchResult {
        MusicSearchResult(songID: songID, title: title, artistName: artistName, duration: duration, previewURL: previewURL, isCatalogBacked: isCatalogBacked ?? true, libraryPersistentID: libraryPersistentID, isExplicit: isExplicit)
    }
}

private struct PlayerPhotoThumbnail: View {
    let relativePath: String?
    var size: CGFloat
    var cornerRadius: CGFloat = 16

    @Environment(\.rollCallTeamAccentTheme) private var teamAccentTheme

    var body: some View {
        Group {
            if let image = loadImage() {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(teamAccentTheme.color(.subtle).opacity(0.14))
                    Image(systemName: "person.crop.square.fill")
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(teamAccentTheme.color(.primary).opacity(0.82))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color(uiColor: .separator), lineWidth: 1)
        )
    }

    private func loadImage() -> UIImage? {
        guard let relativePath else { return nil }
        return PlayerPhotoCache.shared.image(for: relativePath)
    }
}

private extension View {
    func dismissesKeyboardOnTap() -> some View {
        background(KeyboardDismissTapOverlay())
    }
}

private struct KeyboardDismissTapOverlay: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @objc func handleTap() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

@MainActor
private final class PlayerPhotoCache {
    static let shared = PlayerPhotoCache()

    private let cache = NSCache<NSString, UIImage>()

    func image(for relativePath: String) -> UIImage? {
        let key = relativePath as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let url = try? AppPaths.assetURL(relativePath: relativePath),
              let image = UIImage(contentsOfFile: url.path)
        else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }
}
