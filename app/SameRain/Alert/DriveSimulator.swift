import Foundation
import CoreLocation
import Observation

/// Replays a demo route from `routes.gpx` through the real alert code, at 5 times real speed:
/// one fix per wall-clock second, each fix one route point (the points are 5 s apart).
///
/// Each fix carries the route's own GPX time, so the engine sees fixes 5 s apart, as on a real
/// drive. That time is never used to pick a day: the day comes only from the day picker.
///
/// The timer runs on the main run loop. If the app goes to the background the drive keeps going
/// only while iOS keeps the app running (it does while real location updates run in the background);
/// otherwise it pauses until the app comes back.
@Observable
final class DriveSimulator {
    let route: DemoRoute
    /// Where the simulated car is now; nil when the drive isn't running.
    private(set) var position: CLLocationCoordinate2D?
    private(set) var isRunning = false

    @ObservationIgnored private let fixes: [Fix]
    @ObservationIgnored private var next = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var onFix: ((Fix) -> Void)?
    @ObservationIgnored private var onEnd: (() -> Void)?

    init(route: DemoRoute) {
        self.route = route
        self.fixes = Self.fixes(for: route)
    }

    /// The fixes a drive sends, one per route point: the point's GPX time, a valid speed from the
    /// distance to the next point over the time between them, the course toward the next point
    /// (the last point keeps the last leg's), and GPS-grade accuracy (5 m).
    nonisolated static func fixes(for route: DemoRoute) -> [Fix] {
        let p = route.points, t = route.times
        guard p.count == t.count else { return [] }
        return p.indices.map { i in
            // The leg this point starts, or for the last point the leg that ends there.
            let (a, b) = p.count < 2 ? (i, i) : (i + 1 < p.count ? (i, i + 1) : (i - 1, i))
            let dt = t[b].timeIntervalSince(t[a])
            let meters = Geo.distance(from: p[a], to: [[p[b]]]).meters
            let speed = a != b && dt > 0 ? meters / dt : -1
            let course = a != b && meters > 0 ? Geo.bearing(from: p[a], to: p[b]) : -1
            return Fix(coordinate: p[i], speed: speed, course: course, time: t[i], horizontalAccuracy: 5)
        }
    }

    /// Starts from the first point: one fix now, then one a second. `onEnd` runs once the last
    /// point has been shown for a second; it does not run when the drive is stopped by hand.
    func start(onFix: @escaping (Fix) -> Void, onEnd: @escaping () -> Void = {}) {
        stop()
        self.onFix = onFix
        self.onEnd = onEnd
        next = 0
        isRunning = true
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                // A drive that is gone takes its timer with it.
                guard let self else { timer.invalidate(); return }
                self.tick()
            }
        }
        // Common modes, so the drive keeps moving while the map is being dragged.
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    /// One step: the next point's fix, or the end of the drive. The timer calls this every second.
    func tick() {
        guard isRunning else { return }
        guard next < fixes.count else {
            let end = onEnd
            stop()
            end?()
            return
        }
        let fix = fixes[next]
        next += 1
        position = fix.coordinate
        onFix?(fix)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        position = nil
        onFix = nil
        onEnd = nil
    }
}

/// The words around a simulated drive.
nonisolated enum DriveCopy {
    /// Under the map while a drive runs. Always says it is simulated (the video shows it).
    static let running = "Simulated drive \u{00B7} 65 mph"

    /// Under a route in the picker: what that drive will do on the selected day.
    static func alertsLine(_ k: Int) -> String { k == 1 ? "1 alert today" : "\(k) alerts today" }
}
