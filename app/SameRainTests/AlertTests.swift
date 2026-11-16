import Testing
import Foundation
import CoreLocation
@testable import SameRain

private let mPerDeg = 111_320.0
private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

private func road(_ id: String, name: String? = nil, lon: Double = -96.80,
                  from lat0: Double = 32.80, to lat1: Double = 32.90) -> Road {
    Road(id: id, layer: "state", displayName: name ?? id, road: id, surface: nil, roadClass: "x",
         speedLimit: nil, lanes: nil, dailyTraffic: nil, busy: false, checked: "",
         lines: [[CLLocationCoordinate2D(latitude: lat0, longitude: lon),
                  CLLocationCoordinate2D(latitude: lat1, longitude: lon)]])
}

private func coord(_ lat: Double, _ lon: Double = -96.80) -> CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: lat, longitude: lon)
}

private func fix(_ lat: Double, lon: Double = -96.80, speed: Double = 29, course: Double = 0, at s: Double,
                 accuracy: Double = 5) -> Fix {
    Fix(coordinate: coord(lat, lon), speed: speed, course: course, time: t0.addingTimeInterval(s),
        horizontalAccuracy: accuracy)
}

/// Latitude `m` meters south of the road's start.
private func south(_ m: Double) -> Double { 32.80 - m / mPerDeg }

