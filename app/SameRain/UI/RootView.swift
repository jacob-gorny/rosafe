import SwiftUI

/// The three inner pages; each opens from its word on home.
enum Page: String, CaseIterable, Identifiable {
    case score, roads, map

    var id: String { rawValue }

    var title: String {
        switch self {
        case .score: "Daily score"
        case .roads: "Roads to avoid"
        case .map: "Map"
        }
    }
}

/// The one sheet that can show: the day picker or a road's popup. One sheet modifier holds both,
/// so switching from one to the other dismisses the first before presenting the second.
enum AppSheet: Identifiable, Equatable {
    case dayPicker
    case road(String)
    /// The Map page's "Simulate a drive" route list.
    case routePicker

    var id: String {
        switch self {
        case .dayPicker: "day-picker"
        case .road(let roadId): "road-\(roadId)"
        case .routePicker: "route-picker"
        }
    }
}

/// Which page is open and which sheet shows. Plain data, so the deep link can be tested.
struct Navigation: Equatable {
    var page: Page?
    var sheet: AppSheet?

    init(page: Page? = nil, sheet: AppSheet? = nil) {
        self.page = page
        self.sheet = sheet
    }

    /// The road whose popup shows, if any.
    var popupRoadId: String? {
        if case .road(let roadId) = sheet { roadId } else { nil }
    }

    /// The notification deep link: go to Roads to avoid and open that road's popup (replacing the
    /// day picker if it was up). Changes nothing and returns false for a road the app doesn't know.
    @discardableResult
    mutating func openRoad(id: String, isKnown: (String) -> Bool) -> Bool {
        guard isKnown(id) else { return false }
        page = .roads
        sheet = .road(id)
        return true
    }

    /// The deep link's second step, after the page change has settled: shows `target`'s popup,
    /// unless the driver left the page or another sheet (the day picker, a newer link's popup)
    /// came up during the wait.
    mutating func finishOpening(_ target: Navigation) {
        guard page == target.page, sheet == nil else { return }
        sheet = target.sheet
    }
}

/// The whole screen's size and its safe-area insets, so home, pages and symbols share one frame.
struct ScreenFrame {
    let size: CGSize
    let insets: EdgeInsets
}

/// Holds the open page. Home, the inner page and the weather tiles all stay on screen
/// together, so a word can fly from home into the page title and the tiles can glide to the
/// screen edges and back.
struct RootView: View {
    let store: DataStore?
    /// From the location service (via the coordinator).
    var isWatching: Bool
    var onTurnOnLocation: () -> Void
    /// The deep-link seam: set it to a road id (a notification tap does) and the app goes to
    /// Roads to avoid and opens that road's popup, then sets it back to nil.
    @Binding var roadToOpen: String?
    /// The simulated drive's controls on the Map page; nil hides them.
    var coordinator: AppCoordinator?

