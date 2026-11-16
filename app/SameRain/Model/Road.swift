import Foundation
import CoreLocation

/// One road from `roads.geojson`.
nonisolated struct Road: Identifiable, Sendable {
    let id: String
    let layer: String
    let displayName: String
    let road: String
    let surface: String?
    let roadClass: String
    let speedLimit: Int?
    let lanes: Int?
    let dailyTraffic: Int?
    let busy: Bool
    let checked: String
    let lines: [[CLLocationCoordinate2D]]
}

nonisolated enum RoadsFile {
    private struct Collection: Decodable { let features: [Feature] }
    private struct Feature: Decodable {
        let geometry: Geometry
        let properties: Properties
    }
    private struct Geometry: Decodable { let coordinates: [[[Double]]] }
    private struct Properties: Decodable {
        let id: String
        let layer: String
        let displayName: String
        let road: String
        let surface: String?
        let roadClass: String
        let speedLimit: Double?
        let lanes: Double?
        let dailyTraffic: Double?
        let busy: Bool
        let checked: String

        enum CodingKeys: String, CodingKey {
            case id, layer, road, surface, lanes, busy, checked
            case displayName = "display_name"
            case roadClass = "road_class"
            case speedLimit = "speed_limit"
            case dailyTraffic = "daily_traffic"
        }
    }

    static func decode(_ data: Data) throws -> [Road] {
        let collection = try JSONDecoder().decode(Collection.self, from: data)
        return collection.features.map { f in
            let p = f.properties
            let lines = f.geometry.coordinates.map { line in
                line.compactMap { pt -> CLLocationCoordinate2D? in
                    guard pt.count >= 2 else { return nil }
                    return CLLocationCoordinate2D(latitude: pt[1], longitude: pt[0])
                }
            }
            return Road(id: p.id, layer: p.layer, displayName: p.displayName, road: p.road,
                        surface: p.surface, roadClass: p.roadClass,
                        speedLimit: p.speedLimit.map { Int($0.rounded()) },
                        lanes: p.lanes.map { Int($0.rounded()) },
                        dailyTraffic: p.dailyTraffic.map { Int($0.rounded()) },
                        busy: p.busy, checked: p.checked, lines: lines)
        }
    }
}
