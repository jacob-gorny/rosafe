import SwiftUI
import os

@main
struct SameRainApp: App {
    /// Owns location, the alert engine, the simulated drive and the notification deep link.
    /// Made at launch, so a notification tap that opens the app reaches it.
    @State private var coordinator: AppCoordinator

    init() {
        var store: DataStore?
        do {
            let loaded = try DataStore.loadFromBundle()
            // The remembered day, if it's still a loaded day; the debug -date argument wins.
            let stored = UserDefaults.standard.string(forKey: DataStore.storedDateKey)
            #if DEBUG
            loaded.selectedDate = loaded.launchDate(stored: stored, override: DebugLaunch.date)
            #else
            loaded.selectedDate = loaded.launchDate(stored: stored, override: nil)
            #endif
            store = loaded
        } catch {
            // Never crash: home shows one plain line instead.
            Logger(subsystem: "com.samerain.SameRain", category: "data")
                .error("Couldn't read the road scores: \(error.localizedDescription, privacy: .public)")
        }
        let coordinator = AppCoordinator.live(store: store)
        #if DEBUG
        coordinator.roadToOpen = DebugLaunch.road
        #endif
        _coordinator = State(initialValue: coordinator)
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            AppRoot(coordinator: coordinator, initialPage: DebugLaunch.page)
            #else
            AppRoot(coordinator: coordinator)
            #endif
        }
    }
}

/// Reads the coordinator inside a view, so location and deep-link changes redraw the screen.
struct AppRoot: View {
    @Bindable var coordinator: AppCoordinator
    var initialPage: Page?

    var body: some View {
        RootView(store: coordinator.store, initialPage: initialPage,
                 isWatching: coordinator.isWatching,
                 onTurnOnLocation: { coordinator.turnOnLocation() },
                 roadToOpen: $coordinator.roadToOpen,
                 coordinator: coordinator)
    }
}

#if DEBUG
/// Debug aids for screenshots, read from launch arguments only:
/// `-date 2023-08-25` selects that day (if loaded), `-page score|roads|map` opens that page at
/// launch, unanimated, and `-road <id>` opens that road's popup through the deep-link seam.
enum DebugLaunch {
    private static var arguments: [String: Any] {
        UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
    }

    static var date: String? { arguments["date"] as? String }
    static var page: Page? { (arguments["page"] as? String).flatMap(Page.init(rawValue:)) }
    static var road: String? { arguments["road"] as? String }
}
#endif
