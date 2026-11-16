import Foundation

nonisolated struct Weather: Decodable, Sendable {
    let rainMm: Double
    let daysSinceRain: Int
    let highF: Int
    let lowF: Int
    let thunder: Bool
    let fog: Bool
    let ice: Bool
    let freezing: Bool

    enum CodingKeys: String, CodingKey {
        case rainMm = "rain_mm", daysSinceRain = "days_since_rain", highF = "high_f", lowF = "low_f"
        case thunder, fog, ice, freezing
    }
}

nonisolated struct Day: Decodable, Sendable {
    let date: String
    let weather: Weather
    let reasons: [String]
    let rare: Bool
    let pred: [Double]
    let alert: [Int]
    let actualLevel: [String: Int]

    enum CodingKeys: String, CodingKey {
        case date, weather, reasons, rare, pred, alert
        case actualLevel = "actual_level"
    }
}

/// Mirrors `docs/app-data-contract.md`. Explicit keys on purpose: a snake-case
/// key strategy would also rewrite the road ids used as `actual_level` keys.
nonisolated struct ScoresFile: Decodable, Sendable {
    let version: Int
    let year: Int
    let model: String
    let madeUp: Bool
    let alertThreshold: Double
    let alertTopShare: Double
    let alertWeatherOnly: Bool?
    let actualLevelNames: [String]
    let roadIds: [String]
    let days: [Day]

    enum CodingKeys: String, CodingKey {
        case version, year, model, days
        case madeUp = "made_up"
        case alertThreshold = "alert_threshold"
        case alertTopShare = "alert_top_share"
        case alertWeatherOnly = "alert_weather_only"
        case actualLevelNames = "actual_level_names"
        case roadIds = "road_ids"
    }
}
