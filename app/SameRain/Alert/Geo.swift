import Foundation
import CoreLocation

nonisolated enum Geo {
    private static let metersPerDegree = 111_320.0

    /// Distance from `p` to the nearest point on any segment of `lines`, and that point.
    /// Local equirectangular projection centered on `p`, so the result is in meters.
    static func distance(from p: CLLocationCoordinate2D, to lines: [[CLLocationCoordinate2D]])
        -> (meters: Double, nearest: CLLocationCoordinate2D) {
        let kx = metersPerDegree * cos(p.latitude * .pi / 180)
        let ky = metersPerDegree
        func xy(_ c: CLLocationCoordinate2D) -> (x: Double, y: Double) {
            ((c.longitude - p.longitude) * kx, (c.latitude - p.latitude) * ky)
        }
        var best = Double.infinity
        var bestPoint = p
        func consider(_ x: Double, _ y: Double) {
            let d = (x * x + y * y).squareRoot()
            if d < best {
                best = d
                bestPoint = CLLocationCoordinate2D(latitude: p.latitude + y / ky,
                                                   longitude: p.longitude + (kx > 0 ? x / kx : 0))
            }
        }
        for line in lines {
            if line.count == 1 { let a = xy(line[0]); consider(a.x, a.y) }
            guard line.count >= 2 else { continue }
            for i in 0..<(line.count - 1) {
                let a = xy(line[i]), b = xy(line[i + 1])
                let dx = b.x - a.x, dy = b.y - a.y
                let len2 = dx * dx + dy * dy
                // Projection of the origin (the car) onto the segment, clamped to its ends.
                let t = len2 > 0 ? min(1, max(0, -(a.x * dx + a.y * dy) / len2)) : 0
                consider(a.x + t * dx, a.y + t * dy)
            }
        }
        return best.isFinite ? (best, bestPoint) : (.infinity, p)
    }

    /// Initial great-circle bearing from `a` to `b`, degrees from north, 0..<360.
    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let p1 = a.latitude * .pi / 180, p2 = b.latitude * .pi / 180
        let dl = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dl) * cos(p2)
        let x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl)
        let deg = atan2(y, x) * 180 / .pi
        return (deg.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
}
