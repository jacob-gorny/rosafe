import Testing
import Foundation
import CoreLocation
@testable import SameRain

@MainActor
private func freshStore() throws -> DataStore {
    try DataStore.loadFromBundle()
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private func day(_ json: String) throws -> Day {
    try JSONDecoder().decode(Day.self, from: Data(json.utf8))
}

@MainActor
@Suite struct DataTests {

    @Test func loadsRealFiles() throws {
        let store = try freshStore()
        #expect(store.roads.count == 850)
        let file = try #require(store.years.first)
        #expect(file.days.count == 365)
        #expect(Set(file.roadIds) == Set(store.roads.map(\.id)))
        for id in file.roadIds { #expect(store.roadIndex[id] != nil) }
        #expect(file.alertThreshold == 1.14)
        #expect(file.alertTopShare == 0.15)
        #expect(file.actualLevelNames.count == 5)
    }

    @Test func headerAcceptsAlertWeatherOnly() throws {
        let json = """
        {"version":1,"year":2024,"model":"D","made_up":false,"alert_threshold":1.14,"alert_top_share":0.15,
         "alert_weather_only":true,"actual_level_names":["a"],"road_ids":["x"],"days":[]}
        """
        let f = try JSONDecoder().decode(ScoresFile.self, from: Data(json.utf8))
        #expect(f.alertWeatherOnly == true)
        #expect(f.year == 2024)
        // The bundled 2023 file carries the flag since Drop 2.2.
        let bundled = try #require(try freshStore().years.first)
        #expect(bundled.alertWeatherOnly == true)
    }

    @Test func defaultDateFallsBackToLatestYear() throws {
        let road = try RoadsFile.decode(Data("""
        {"features":[{"geometry":{"coordinates":[[[-96.8,32.8],[-96.7,32.8]]]},"properties":{"id":"x","layer":"state",
        "display_name":"X","road":"X","surface":null,"road_class":"interstate","speed_limit":null,"lanes":null,
        "daily_traffic":null,"busy":false,"checked":"estimated"}}]}
        """.utf8))
        func file(_ year: Int, _ dates: [String]) throws -> ScoresFile {
            let days = dates.map { """
            {"date":"\($0)","weather":{"rain_mm":0,"days_since_rain":1,"high_f":70,"low_f":50,"thunder":false,"fog":false,"ice":false,"freezing":false},
             "reasons":[],"rare":false,"pred":[1.0],"alert":[],"actual_level":{}}
            """ }.joined(separator: ",")
            return try JSONDecoder().decode(ScoresFile.self, from: Data("""
            {"version":1,"year":\(year),"model":"D","made_up":false,"alert_threshold":1.1,"alert_top_share":0.15,
             "actual_level_names":[],"road_ids":["x"],"days":[\(days)]}
            """.utf8))
        }
        let only2024 = try DataStore(roads: road, years: [file(2024, ["2024-01-01", "2024-01-02"])])
        #expect(only2024.selectedDate == "2024-01-01")
        #expect(only2024.day != nil)
        let both = try DataStore(roads: road, years: [file(2023, ["2023-12-15"]), file(2024, ["2024-01-01"])])
        #expect(both.selectedDate == "2023-12-15")
    }

    @Test func dailyScoreMatchesFile() throws {
        let store = try freshStore()
        func score(_ d: String) throws -> Int {
            store.selectedDate = d
            return DayMath.dailyScore(try #require(store.day))
        }
        #expect(try score("2023-12-15") == 28)
        #expect(try score("2023-08-25") == -15)
        #expect(try score("2023-01-30") == 35)
    }

    @Test func percentRounds() throws {
        #expect(DayMath.percent(2.09) == 109)
        #expect(DayMath.percent(1.89) == 89)
        #expect(DayMath.percent(0.85) == -15)
    }

    @Test func percentText() throws {
        #expect(DayMath.percentText(2.09) == "+109%")
        #expect(DayMath.percentText(1.0) == "+0%")
        #expect(DayMath.percentText(0.85) == "\u{2212}15%")
    }

    @Test func flaggedOrderAndEmpty() throws {
        let store = try freshStore()
        store.selectedDate = "2023-12-15"
        #expect(store.flagged.count == 127)
        #expect(store.flagged.first?.road.displayName == "US 175")
        #expect(store.flagged.first?.road.id == "state-us175-asphalt_over_concrete")
        #expect(store.flagged.first?.pred == 2.09)
        #expect(store.flagged.map(\.pred) == store.flagged.map(\.pred).sorted(by: >))
        store.selectedDate = "2023-08-25"
        #expect(store.flagged.isEmpty)
    }

    @Test func appTest2SameNumbers() throws {
        let store = try freshStore()
        let url = try #require(Bundle.main.url(forResource: "data", withExtension: nil))
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: url.appending(path: "scores_2023.json"))) as! [String: Any]
        let ids = raw["road_ids"] as! [String]
        let days = raw["days"] as! [[String: Any]]
        var rng = SeededGenerator(state: 42)
        for _ in 0..<5 {
            let r = Int.random(in: 0..<ids.count, using: &rng)
            let d = Int.random(in: 0..<days.count, using: &rng)
            let date = days[d]["date"] as! String
            let want = (days[d]["pred"] as! [NSNumber])[r].doubleValue
            let got = try #require(store.pred(roadId: ids[r], date: date))
            #expect(abs(got - want) < 1e-12)
        }
        #expect(store.pred(roadId: "nope", date: "2023-12-15") == nil)
        #expect(store.pred(roadId: ids[0], date: "1999-01-01") == nil)
    }

    @Test func symbolSets() throws {
        let store = try freshStore()
        func sym(_ d: String) throws -> SymbolSet {
            store.selectedDate = d
            let day = try #require(store.day)
            return DayMath.symbolSet(day.weather, rare: day.rare)
        }
        #expect(try sym("2023-12-15") == .rain(fog: true, thunder: false))
        #expect(try sym("2023-01-30") == .ice(fog: true))
        #expect(try sym("2023-08-25") == .dry(fog: false))
        #expect(try sym("2023-10-25") == .rain(fog: true, thunder: true))
    }

    @Test func surfaceCaptionForDuplicates() throws {
        let store = try freshStore()
        store.selectedDate = "2023-12-15"
        let caption = DayMath.needsSurfaceCaption(store.flagged.map(\.road))
        #expect(caption.contains("state-us75-concrete"))
        #expect(caption.contains("state-us75-asphalt_over_concrete"))
    }

    @Test func roadWhyUS175() throws {
        let store = try freshStore()
        store.selectedDate = "2023-12-15"
        let day = try #require(store.day)
        let names = try #require(store.years.first).actualLevelNames
        let us175 = store.roads[try #require(store.roadIndex["state-us175-asphalt_over_concrete"])]
        let why = DayMath.roadWhy(road: us175, pred: 2.09, day: day, levelNames: names)
        #expect(why.contains(WhyLine(title: "Asphalt laid over concrete",
            detail: "On first rains this surface jumped more than plain concrete on the same highways (2021 to 2024)")))
        #expect(why.contains(WhyLine(title: "How it's built", detail: "70 mph, 4 lanes, about 76,000 cars a day")))
        #expect(why.first == WhyLine(title: "First rain after 14 dry days", detail: "Last rain at DFW Airport was Nov 30"))
        #expect(why.count <= 4)

        let i35 = store.roads[try #require(store.roadIndex["state-ih35e-asphalt_over_concrete"])]
        let why35 = DayMath.roadWhy(road: i35, pred: 2.0, day: day, levelNames: names)
        #expect(why35.contains(WhyLine(title: "What really happened", detail: "Far higher than normal")))
        #expect(why35.count <= 4)
    }

    @Test func roadWhyOtherSurfaceAndMissingParts() throws {
        let store = try freshStore()
        store.selectedDate = "2023-12-15"
        let day = try #require(store.day)
        let concrete = store.roads[try #require(store.roadIndex["state-ih30-concrete"])]
        let why = DayMath.roadWhy(road: concrete, pred: 1.5, day: day, levelNames: ["a", "b", "c", "d", "e"])
        #expect(why.contains(WhyLine(title: "Concrete road", detail: nil)))
        // A road with no surface gets no surface line.
        let noSurface = try #require(store.roads.first { $0.surface == nil })
        let whyNone = DayMath.roadWhy(road: noSurface, pred: 1.5, day: day, levelNames: ["a", "b", "c", "d", "e"])
        #expect(!whyNone.contains { $0.title.hasSuffix(" road") || $0.title == "Asphalt laid over concrete" })
    }

    @Test func dayFactsFromReasons() throws {
        let store = try freshStore()
        store.selectedDate = "2023-12-15"
        #expect(DayMath.dayFacts(try #require(store.day)) == [
            WhyLine(title: "First rain after 14 dry days", detail: "Last rain at DFW Airport was Nov 30"),
            WhyLine(title: "Heavy rain, 15 mm", detail: "Measured at DFW Airport"),
            WhyLine(title: "Fog", detail: "Reported at DFW Airport"),
        ])
        store.selectedDate = "2023-01-30"
        #expect(DayMath.dayFacts(try #require(store.day)) == [
            WhyLine(title: "Ice on the roads", detail: "High of 30\u{00B0}F, low of 26\u{00B0}F at DFW Airport"),
            WhyLine(title: "Rain, 0.3 mm", detail: "Measured at DFW Airport"),
            WhyLine(title: "Fog", detail: "Reported at DFW Airport"),
        ])
        store.selectedDate = "2023-10-25"
        let thunderDay = try #require(store.day)
        let second = try #require(DayMath.dayFacts(thunderDay).dropFirst().first)
        #expect(second == WhyLine(title: "Thunderstorms", detail: "Reported at DFW Airport"))
    }

    @Test func dayFactsWithoutReasons() throws {
        let store = try freshStore()
        store.selectedDate = "2023-08-25"
        #expect(DayMath.dayFacts(try #require(store.day)) == [
            WhyLine(title: "No rain for 40 days", detail: "Last rain at DFW Airport was Jul 16"),
            WhyLine(title: "Hot, 110\u{00B0}F", detail: "Measured at DFW Airport"),
        ])
        let mild = try day("""
        {"date":"2023-04-02","weather":{"rain_mm":0,"days_since_rain":3,"high_f":72,"low_f":50,"thunder":false,"fog":false,"ice":false,"freezing":false},
         "reasons":[],"rare":false,"pred":[],"alert":[],"actual_level":{}}
        """)
        #expect(DayMath.dayFacts(mild) == [
            WhyLine(title: "No rain for 3 days", detail: "Last rain at DFW Airport was Mar 30"),
            WhyLine(title: "High of 72\u{00B0}F", detail: "Low of 50\u{00B0}F at DFW Airport"),
        ])
    }

    @Test func otherReasonCopy() throws {
        let d = try day("""
        {"date":"2023-07-04","weather":{"rain_mm":2.0,"days_since_rain":1,"high_f":99,"low_f":78,"thunder":false,"fog":false,"ice":false,"freezing":false},
         "reasons":["Rain after 4 hot days","Holiday","Something new"],"rare":false,"pred":[],"alert":[],"actual_level":{}}
        """)
        #expect(DayMath.dayFacts(d) == [
            WhyLine(title: "Rain after 4 hot days", detail: "Counted from DFW Airport daily highs"),
            WhyLine(title: "Holiday", detail: "A federal holiday or the day after Thanksgiving"),
            WhyLine(title: "Something new", detail: nil),
        ])
    }

    @Test func labelsAndCaptions() throws {
        #expect(DayMath.surfaceLabel("concrete") == "Concrete")
        #expect(DayMath.surfaceLabel("asphalt_over_concrete") == "Asphalt over concrete")
        #expect(DayMath.surfaceLabel("asphalt") == "Asphalt")
        #expect(DayMath.surfaceLabel("surface_treated") == "Surface-treated")
        #expect(DayMath.surfaceLabel(nil) == nil)
        let store = try freshStore()
        let busy = try #require(store.roads.first { $0.checked == "measured" })
        let est = try #require(store.roads.first { $0.checked != "measured" })
        #expect(DayMath.checkedLine(busy) == "Measured: busy enough to test on its own")
        #expect(DayMath.checkedLine(est) == "Estimated from roads built like this one")
    }

    @Test func routesParse() throws {
        let url = try #require(Bundle.main.url(forResource: "data", withExtension: nil))
        let routes = try DemoRoutes.load(from: url.appending(path: "routes.gpx"))
        #expect(routes.count == 5)
        #expect(routes[0].points.count == 240)
        #expect(routes[0].times.count == 240)
        #expect(routes[0].name == "route-1")
        #expect(routes[0].label == "I-35E")
        #expect(routes[4].label == "I-635")
        #expect(routes[0].times[1].timeIntervalSince(routes[0].times[0]) == 5)
    }

    @Test func badRouteTimeThrows() throws {
        let gpx = """
        <gpx><trk><name>r</name><desc>drives X</desc><trkseg>
        <trkpt lat="1" lon="2"><time>2023-12-15T13:00:00Z</time></trkpt>
        <trkpt lat="1" lon="2"><time>not a time</time></trkpt></trkseg></trk></gpx>
        """
        let url = FileManager.default.temporaryDirectory.appending(path: "bad-\(UUID().uuidString).gpx")
        try gpx.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: DataError.self) { try DemoRoutes.load(from: url) }
        let ok = gpx.replacingOccurrences(of: "not a time", with: "2023-12-15T13:00:05.500Z")
        try ok.write(to: url, atomically: true, encoding: .utf8)
        let routes = try DemoRoutes.load(from: url)
        #expect(routes[0].times.count == 2 && routes[0].points.count == 2)
    }

    @Test func missingFolderThrowsDescriptiveError() throws {
        #expect(throws: DataError.self) {
            try DataStore.load(from: URL(fileURLWithPath: "/nonexistent-folder"))
        }
    }
}