    @State private var nav: Navigation
    @AppStorage(DataStore.storedDateKey) private var storedDate = ""
    @Namespace private var words
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: DataStore?, initialPage: Page? = nil, isWatching: Bool = false,
         onTurnOnLocation: @escaping () -> Void = {}, roadToOpen: Binding<String?> = .constant(nil),
         coordinator: AppCoordinator? = nil) {
        self.store = store
        self.isWatching = isWatching
        self.onTurnOnLocation = onTurnOnLocation
        _roadToOpen = roadToOpen
        self.coordinator = coordinator
        _nav = State(initialValue: Navigation(page: store == nil ? nil : initialPage))
    }

    private var symbolSet: SymbolSet {
        guard let day = store?.day else { return .dry(fog: false) }
        return DayMath.symbolSet(day.weather, rare: day.rare)
    }

    private var tileSymbols: [String] {
        guard let day = store?.day else { return WeatherTiles.symbols(for: .dry(fog: false), reasons: []) }
        return WeatherTiles.symbols(for: day)
    }

    var body: some View {
        // The reader respects the safe area so it can report the insets; the content then
        // extends over the whole screen and places things itself.
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let screen = ScreenFrame(
                size: CGSize(width: geo.size.width + insets.leading + insets.trailing,
                             height: geo.size.height + insets.top + insets.bottom),
                insets: insets)
            ZStack(alignment: .topLeading) {
                // Only the tint crossfades when the day changes; the tiles crossfade their own
                // symbols, and the page content just shows the new day.
                Theme.tint(for: symbolSet)
                    .animation(.easeInOut(duration: 0.5), value: symbolSet)

                if store != nil {
                    WeatherTilesLayer(symbols: tileSymbols, onPage: nav.page != nil, hideSides: nav.page == .map)
                }

                HomeView(namespace: words,
                         page: nav.page,
                         screen: screen,
                         dateText: store.map { DayLabel.long($0.selectedDate) },
                         isWatching: isWatching,
                         onOpen: open,
                         onPickDay: { nav.sheet = .dayPicker },
                         onTurnOnLocation: onTurnOnLocation)

                if let store {
                    InnerPage(namespace: words, page: nav.page, store: store, screen: screen,
                              coordinator: coordinator,
                              onBack: goHome, onOpenRoad: { nav.sheet = .road($0) },
                              onPickRoute: { nav.sheet = .routePicker })
                }
            }
            .frame(width: screen.size.width, height: screen.size.height)
            .ignoresSafeArea()
        }
        .sheet(item: $nav.sheet) { sheet in
            if let store {
                Group {
                    switch sheet {
                    case .dayPicker:
                        DayPicker(store: store, onPick: pickDay)
                    case .road(let roadId):
                        RoadPopup(store: store, roadId: roadId)
                    case .routePicker:
                        if let coordinator {
                            RoutePicker(store: store, coordinator: coordinator)
                        }
                    }
                }
                .presentationBackground(Theme.tint(for: symbolSet))
            }
        }
        .onChange(of: roadToOpen, initial: true) { _, roadId in
            guard let roadId else { return }
            roadToOpen = nil
            openRoad(id: roadId)
        }
    }

    private var pageAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.5, dampingFraction: 0.8)
    }

    private func open(_ p: Page) {
        withAnimation(pageAnimation) { nav.page = p }
    }

    private func goHome() {
        withAnimation(pageAnimation) { nav.page = nil }
    }

    private func pickDay(_ date: String) {
        guard let store, store.isLoaded(date) else { return }
        store.selectedDate = date
        storedDate = date
    }

    /// Goes to Roads to avoid (with the usual word-to-title move) and opens the road's popup.
    /// When the page or the sheet has to change first, the popup waits for that to settle.
    func openRoad(id: String) {
        guard let store else { return }
        var next = nav
        guard next.openRoad(id: id, isKnown: { store.roadIndex[$0] != nil }) else { return }
        let settle = next.page != nav.page || (nav.sheet != nil && nav.sheet != next.sheet)
        withAnimation(pageAnimation) { nav.page = next.page }
        guard settle else {
            nav.sheet = next.sheet
            return
        }
        nav.sheet = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))
            nav.finishOpening(next)
        }
    }
}

/// An inner page: the title (the word that flew) at the top left, then the page itself.
private struct InnerPage: View {
    let namespace: Namespace.ID
    let page: Page?
    let store: DataStore
    let screen: ScreenFrame
    let coordinator: AppCoordinator?
    let onBack: () -> Void
    let onOpenRoad: (String) -> Void
    let onPickRoute: () -> Void

    var body: some View {
        let inset = TileLayout.pageInset(width: screen.size.width)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                // Keep PageTitle directly inserted here: its own transition flies the word.
                if let page {
                    PageTitle(namespace: namespace, page: page, onBack: onBack)
                }
                Spacer(minLength: 0)
                if let page {
                    PageTitleTrailing(page: page, store: store)
                        .transition(.opacity)
                }
            }
            if let page {
                PageBody(page: page, store: store, coordinator: coordinator,
                         onOpenRoad: onOpenRoad, onPickRoute: onPickRoute)
                    .transition(.opacity)
            }
        }
        .padding(.top, screen.insets.top + 8)
        // Wide enough that the half-cut edge tiles never touch the text, and the column ends
        // above the corner tile.
        .padding(.horizontal, inset)
        .padding(.bottom, TileLayout.pageBottom)
        .environment(\.pageInset, inset)
        .frame(width: screen.size.width, height: screen.size.height, alignment: .topLeading)
    }
}

/// Each page's content, under the title.
private struct PageBody: View {
    let page: Page
    let store: DataStore
    let coordinator: AppCoordinator?
    let onOpenRoad: (String) -> Void
    let onPickRoute: () -> Void

    var body: some View {
        switch page {
        case .score:
            DailyScoreView(store: store)
        case .roads:
            RoadsView(store: store, onOpenRoad: onOpenRoad)
        case .map:
            if let coordinator {
                MapPage(store: store, car: coordinator.drive?.position) {
                    DriveControls(store: store, coordinator: coordinator, onPickRoute: onPickRoute)
                }
            } else {
                MapPage(store: store)
            }
        }
    }
}

extension EnvironmentValues {
    /// The inner pages' side margin (`TileLayout.pageInset`), so the map box can break out of it.
    @Entry var pageInset: CGFloat = 48
}

/// What sits beside the title: the day's score on Daily score, nothing elsewhere.
private struct PageTitleTrailing: View {
    let page: Page
    let store: DataStore

    var body: some View {
        if page == .score, let day = store.day {
            DailyScoreNumber(day: day)
        }
    }
}
