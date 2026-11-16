import Testing
import Foundation
import CoreLocation
import UserNotifications
@testable import SameRain

/// Records what the coordinator would have sent, instead of showing a notification.
@MainActor
private final class FakeNotifier: NotificationSending {
    var sent: [(road: Road, pred: Double)] = []
    func send(road: Road, pred: Double) { sent.append((road, pred)) }
}

/// Holds the notification question, as the real prompt does until the driver answers it.
@MainActor
private final class AskingNotifier: NotificationSending {
    var sent: [(road: Road, pred: Double)] = []
    var waiting: [@MainActor () -> Void] = []
    func send(road: Road, pred: Double) { sent.append((road, pred)) }
    func askIfUndecided(then: @escaping @MainActor () -> Void) { waiting.append(then) }
}

@MainActor
private func demoRoutes() throws -> [DemoRoute] {
    let url = try #require(Bundle.main.url(forResource: "data", withExtension: nil))
    return try DemoRoutes.load(from: url.appending(path: "routes.gpx"))
}

/// Location, notifications and the simulated drive (Task 6).
@MainActor
@Suite struct AppTests {

    // MARK: Notification

    @Test func notificationContent() throws {
        let store = try DataStore.loadFromBundle()
        let road = try #require(store.roads.first { $0.id == "state-ih35e-asphalt_over_concrete" })
        let c = Notifier.content(road: road, pred: 1.66)
        #expect(c.title == "Approaching risky road")
        #expect(c.body == "I-35E \u{00B7} 66% more crashes than normal today")
        #expect(c.interruptionLevel == .timeSensitive)
        #expect(c.sound != nil)
        #expect(c.userInfo["roadId"] as? String == "state-ih35e-asphalt_over_concrete")
    }

    // MARK: Location fixes