private struct Lcg {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 &+ 1 }
    mutating func unit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * unit() }
    /// Standard normal (Box-Muller).
    mutating func gauss() -> Double {
        let u1 = max(unit(), 1e-12), u2 = unit()
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

/// A point `dx` m east and `dy` m north of a spot 100 m east of the road.
private func parked(dx: Double, dy: Double) -> (lat: Double, lon: Double) {
    let kx = mPerDeg * cos(32.85 * .pi / 180)
    return (32.85 + dy / mPerDeg, -96.80 + (100 + dx) / kx)
}

private func parkedRadial(_ rng: inout Lcg, _ lo: Double, _ hi: Double) -> (lat: Double, lon: Double) {
    let r = rng.range(lo, hi), a = rng.range(0, 2 * .pi)
    return parked(dx: r * cos(a), dy: r * sin(a))
}

@Suite struct GeoTests {
    @Test func distanceToSegmentInterior() {
        // East-west line; point 0.01 degree of latitude north of it: about 1,113 m.
        let line = [[coord(32.80, -96.90), coord(32.80, -96.70)]]
        let r = Geo.distance(from: coord(32.81, -96.80), to: line)
        #expect(abs(r.meters - 1113.2) < 1)
        #expect(abs(r.nearest.latitude - 32.80) < 1e-6)
        #expect(abs(r.nearest.longitude + 96.80) < 1e-6)
    }

    @Test func distanceBeyondSegmentEndUsesEndpoint() {
        let line = [[coord(32.80), coord(32.90)]]
        let r = Geo.distance(from: coord(32.79), to: line)
        #expect(abs(r.meters - 1113.2) < 1)
        #expect(abs(r.nearest.latitude - 32.80) < 1e-6)
    }

    @Test func distancePicksNearestOfSeveralLines() {
        let lines = [[coord(32.80, -96.80), coord(32.90, -96.80)],
                     [coord(32.80, -96.70), coord(32.90, -96.70)]]
        let r = Geo.distance(from: coord(32.85, -96.71), to: lines)
        #expect(r.meters < 1000 && r.meters > 900)
    }

    @Test func bearingCardinals() {
        #expect(abs(Geo.bearing(from: coord(32.8), to: coord(32.9))) < 0.01)
        #expect(abs(Geo.bearing(from: coord(32.8), to: coord(32.8, -96.7)) - 90) < 0.1)
        #expect(abs(Geo.bearing(from: coord(32.9), to: coord(32.8)) - 180) < 0.01)
        #expect(abs(Geo.bearing(from: coord(32.8), to: coord(32.8, -96.9)) - 270) < 0.1)
    }
}

@Suite struct AlertTests {
    private func engine(_ roads: [(Road, Double)]) -> AlertEngine {
        var e = AlertEngine()
        e.setTargets(roads.map { (road: $0.0, pred: $0.1) })
        return e
    }

    @Test func firesWhenApproachingFast() {
        var e = engine([(road("A"), 1.5)])
        var fired: [Int] = []
        for i in 0..<30 {
            let m = 1200 - 145.0 * Double(i)
            if e.process(fix(south(m), at: Double(i) * 5)) != nil { fired.append(i) }
        }
        // distances 1200, 1055, 910, 765: the fourth fix is the first within 805 m.
        #expect(fired == [3])
    }

    @Test func firesWhenStartingOnRoad() {
        var e = engine([(road("A"), 1.5)])
        #expect(e.process(fix(32.85, at: 0))?.road.id == "A")

        var e2 = engine([(road("A"), 1.5)])
        // Invalid speed needs 3 aged anchors (5, 10 and 15 s old at 5 s cadence): alert on the fourth fix.
        for i in 0..<3 { #expect(e2.process(fix(32.85 + 145 * Double(i) / mPerDeg, speed: -1, at: Double(i) * 5)) == nil) }
        #expect(e2.process(fix(32.85 + 145 * 3 / mPerDeg, speed: -1, at: 15))?.road.id == "A")
    }

    @Test func quietWhenParked() {
        var e = engine([(road("A"), 1.5)])
        for i in 0..<60 {
            #expect(e.process(fix(32.85, lon: -96.80 + 100 / (mPerDeg * cos(32.85 * .pi / 180)),
                                  speed: 0, at: Double(i) * 5)) == nil)
        }
    }

    @Test func quietWhenWalking() {
        var e = engine([(road("A"), 1.5)])
        for i in 0..<100 {
            let m = 1000 - 7.5 * Double(i)
            #expect(e.process(fix(south(m), speed: 1.5, at: Double(i) * 5)) == nil)
        }
    }

    @Test func quietWhenMovingAway() {
        var e = engine([(road("A"), 1.5)])
        // 300 m east of the road, heading south (course 180), parallel to the road.
        let lon = -96.80 + 300 / (mPerDeg * cos(32.85 * .pi / 180))
        for i in 0..<20 {
            let lat = 32.80 - 145 * Double(i) / mPerDeg
            #expect(e.process(fix(lat, lon: lon, speed: 29, course: 180, at: Double(i) * 5)) == nil)
        }
        // Heading away along the road's line from its south end: distance grows.
        var e2 = engine([(road("A"), 1.5)])
        for i in 0..<10 {
            let lat = south(700 + 145 * Double(i))
            #expect(e2.process(fix(lat, speed: 29, course: 180, at: Double(i) * 5)) == nil)
        }
    }

    @Test func onePerPass() {
        var e = engine([(road("A"), 1.5)])
        var alerts = 0
        var t = 0.0
        // 20 minutes along the road (about 34.8 km, longer than the road: bounce along it).
        for i in 0..<240 {
            let lat = 32.81 + 0.07 * (Double(i % 100) / 100)
            if e.process(fix(lat, at: t)) != nil { alerts += 1 }
            t += 5
        }
        #expect(alerts == 1)
        // Leave to 1,000 m, wait 11 minutes there, come back: a second alert.
        let far = south(1000)
        for _ in 0..<132 { _ = e.process(fix(far, speed: 29, course: 180, at: t)); t += 5 }
        var second = 0
        for i in 0..<10 {
            if e.process(fix(far + 145 * Double(i + 1) / mPerDeg, at: t)) != nil { second += 1 }
            t += 5
        }
        #expect(second == 1)

        // Leave to 1,000 m but come back after 3 minutes: no new alert.
        var e2 = engine([(road("A"), 1.5)])
        var t2 = 0.0
        #expect(e2.process(fix(32.85, at: t2)) != nil)
        t2 += 5
        for _ in 0..<36 { #expect(e2.process(fix(far, speed: 29, course: 180, at: t2)) == nil); t2 += 5 }
        for i in 0..<20 {
            #expect(e2.process(fix(far + 145 * Double(i + 1) / mPerDeg, at: t2)) == nil)
            t2 += 5
        }
    }

    @Test func invalidSpeedUsesDerived() {
        var e = engine([(road("A"), 1.5)])
        var fired: [Int] = []
        for i in 0..<12 {
            let m = 1200 - 145.0 * Double(i)
            if e.process(fix(south(m), speed: -1, at: Double(i) * 5)) != nil { fired.append(i) }
        }
        #expect(fired == [3])
    }

    @Test func invalidSpeedAndSlowDerivedIsQuiet() {
        var e = engine([(road("A"), 1.5)])
        for i in 0..<30 {
            #expect(e.process(fix(south(700 - 5.0 * Double(i)), speed: -1, at: Double(i) * 5)) == nil)
        }
    }

    @Test func highestPredFirst() {
        let a = road("A", lon: -96.8000)
        let b = road("B", lon: -96.8003)
        var e = engine([(a, 1.2), (b, 1.9)])
        let f = { (s: Double) in fix(32.85 + s * 145 / mPerDeg, at: s * 5) }
        #expect(e.process(f(0))?.road.id == "B")
        #expect(e.process(f(1))?.road.id == "A")
        #expect(e.process(f(2)) == nil)
    }

    @Test func sameNameSharesPass() {
        let a = road("A", name: "I-635", lon: -96.8000)
        let b = road("B", name: "I-635", lon: -96.8003)
        var e = engine([(a, 1.9), (b, 1.2)])
        #expect(e.process(fix(32.85, at: 0))?.road.id == "A")
        for i in 1..<6 {
            #expect(e.process(fix(32.85 + Double(i) * 145 / mPerDeg, at: Double(i) * 5)) == nil)
        }
    }

    @Test func sameNameFarAwayDoesNotShare() {
        let a = road("A", name: "Main St", from: 32.80, to: 32.90)
        let b = road("B", name: "Main St", from: 33.10, to: 33.20)   // about 22 km north
        var e = engine([(a, 1.5), (b, 1.4)])
        #expect(e.process(fix(32.85, at: 0))?.road.id == "A")
        #expect(e.process(fix(33.15, at: 10))?.road.id == "B")
    }

    @Test func quietWhenParkedWithInvalidSpeedJitter() {
        var bad: [UInt64] = []
        for seed in 1...1000 {
            var rng = Lcg(seed: UInt64(seed))
            var e = engine([(road("A"), 1.5)])
            for i in 0..<120 {
                let dx = rng.range(30, 60) * (rng.unit() < 0.5 ? -1 : 1)
                let dy = rng.range(30, 60) * (rng.unit() < 0.5 ? -1 : 1)
                let p = parked(dx: dx, dy: dy)
                if e.process(fix(p.lat, lon: p.lon, speed: -1, course: -1, at: Double(i), accuracy: 30)) != nil {
                    bad.append(UInt64(seed)); break
                }
            }
        }
        #expect(bad.isEmpty, "seeds that fired: \(bad.count)")
    }

    @Test func quietWhenParkedGPSJitter() {
        var bad: [UInt64] = []
        for seed in 1...1000 {
            var rng = Lcg(seed: UInt64(seed))
            var e = engine([(road("A"), 1.5)])
            for i in 0..<120 {
                let p = parkedRadial(&rng, 10, 25)
                if e.process(fix(p.lat, lon: p.lon, speed: -1, course: -1, at: Double(i), accuracy: 10)) != nil {
                    bad.append(UInt64(seed)); break
                }
            }
        }
        #expect(bad.isEmpty, "seeds that fired: \(bad.count)")
    }

    @Test func quietWhenParkedSparse() {
        var bad: [UInt64] = []
        for seed in 1...1000 {
            var rng = Lcg(seed: UInt64(seed))
            var e = engine([(road("A"), 1.5)])
            var t = 0.0
            for _ in 0..<60 {
                t += rng.range(6, 20)
                let p = parkedRadial(&rng, 10, 25)
                if e.process(fix(p.lat, lon: p.lon, speed: -1, course: -1, at: t, accuracy: 10)) != nil {
                    bad.append(UInt64(seed)); break
                }
            }
        }
        #expect(bad.isEmpty, "seeds that fired: \(bad.count)")
    }

    /// A drive toward the road from 1.5 km with speed and course invalid and AR(1)-correlated noise
    /// (sigma = accuracy / 2). Counts seeds that alerted in time (>= 400 m out), late, or never.
    private func noisyDrive(speed: Double, accuracy: Double) -> (inTime: Int, late: Int, never: Int) {
        var inTime = 0, late = 0, never = 0
        let sigma = accuracy / 2, phi = 0.8
        for seed in 1...1000 {
            var rng = Lcg(seed: UInt64(seed))
            var e = engine([(road("A"), 1.5)])
            var ex = sigma * rng.gauss(), ey = sigma * rng.gauss()
            var alertedAt: Double?
            for i in 0..<120 {
                let m = 1500 - speed * Double(i)
                if m < -200 { break }
                ex = phi * ex + sigma * (1 - phi * phi).squareRoot() * rng.gauss()
                ey = phi * ey + sigma * (1 - phi * phi).squareRoot() * rng.gauss()
                let lat = south(m) + ey / mPerDeg
                let lon = -96.80 + ex / (mPerDeg * cos(32.8 * .pi / 180))
                if e.process(fix(lat, lon: lon, speed: -1, course: -1, at: Double(i), accuracy: accuracy)) != nil {
                    alertedAt = m; break
                }
            }
            if let m = alertedAt { if m >= 400 { inTime += 1 } else { late += 1 } } else { never += 1 }
        }
        return (inTime, late, never)
    }

    @Test(arguments: [10.0, 15.0, 20.0])
    func cityDriveInvalidSpeedAlerts(accuracy: Double) {
        let r = noisyDrive(speed: 13.4, accuracy: accuracy)
        print("CITY acc=\(Int(accuracy)) inTime/late/never = \(r.inTime)/\(r.late)/\(r.never)")
        #expect(r.inTime >= 985)
    }

    @Test(arguments: [10.0, 15.0, 20.0])
    func highwayDriveInvalidSpeedAlerts(accuracy: Double) {
        let r = noisyDrive(speed: 29, accuracy: accuracy)
        print("HIGHWAY acc=\(Int(accuracy)) inTime/late/never = \(r.inTime)/\(r.late)/\(r.never)")
        #expect(r.inTime >= 985)
    }

    @Test func quietWhenParkedGaussian() {
        var bad = 0
        for seed in 1...1000 {
            var rng = Lcg(seed: UInt64(seed))
            var e = engine([(road("A"), 1.5)])
            for i in 0..<120 {
                let p = parked(dx: 20 * rng.gauss(), dy: 20 * rng.gauss())
                if e.process(fix(p.lat, lon: p.lon, speed: -1, course: -1, at: Double(i), accuracy: 20)) != nil {
                    bad += 1; break
                }
            }
        }
        #expect(bad == 0, "seeds that fired: \(bad)")
    }

    @Test func ignoresInaccurateFixes() {
        var e0 = engine([(road("A"), 1.5)])
        for i in 0..<30 {
            let m = 1200 - 145.0 * Double(i)
            #expect(e0.process(fix(south(m), at: Double(i) * 5, accuracy: 150)) == nil)
        }
        var e2 = engine([(road("A"), 1.5)])
        #expect(e2.process(fix(32.85, at: 0, accuracy: -1)) == nil)

        // Inaccurate fixes with invalid speed must not become anchors for a later accurate fix.
        var e3 = engine([(road("A"), 1.5)])
        for i in 0..<10 {
            #expect(e3.process(fix(32.85 - 0.002, speed: -1, at: Double(i) * 2, accuracy: 150)) == nil)
        }
        #expect(e3.process(fix(32.85, speed: -1, at: 20, accuracy: 5)) == nil)

        // Probe: an inaccurate fix must not touch lastDistance. Good fix 700 m out, inaccurate fix at
        // 650 m (ignored), good fix at 680 m: the distance fell from 700, so it alerts.
        var e4 = engine([(road("A"), 1.5)])
        #expect(e4.process(fix(south(700), course: 180, at: 0)) == nil)
        #expect(e4.process(fix(south(650), course: 180, at: 5, accuracy: 150)) == nil)
        #expect(e4.process(fix(south(680), course: 180, at: 10))?.road.id == "A")
    }

    @Test func targetsSwapMidDrive() {
        let a = road("A")
        var e = engine([(a, 1.5)])
        #expect(e.process(fix(32.85, at: 0)) != nil)
        e.setTargets([(road: a, pred: 1.5), (road: road("C", lon: -96.9), pred: 1.1)])
        #expect(e.process(fix(32.851, at: 5)) == nil)
        #expect(e.process(fix(32.852, at: 10)) == nil)
    }

    @Test func courseTowardRoadFiresEvenOnFirstFix() {
        // Road east of the car; heading east (90) at 700 m: bearing to nearest point is east.
        let r = road("A")
        let lon = -96.80 - 700 / (mPerDeg * cos(32.85 * .pi / 180))
        var e = engine([(r, 1.5)])
        #expect(e.process(fix(32.85, lon: lon, speed: 29, course: 90, at: 0))?.road.id == "A")
        // Same place, heading west (270): not toward.
        var e2 = engine([(r, 1.5)])
        #expect(e2.process(fix(32.85, lon: lon, speed: 29, course: 270, at: 0)) == nil)
    }
}

