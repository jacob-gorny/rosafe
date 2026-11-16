import Foundation
import Observation
import os

/// Where a fix came from: the phone's location, or a simulated drive.
enum FixSource {
    case device, simulator
}

/// Joins the parts of the alert: location and the simulated drive feed fixes to one
/// `AlertEngine`, which uses the selected day's flagged roads; a hit becomes a notification, and
/// a tap on that notification opens the road's popup.
@Observable
final class AppCoordinator {
    let store: DataStore?
    let location: LocationService?
    /// The five demo drives from `routes.gpx` (empty if the file couldn't be read).
    let routes: [DemoRoute]
    /// The running simulated drive, if any.
    private(set) var drive: DriveSimulator?
    /// The notification deep link: RootView opens this road's popup, then sets it back to nil.
    var roadToOpen: String?

    @ObservationIgnored private let notifier: any NotificationSending
    @ObservationIgnored private var engine = AlertEngine()
    /// The day whose flagged roads the engine holds.
    @ObservationIgnored private var targetsDate: String?
    @ObservationIgnored private var countsCache: (date: String, counts: [Int])?

    init(store: DataStore?, location: LocationService?, notifier: any NotificationSending, routes: [DemoRoute]) {
        self.store = store
        self.location = location
        self.notifier = notifier
        self.routes = routes
        engine = freshEngine()
        location?.onFix = { [weak self] fix in self?.receive(fix, from: .device) }
    }

    /// The app's coordinator: real location, real notifications, the bundled demo routes.
    static func live(store: DataStore?) -> AppCoordinator {
        let notifier = Notifier()
        let location = LocationService()
        var routes: [DemoRoute] = []
        if let folder = Bundle.main.url(forResource: "data", withExtension: nil) {
            do { routes = try DemoRoutes.load(from: folder.appending(path: "routes.gpx")) }
            catch {
                Logger(subsystem: "com.samerain.SameRain", category: "data")
                    .error("Couldn't read the demo drives: \(error.localizedDescription, privacy: .public)")
            }
        }
        let coordinator = AppCoordinator(store: store, location: location, notifier: notifier, routes: routes)
        notifier.onOpenRoad = { [weak coordinator] roadId in coordinator?.roadToOpen = roadId }
        notifier.install()
        location.onReadyForNotifications = {
            Task { await Notifier.requestAuthorization() }
        }
        return coordinator
    }

    // MARK: Location

    var isWatching: Bool { location?.isWatching ?? false }

    func turnOnLocation() { location?.requestPermissions() }

    // MARK: Fixes

    /// Runs one fix through the engine and sends the notification on a hit. While a simulated
    /// drive runs, the phone's own fixes are left out, so the two never mix in one engine.
    func receive(_ fix: Fix, from source: FixSource) {
        if source == .device, drive != nil { return }
        syncTargets()
        if let hit = engine.process(fix) {
            notifier.send(road: hit.road, pred: hit.pred)
        }
    }

    /// The engine always works on the selected day's flagged roads: when the day changes, the next
    /// fix swaps them in (the engine keeps each road's pass, so a road doesn't alert twice).
    private func syncTargets() {
        guard let store, store.selectedDate != targetsDate else { return }
        engine.setTargets(store.flagged)
        targetsDate = store.selectedDate
    }

    private func freshEngine() -> AlertEngine {
        var e = AlertEngine()
        if let store {
            e.setTargets(store.flagged)
            targetsDate = store.selectedDate
        }
        return e
    }

    // MARK: Simulated drive

    /// Replays `route` with the selected day's flagged roads. Each drive starts with a fresh
    /// engine, so a second run alerts again. If the phone was never asked about notifications
    /// (the location flow never ran), it is asked first and the drive starts once that is
    /// answered, so the first banner isn't lost behind the prompt.
    func startDrive(_ route: DemoRoute) {
        endDrive()
        engine = freshEngine()
        let sim = DriveSimulator(route: route)
        drive = sim
        notifier.askIfUndecided { [weak self, weak sim] in
            // Ended, or replaced by another drive, while the question was up.
            guard let self, let sim, self.drive === sim else { return }
            sim.start(onFix: { [weak self] fix in
                self?.receive(fix, from: .simulator)
            }, onEnd: { [weak self, weak sim] in
                guard let self, let sim, self.drive === sim else { return }
                self.finishDrive()
            })
        }
    }

    /// Stops a running drive early.
    func endDrive() {
        guard let sim = drive else { return }
        sim.stop()
        finishDrive()
    }

    /// The drive's fixes don't carry over: the phone's location starts again on a fresh engine.
    private func finishDrive() {
        drive = nil
        engine = freshEngine()
    }

    /// How many notifications `route` will send on the selected day: the same fixes through a
    /// fresh engine with the same flagged roads, so the number is exactly what the drive does.
    func alertCount(for route: DemoRoute) -> Int {
        Self.alertCount(route: route, targets: store?.flagged ?? [])
    }

    /// `alertCount(for:)` for every demo route, in order. Kept per day.
    func alertCounts() -> [Int] {
        let date = store?.selectedDate ?? ""
        if let cache = countsCache, cache.date == date { return cache.counts }
        let targets = store?.flagged ?? []
        let counts = routes.map { Self.alertCount(route: $0, targets: targets) }
        countsCache = (date, counts)
        return counts
    }

    /// The same counts, worked out off the main thread (all five take a moment).
    func loadAlertCounts() async -> [Int] {
        let date = store?.selectedDate ?? ""
        if let cache = countsCache, cache.date == date { return cache.counts }
        let targets = store?.flagged ?? []
        let routes = routes
        let counts = await Task.detached(priority: .userInitiated) {
            routes.map { Self.alertCount(route: $0, targets: targets) }
        }.value
        countsCache = (date, counts)
        return counts
    }

    nonisolated static func alertCount(route: DemoRoute, targets: [(road: Road, pred: Double)]) -> Int {
        var e = AlertEngine()
        e.setTargets(targets)
        return DriveSimulator.fixes(for: route).reduce(0) { n, fix in e.process(fix) == nil ? n : n + 1 }
    }
}
