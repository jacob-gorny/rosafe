import Foundation
import CoreLocation

nonisolated struct DemoRoute: Sendable {
    let name: String
    /// The road the drive follows, from the track description ("I-35E").
    let label: String
    let points: [CLLocationCoordinate2D]
    let times: [Date]
}

nonisolated enum DemoRoutes {
    static func load(from url: URL) throws -> [DemoRoute] {
        let data = try Data(contentsOf: url)
        let parser = XMLParser(data: data)
        let handler = GPXHandler()
        parser.delegate = handler
        let ok = parser.parse()
        if let bad = handler.badTime {
            throw DataError.badFile("routes.gpx", "a track point has an unreadable time (\(bad))")
        }
        guard ok else {
            throw DataError.badFile("routes.gpx", parser.parserError?.localizedDescription ?? "not valid GPX")
        }
        return handler.routes
    }

    private final class GPXHandler: NSObject, XMLParserDelegate {
        var routes: [DemoRoute] = []
        private var name = "", desc = ""
        private var points: [CLLocationCoordinate2D] = []
        private var times: [Date] = []
        private var text = ""
        private var inPoint = false
        var badTime: String?
        private let iso = ISO8601DateFormatter()
        private let isoFraction: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()

        func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String]) {
            text = ""
            switch element {
            case "trk": name = ""; desc = ""; points = []; times = []
            case "trkpt":
                inPoint = true
                if let lat = attributes["lat"].flatMap(Double.init), let lon = attributes["lon"].flatMap(Double.init) {
                    points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                }
            default: break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

        func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
            switch element {
            case "name": if !inPoint { name = text.trimmingCharacters(in: .whitespacesAndNewlines) }
            case "desc": desc = text.trimmingCharacters(in: .whitespacesAndNewlines)
            case "time":
                guard inPoint else { break }
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let d = iso.date(from: t) ?? isoFraction.date(from: t) {
                    times.append(d)
                } else {
                    badTime = t
                    parser.abortParsing()
                }
            case "trkpt":
                inPoint = false
                if times.count != points.count { badTime = "missing"; parser.abortParsing() }
            case "trk":
                routes.append(DemoRoute(name: name, label: Self.label(from: desc), points: points, times: times))
            default: break
            }
        }

        private static func label(from desc: String) -> String {
            guard let r = desc.range(of: "drives ") else { return "" }
            let rest = desc[r.upperBound...]
            return String(rest.prefix { $0 != ";" }).trimmingCharacters(in: .whitespaces)
        }
    }
}
