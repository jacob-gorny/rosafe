import Foundation

nonisolated struct WhyLine: Equatable, Sendable {
    let title: String
    let detail: String?
}

nonisolated enum SymbolSet: Equatable, Sendable {
    case rain(fog: Bool, thunder: Bool)
    case ice(fog: Bool)
    case dry(fog: Bool)
}

/// One of the three numbers at the top of Daily score: "17 mm" over "rain".
nonisolated struct DayNumber: Equatable, Sendable {
    let value: String
    let label: String
}

/// One of the busiest roads on Daily score: what the model predicted for it and what happened.
/// Each row is one surface stretch of a road (its `actual_level` id), so it carries the surface.
nonisolated struct BusiestRow: Equatable, Sendable {
    let roadId: String
    let name: String
    /// The stretch's surface ("concrete", "asphalt_over_concrete"); nil if the road has none.
    let surface: String?
    let pred: Double
    /// The file's level name without " than normal": "much higher", "about normal".
    let level: String
}

nonisolated enum DayMath {
    static func percent(_ pred: Double) -> Int { Int(((pred - 1) * 100).rounded()) }

    static func percentText(_ pred: Double) -> String { signed(percent(pred)) }

    /// Mean of all roads' scores minus 1, as a whole percent.
    static func dailyScore(_ day: Day) -> Int {
        guard !day.pred.isEmpty else { return 0 }
        return percent(day.pred.reduce(0, +) / Double(day.pred.count))
    }

    static func dailyScoreText(_ day: Day) -> String { signed(dailyScore(day)) }

    /// The line under the daily score: "Above a normal day, across 850 DFW roads".
    static func scoreLine(score: Int, roads: Int) -> String {
        let side = score > 0 ? "Above" : score < 0 ? "Below" : "About"
        return "\(side) a normal day, across \(roads) DFW roads"
    }

    /// Added under the score on rare days (ice): the model has seen few days like it.
    static let rareLine = "Ice is rare, so trust this less"

    private static func signed(_ n: Int) -> String {
        n < 0 ? "\u{2212}\(-n)%" : "+\(n)%"
    }

    static func symbolSet(_ w: Weather, rare: Bool) -> SymbolSet {
        if rare || w.ice { return .ice(fog: w.fog) }
        if w.rainMm >= 0.3 { return .rain(fog: w.fog, thunder: w.thunder) }
        return .dry(fog: w.fog)
    }

    static func surfaceLabel(_ surface: String?) -> String? {
        switch surface {
        case nil: nil
        case "concrete": "Concrete"
        case "asphalt_over_concrete": "Asphalt over concrete"
        case "asphalt": "Asphalt"
        case "surface_treated": "Surface-treated"
        case let other?: other.replacingOccurrences(of: "_", with: " ").capitalizedFirst
        }
    }

    static func checkedLine(_ road: Road) -> String {
        road.checked == "measured" ? "Measured: busy enough to test on its own" : "Estimated from roads built like this one"
    }

    /// Ids of flagged roads that share a display name with another flagged road.
    static func needsSurfaceCaption(_ flagged: [Road]) -> Set<String> {
        var counts: [String: Int] = [:]
        for r in flagged { counts[r.displayName, default: 0] += 1 }
        return Set(flagged.filter { counts[$0.displayName, default: 0] > 1 }.map(\.id))
    }

    // MARK: Daily score: the day's numbers and the busiest roads

    /// Rain, days since rain and the high, as Daily score shows them.
    static func dayNumbers(_ w: Weather) -> [DayNumber] {
        [DayNumber(value: "\(rainText(w.rainMm)) mm", label: "rain"),
         DayNumber(value: "\(w.daysSinceRain)", label: "days since rain"),
         DayNumber(value: "\(w.highF)\u{00B0}F", label: "high")]
    }

    /// Whole millimetres, except a trace under 1 mm keeps its decimal ("0.3"), so a day with a
    /// little rain never reads "0 mm" next to "Rain, 0.3 mm".
    static func rainText(_ mm: Double) -> String {
        mm > 0 && mm < 1 ? String(format: "%.1f", mm) : "\(Int(mm.rounded()))"
    }

    /// "much higher than normal" → "much higher".
    static func shortLevel(_ name: String) -> String {
        name.replacingOccurrences(of: " than normal", with: "")
    }

    /// The roads with an `actual_level` that day (the 5 busiest stretches), highest predicted
    /// score first. Levels are looked up by road id only; a road the app can't name or a level
    /// the file can't name is left out.
    static func busiestRows(_ day: Day, levelNames: [String], name: (String) -> String?,
                            surface: (String) -> String?, pred: (String) -> Double?) -> [BusiestRow] {
        day.actualLevel.compactMap { id, level -> BusiestRow? in
            guard let n = name(id), let p = pred(id), levelNames.indices.contains(level) else { return nil }
            return BusiestRow(roadId: id, name: n, surface: surface(id), pred: p, level: shortLevel(levelNames[level]))
        }
        .sorted { $0.pred != $1.pred ? $0.pred > $1.pred : $0.roadId < $1.roadId }
    }

    // MARK: Why lines

    static func dayFacts(_ day: Day) -> [WhyLine] {
        let w = day.weather
        let airport = "at DFW Airport"
        if day.reasons.isEmpty {
            var out: [WhyLine] = []
            if w.rainMm == 0 {
                out.append(WhyLine(title: "No rain for \(w.daysSinceRain) days",
                                   detail: "Last rain \(airport) was \(lastRain(day))"))
            }
            if w.highF >= 95 {
                out.append(WhyLine(title: "Hot, \(w.highF)\u{00B0}F", detail: "Measured \(airport)"))
            } else {
                out.append(WhyLine(title: "High of \(w.highF)\u{00B0}F", detail: "Low of \(w.lowF)\u{00B0}F \(airport)"))
            }
            return out
        }
        return day.reasons.map { reason in
            if let n = number(in: reason, prefix: "Heavy rain (", suffix: " mm)") {
                return WhyLine(title: "Heavy rain, \(n) mm", detail: "Measured \(airport)")
            }
            if let n = number(in: reason, prefix: "Rain (", suffix: " mm)") {
                return WhyLine(title: "Rain, \(n) mm", detail: "Measured \(airport)")
            }
            if reason.hasPrefix("First rain after ") {
                return WhyLine(title: reason, detail: "Last rain \(airport) was \(lastRain(day))")
            }
            if reason.hasPrefix("Rain after "), reason.hasSuffix(" hot days") {
                // The hot days came before today's rain, so today's high would read as a contradiction.
                return WhyLine(title: reason, detail: "Counted from DFW Airport daily highs")
            }
            switch reason {
            case "Fog", "Heavy fog", "Thunderstorms":
                return WhyLine(title: reason, detail: "Reported \(airport)")
            case "Ice on the roads":
                return WhyLine(title: reason, detail: "High of \(w.highF)\u{00B0}F, low of \(w.lowF)\u{00B0}F \(airport)")
            case "Holiday":
                return WhyLine(title: "Holiday", detail: "A federal holiday or the day after Thanksgiving")
            default:
                return WhyLine(title: reason, detail: nil)
            }
        }
    }

    static func roadWhy(road: Road, pred: Double, day: Day, levelNames: [String]) -> [WhyLine] {
        var out: [WhyLine] = []
        if let first = dayFacts(day).first { out.append(first) }
        if road.surface == "asphalt_over_concrete" {
            out.append(WhyLine(title: "Asphalt laid over concrete",
                               detail: "On first rains this surface jumped more than plain concrete on the same highways (2021 to 2024)"))
        } else if let label = surfaceLabel(road.surface) {
            out.append(WhyLine(title: label + " road", detail: nil))
        }
        var parts: [String] = []
        if let s = road.speedLimit { parts.append("\(s) mph") }
        if let l = road.lanes { parts.append("\(l) lanes") }
        if let t = road.dailyTraffic { parts.append("about \(thousands((t + 500) / 1000 * 1000)) cars a day") }
        if !parts.isEmpty { out.append(WhyLine(title: "How it's built", detail: parts.joined(separator: ", "))) }
        if let level = day.actualLevel[road.id], levelNames.indices.contains(level) {
            out.append(WhyLine(title: "What really happened", detail: levelNames[level].capitalizedFirst))
        }
        return out
    }

    // MARK: Helpers

    private static func number(in s: String, prefix: String, suffix: String) -> String? {
        guard s.hasPrefix(prefix), s.hasSuffix(suffix), s.count > prefix.count + suffix.count else { return nil }
        return String(s.dropFirst(prefix.count).dropLast(suffix.count))
    }

    private static func thousands(_ n: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private static func lastRain(_ day: Day) -> String {
        var cal = Calendar(identifier: .gregorian)
        let utc = TimeZone(identifier: "UTC")!
        cal.timeZone = utc
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = utc
        parser.dateFormat = "yyyy-MM-dd"
        guard let d = parser.date(from: day.date),
              let back = cal.date(byAdding: .day, value: -day.weather.daysSinceRain, to: d) else { return "unknown" }
        parser.dateFormat = "MMM d"
        return parser.string(from: back)
    }
}

private extension String {
    nonisolated var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