// MARK: - Real routes

private func runRoute(_ route: DemoRoute, targets: [(road: Road, pred: Double)], useValidSpeed: Bool)
    -> [(index: Int, id: String, name: String)] {
    var e = AlertEngine()
    e.setTargets(targets)
    var out: [(Int, String, String)] = []
    for i in route.points.indices {
        let j = i + 1 < route.points.count ? i + 1 : i
        let k = i + 1 < route.points.count ? i : i - 1
        let course = k >= 0 && j != k ? Geo.bearing(from: route.points[k], to: route.points[j]) : -1
        let f = Fix(coordinate: route.points[i], speed: useValidSpeed ? 29 : -1,
                    course: useValidSpeed ? course : -1, time: route.times[i])
        if let hit = e.process(f) { out.append((i, hit.road.id, hit.road.displayName)) }
    }
    return out
}

@MainActor
@Suite struct RealRouteTests {
    private func routes() throws -> [DemoRoute] {
        let url = try #require(Bundle.main.url(forResource: "data", withExtension: nil))
        return try DemoRoutes.load(from: url.appending(path: "routes.gpx"))
    }

    @Test func route1OnDec15() throws {
        let store = try DataStore.loadFromBundle()
        store.selectedDate = "2023-12-15"
        let targets = store.flagged
        let route = try routes()[0]
        for valid in [false, true] {
            let alerts = runRoute(route, targets: targets, useValidSpeed: valid)
            print("ROUTE1 valid=\(valid):", alerts.map { "\($0.index)@\(Int(route.times[$0.index].timeIntervalSince(route.times[0])))s \($0.name)" })
            #expect(alerts.contains { $0.name == "I-35E" })
            let first = try #require(alerts.first)
            #expect(route.times[first.index].timeIntervalSince(route.times[0]) <= 30)
            // A road may alert again only on a genuinely new pass: at least 10 minutes later.
            // (US 77 does: the drive leaves it, then reaches it again about 13 minutes after.)
            var lastAt: [String: Date] = [:]
            for a in alerts {
                let t = route.times[a.index]
                if let prev = lastAt[a.id] { #expect(t.timeIntervalSince(prev) >= 600) }
                lastAt[a.id] = t
            }
        }
    }

    @Test func route5OnAug25() throws {
        let store = try DataStore.loadFromBundle()
        store.selectedDate = "2023-08-25"
        let targets = store.flagged
        #expect(targets.isEmpty)
        let route = try routes()[4]
        #expect(runRoute(route, targets: targets, useValidSpeed: true).isEmpty)
        #expect(runRoute(route, targets: targets, useValidSpeed: false).isEmpty)
    }

    @Test func route5OnDec15CountsFlaggedPasses() throws {
        let store = try DataStore.loadFromBundle()
        store.selectedDate = "2023-12-15"
        let route = try routes()[4]
        let alerts = runRoute(route, targets: store.flagged, useValidSpeed: true)
        print("ROUTE5 Dec15:", alerts.map { "\($0.index) \($0.name)" })
        #expect(alerts.count >= 1)
        #expect(Set(alerts.map(\.id)).count == alerts.count)  // no road twice on this 20-minute drive
        var lastAt: [String: Date] = [:]
        for a in alerts {
            let t = route.times[a.index]
            if let prev = lastAt[a.name] { #expect(t.timeIntervalSince(prev) >= 600) }
            lastAt[a.name] = t
        }
    }
}