    @Test func locationFixKeepsTheRealAccuracy() {
        let t = Date(timeIntervalSince1970: 1_700_000_000)
        let loc = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 32.8, longitude: -96.8), altitude: 150,
                             horizontalAccuracy: 42, verticalAccuracy: 10, course: 91, speed: 27.5, timestamp: t)
        let f = LocationService.fix(from: loc)
        #expect(f.coordinate.latitude == 32.8)
        #expect(f.coordinate.longitude == -96.8)
        #expect(f.horizontalAccuracy == 42)
        #expect(f.speed == 27.5)
        #expect(f.course == 91)
        #expect(f.time == t)
    }

    /// A cached location from before (say, the end of an earlier drive, still carrying its speed)
    /// must not alert a parked driver who opens the app: only fresh fixes go on to the engine.
    @Test func staleCachedLocationsAreDropped() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        func loc(ageSeconds: Double) -> CLLocation {
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 32.8, longitude: -96.8), altitude: 0,
                       horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 29,
                       timestamp: now.addingTimeInterval(-ageSeconds))
        }
        #expect(LocationService.isFresh(loc(ageSeconds: 0), now: now))
        #expect(LocationService.isFresh(loc(ageSeconds: 9), now: now))
        #expect(!LocationService.isFresh(loc(ageSeconds: 11), now: now))
        #expect(!LocationService.isFresh(loc(ageSeconds: 600), now: now))
    }

    // MARK: Simulated drive fixes

    @Test func driveFixesFollowTheRoute() throws {
        let route = try demoRoutes()[0]
        let fixes = DriveSimulator.fixes(for: route)
        #expect(fixes.count == route.points.count)
        for (i, f) in fixes.enumerated() {
            // Route time, never the wall clock: fixes stay 5 s apart for the engine.
            #expect(f.time == route.times[i])
            #expect(f.coordinate.latitude == route.points[i].latitude)
            #expect(f.coordinate.longitude == route.points[i].longitude)
            #expect(f.horizontalAccuracy == 5)
            // About 65 mph, from the distance between points over their 5 s.
            #expect(f.speed > 28 && f.speed < 30)
            #expect(f.course >= 0 && f.course < 360)
        }
        #expect(fixes[1].time.timeIntervalSince(fixes[0].time) == 5)
        let d01 = Geo.distance(from: route.points[0], to: [[route.points[1]]]).meters
        #expect(abs(fixes[0].speed - d01 / 5) < 1e-9)
        #expect(abs(fixes[0].course - Geo.bearing(from: route.points[0], to: route.points[1])) < 1e-9)
        // The last point has no next one: it keeps the last leg's course.
        let n = route.points.count
        #expect(abs(fixes[n - 1].course - Geo.bearing(from: route.points[n - 2], to: route.points[n - 1])) < 1e-9)
    }

    @Test func driveCopy() {
        #expect(DriveCopy.alertsLine(0) == "0 alerts today")
        #expect(DriveCopy.alertsLine(1) == "1 alert today")
        #expect(DriveCopy.alertsLine(3) == "3 alerts today")
        #expect(DriveCopy.running == "Simulated drive \u{00B7} 65 mph")
    }

    // MARK: Coordinator

    @Test func route1OnSep23AlertsI35EFirst() throws {
        let store = try DataStore.loadFromBundle()
        store.selectedDate = "2024-09-23"
        let routes = try demoRoutes()
        let fake = FakeNotifier()
        let c = AppCoordinator(store: store, location: nil, notifier: fake, routes: routes)
        for f in DriveSimulator.fixes(for: routes[0]) { c.receive(f, from: .device) }
        let first = try #require(fake.sent.first)
        #expect(first.road.displayName == "I-35E")
        #expect(first.pred == 1.66)
        #expect(Notifier.content(road: first.road, pred: first.pred).body
                == "I-35E \u{00B7} 66% more crashes than normal today")
        print("ROUTE1 Sep 23:", fake.sent.map { "\($0.road.displayName) \(DayMath.percent($0.pred))%" })
    }

    @Test func changingTheDayRetargets() throws {
        let store = try DataStore.loadFromBundle()
        store.selectedDate = "2024-09-23"
        let routes = try demoRoutes()
        let fake = FakeNotifier()
        let c = AppCoordinator(store: store, location: nil, notifier: fake, routes: routes)
        for f in DriveSimulator.fixes(for: routes[0]) { c.receive(f, from: .device) }
        #expect(!fake.sent.isEmpty)
        // Control: on Sep 23, route 5 passes flagged roads, so silence below means new targets.
        #expect(c.alertCount(for: routes[4]) > 0)

        store.selectedDate = "2023-08-25"
        let before = fake.sent.count
        for f in DriveSimulator.fixes(for: routes[4]) { c.receive(f, from: .device) }
        #expect(fake.sent.count == before)
        #expect(c.alertCount(for: routes[4]) == 0)
    }

    /// Plays a whole simulated drive by hand (the timer would call `tick` once a second).
    private func play(_ route: DemoRoute, on c: AppCoordinator) throws {
        c.startDrive(route)
        var steps = 0
        while c.drive != nil {
            try #require(steps <= route.points.count + 1)
            c.drive?.tick()
            steps += 1
        }
    }

    @Test func offlineCountMatchesTheDrive() throws {
        let store = try DataStore.loadFromBundle()
        store.selectedDate = "2024-09-23"
        let routes = try demoRoutes()
        let fake = FakeNotifier()
        let c = AppCoordinator(store: store, location: nil, notifier: fake, routes: routes)
        let start = Date()
        let k = c.alertCount(for: routes[0])
        print("ROUTE1 Sep 23 offline count:", k, "in", Date().timeIntervalSince(start), "s")
        #expect(k > 0)
        try play(routes[0], on: c)
        #expect(fake.sent.count == k)
        #expect(fake.sent.first?.road.displayName == "I-35E")

        // A second drive starts with a fresh engine, so it alerts again, the same way.
        fake.sent = []
        try play(routes[0], on: c)
        #expect(fake.sent.count == k)
    }

    @Test func allRouteCountsMatchTheirDrives() throws {
        let store = try DataStore.loadFromBundle()
        store.selectedDate = "2024-09-23"
        let routes = try demoRoutes()
        let fake = FakeNotifier()
        let c = AppCoordinator(store: store, location: nil, notifier: fake, routes: routes)
        let start = Date()
        let counts = c.alertCounts()
        print("Sep 23 counts:", counts, "in", Date().timeIntervalSince(start), "s")
        #expect(counts.count == routes.count)
        for (i, route) in routes.enumerated() {
            fake.sent = []
            try play(route, on: c)
            #expect(fake.sent.count == counts[i])
        }
    }

    @Test func route5OnAug25IsQuiet() throws {
        let store = try DataStore.loadFromBundle()
        store.selectedDate = "2023-08-25"
        let routes = try demoRoutes()
        let fake = FakeNotifier()
        let c = AppCoordinator(store: store, location: nil, notifier: fake, routes: routes)
        #expect(c.alertCount(for: routes[4]) == 0)
        try play(routes[4], on: c)
        #expect(fake.sent.isEmpty)
    }

    @Test func deviceFixesWaitWhileADriveRuns() throws {
        let store = try DataStore.loadFromBundle()
        store.selectedDate = "2024-09-23"
        let routes = try demoRoutes()
        let fake = FakeNotifier()
        let c = AppCoordinator(store: store, location: nil, notifier: fake, routes: routes)
        c.startDrive(routes[4])
        #expect(c.drive?.isRunning == true)
        let before = fake.sent.count
        // Route 1's start is on I-35E at 65 mph: it would alert at once if it reached the engine.
        for f in DriveSimulator.fixes(for: routes[0]).prefix(10) { c.receive(f, from: .device) }
        #expect(fake.sent.count == before)
        c.endDrive()
        #expect(c.drive == nil)
        // With the drive over, the phone's own fixes count again.
        for f in DriveSimulator.fixes(for: routes[0]).prefix(10) { c.receive(f, from: .device) }
        #expect(fake.sent.first { $0.road.displayName == "I-35E" } != nil)
    }

    @Test func driveWaitsForTheNotificationQuestion() throws {
        let store = try DataStore.loadFromBundle()
        store.selectedDate = "2024-09-23"
        let routes = try demoRoutes()
        let asking = AskingNotifier()
        let c = AppCoordinator(store: store, location: nil, notifier: asking, routes: routes)
        func answer() throws {
            try #require(!asking.waiting.isEmpty)
            asking.waiting.removeFirst()()
        }

        // Route 1 starts on I-35E: no fix may reach the engine before the driver answers.
        c.startDrive(routes[0])
        #expect(asking.waiting.count == 1)
        #expect(c.drive?.isRunning == false)
        #expect(c.drive?.position == nil)
        try answer()
        #expect(c.drive?.isRunning == true)
        #expect(c.drive?.position?.latitude == routes[0].points[0].latitude)
        c.endDrive()

        // A drive ended, or replaced by another, while the question is up never starts.
        c.startDrive(routes[0])
        c.endDrive()
        try answer()
        #expect(c.drive == nil)
        c.startDrive(routes[0])
        c.startDrive(routes[4])
        try answer()
        #expect(c.drive?.route.name == routes[4].name)
        #expect(c.drive?.isRunning == false)
        try answer()
        #expect(c.drive?.isRunning == true)
        c.endDrive()
    }

    @Test func theAppIsCalledRosafe() throws {
        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["CFBundleDisplayName"] as? String == "Rosafe")
        for key in ["NSLocationWhenInUseUsageDescription", "NSLocationAlwaysAndWhenInUseUsageDescription"] {
            let text = try #require(info[key] as? String)
            #expect(text.contains("Rosafe"))
            #expect(!text.contains("Same Rain"))
        }
    }

    @Test func driveShowsPositionAndStops() throws {
        let routes = try demoRoutes()
        let sim = DriveSimulator(route: routes[0])
        var got: [Fix] = []
        var ended = false
        sim.start(onFix: { got.append($0) }, onEnd: { ended = true })
        #expect(sim.isRunning)
        #expect(got.count == 1)
        #expect(sim.position?.latitude == routes[0].points[0].latitude)
        sim.tick()
        #expect(got.count == 2)
        #expect(sim.position?.latitude == routes[0].points[1].latitude)
        sim.stop()
        #expect(!sim.isRunning)
        #expect(sim.position == nil)
        sim.tick()
        #expect(got.count == 2)
        #expect(!ended)  // stopping by hand is not the drive reaching its end
    }
}
