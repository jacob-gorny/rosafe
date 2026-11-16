import Foundation
import CoreLocation

nonisolated struct Fix: Sendable {
    var coordinate: CLLocationCoordinate2D
    /// Meters per second; below 0 means invalid.
    var speed: Double
    /// Degrees from north; below 0 means invalid.
    var course: Double
    var time: Date
    /// Meters; below 0 means invalid.
    var horizontalAccuracy: Double = 5
}

/// Decides, fix by fix, which flagged road to warn about. Pure logic: no location manager, no
/// notifications, no clock (it uses each fix's own time), so tests and simulated drives are exact.
nonisolated struct AlertEngine: Sendable {
    static let minSpeed = 8.9            // m/s, 20 mph
    static let range = 805.0             // m, half a mile
    static let onRoad = 60.0             // m, shapes are approximate
    static let headingLimit = 60.0       // degrees
    static let rearmSeconds = 600.0      // 10 minutes
    static let maxAccuracy = 100.0       // m, fixes less accurate than this are ignored entirely
    static let anchorMinAge = 5.0        // s, derived speed spans at least this long
    static let anchorMaxAge = 30.0       // s, and at most this long
    static let gpsGradeAccuracy = 20.0   // m, speed is only derived between fixes this accurate
    static let displacementFactor = 3.0  // displacement must be this many times the summed accuracy
    static let minCountedAnchors = 3     // fewer old-enough anchors means no derived speed
    static let gateSpeed = 8.9           // m/s, the 20 mph gate an anchor must be able to separate
    static let maxDerivedSpeed = 70.0    // m/s, faster than this is noise
    static let sharedNameRadius = 2_000.0 // m, same-name roads this close share one pass

    private struct State {
        var lastDistance: Double?
        var lastAlert: Date?
        var armed = true
    }

    private var targets: [(road: Road, pred: Double)] = []
    private var states: [String: State] = [:]
    /// Recent accepted fixes, oldest first, for the derived-speed anchor.
    private var history: [Fix] = []

    init() {}

    /// Replaces the target list. Per-road state is kept, so a road that alerted earlier in this
    /// pass does not alert again after a swap.
    mutating func setTargets(_ targets: [(road: Road, pred: Double)]) {
        self.targets = targets
    }

    /// Returns the one road to alert for this fix, if any. Others that qualify wait for later fixes.
    mutating func process(_ fix: Fix) -> (road: Road, pred: Double)? {
        guard fix.horizontalAccuracy >= 0, fix.horizontalAccuracy <= Self.maxAccuracy else { return nil }

        // Speed: the fix's own when valid. When invalid, derive it only between GPS-grade fixes (a
        // parked phone's Wi-Fi or cell fixes jump around), and only when the car has clearly moved.
        var speed: Double? = fix.speed >= 0 ? fix.speed : nil
        if speed == nil { speed = derivedSpeed(for: fix) }
        history.append(fix)
        history.removeAll { fix.time.timeIntervalSince($0.time) > Self.anchorMaxAge }

        var best: (road: Road, pred: Double)?
        for target in targets {
            let id = target.road.id
            var s = states[id] ?? State()
            let near = Geo.distance(from: fix.coordinate, to: target.road.lines)
            let distance = near.meters
            let before = s.lastDistance
            s.lastDistance = distance

            if !s.armed, distance > Self.range, let at = s.lastAlert,
               fix.time.timeIntervalSince(at) >= Self.rearmSeconds {
                s.armed = true
            }

            if s.armed, let speed, speed > Self.minSpeed, distance <= Self.range, isToward(
                fix: fix, distance: distance, before: before, nearest: near.nearest) {
                if best == nil || target.pred > best!.pred { best = target }
            }
            states[id] = s
        }

        if let hit = best {
            // Close roads sharing a display name are one road to a driver: they share this pass.
            for t in targets {
                let same = t.road.id == hit.road.id || (t.road.displayName == hit.road.displayName
                    && Geo.distance(from: fix.coordinate, to: t.road.lines).meters <= Self.sharedNameRadius)
                guard same else { continue }
                var s = states[t.road.id] ?? State()
                s.armed = false
                s.lastAlert = fix.time
                states[t.road.id] = s
            }
        }
        return best
    }

    /// Speed over earlier GPS-grade fixes 5 to 30 s old. An anchor counts only if it is old enough to
    /// tell 20 mph from standing still (8.9 m/s x age >= 3 x summed accuracy); younger ones are skipped.
    /// Every counted anchor must be at least 3 x (summed accuracy) away, else there is no speed. At
    /// least 3 anchors must count. The slowest counted anchor's speed is used, up to 70 m/s.
    private func derivedSpeed(for fix: Fix) -> Double? {
        guard fix.horizontalAccuracy <= Self.gpsGradeAccuracy else { return nil }
        var slowest: Double?
        var counted = 0
        for anchor in history where anchor.horizontalAccuracy <= Self.gpsGradeAccuracy {
            let dt = fix.time.timeIntervalSince(anchor.time)
            guard dt >= Self.anchorMinAge, dt <= Self.anchorMaxAge else { continue }
            let needed = Self.displacementFactor * (fix.horizontalAccuracy + anchor.horizontalAccuracy)
            guard Self.gateSpeed * dt >= needed else { continue }
            let d = Geo.distance(from: fix.coordinate, to: [[anchor.coordinate]]).meters
            guard d >= needed else { return nil }
            counted += 1
            slowest = min(slowest ?? .infinity, d / dt)
        }
        guard counted >= Self.minCountedAnchors, let v = slowest, v <= Self.maxDerivedSpeed else { return nil }
        return v
    }

    private func isToward(fix: Fix, distance: Double, before: Double?, nearest: CLLocationCoordinate2D) -> Bool {
        if distance <= Self.onRoad { return true }
        if let before, distance < before { return true }
        if fix.course >= 0 {
            let b = Geo.bearing(from: fix.coordinate, to: nearest)
            var diff = abs(fix.course - b).truncatingRemainder(dividingBy: 360)
            if diff > 180 { diff = 360 - diff }
            return diff < Self.headingLimit
        }
        return false
    }
}
