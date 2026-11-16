import Testing
import Foundation
import SwiftUI
@testable import SameRain

/// Logic behind the inner pages, the day picker and the notification deep link (Task 5).
@MainActor
@Suite struct PagesTests {

    private func store() throws -> DataStore { try DataStore.loadFromBundle() }

    // MARK: Default day

    @Test func defaultDayIsThe2024DemoDay() throws {
        let s = try store()
        #expect(s.defaultDate == "2024-09-23")
        #expect(s.selectedDate == "2024-09-23")
        #expect(s.isLoaded("2024-09-23"))
        #expect(!s.isLoaded("1999-01-01"))
    }

    @Test func launchDateIgnoresAStoredDayThatIsNotLoaded() throws {
        let s = try store()
        #expect(s.launchDate(stored: nil, override: nil) == "2024-09-23")
        #expect(s.launchDate(stored: "", override: nil) == "2024-09-23")
        #expect(s.launchDate(stored: "1999-01-01", override: nil) == "2024-09-23")
        #expect(s.launchDate(stored: "2023-01-30", override: nil) == "2023-01-30")
        // The debug -date argument wins, but only for a loaded day.
        #expect(s.launchDate(stored: "2023-01-30", override: "2023-08-25") == "2023-08-25")
        #expect(s.launchDate(stored: "2023-01-30", override: "1999-01-01") == "2023-01-30")
    }

    @Test func defaultFallsBackTo2023DemoDayWithout2024() throws {
        let road = try RoadsFile.decode(Data("""
        {"features":[{"geometry":{"coordinates":[[[-96.8,32.8],[-96.7,32.8]]]},"properties":{"id":"x","layer":"state",
        "display_name":"X","road":"X","surface":null,"road_class":"interstate","speed_limit":null,"lanes":null,
        "daily_traffic":null,"busy":false,"checked":"estimated"}}]}
        """.utf8))
        let days = ["2023-01-30", "2023-12-15"].map { """
        {"date":"\($0)","weather":{"rain_mm":0,"days_since_rain":1,"high_f":70,"low_f":50,"thunder":false,"fog":false,"ice":false,"freezing":false},
         "reasons":[],"rare":false,"pred":[1.0],"alert":[],"actual_level":{}}
        """ }.joined(separator: ",")
        let file = try JSONDecoder().decode(ScoresFile.self, from: Data("""
        {"version":1,"year":2023,"model":"D","made_up":false,"alert_threshold":1.1,"alert_top_share":0.15,
         "actual_level_names":[],"road_ids":["x"],"days":[\(days)]}
        """.utf8))
        let s = try DataStore(roads: road, years: [file])
        #expect(s.defaultDate == "2023-12-15")
        #expect(s.launchDate(stored: "2024-09-23", override: nil) == "2023-12-15")
        #expect(s.dateRange == "2023-01-30"..."2023-12-15")
    }

    // MARK: Quick picks

    @Test func quickPicksInOrder() throws {
        let s = try store()
        let picks = QuickPicks.available(s.isLoaded)
        #expect(picks.map(\.date) == ["2024-09-23", "2024-04-20", "2024-08-19", "2023-12-15", "2023-01-30", "2023-08-25"])
        #expect(picks.map(\.label) == ["First rain", "Storm", "Hot and dry", "First rain", "Ice", "Dry"])
        for p in picks { #expect((1...3).contains(p.label.split(separator: " ").count)) }
    }

    @Test func quickPicksFilterToLoadedDays() {
        let only2023 = QuickPicks.available { $0.hasPrefix("2023-") }
        #expect(only2023.map(\.date) == ["2023-12-15", "2023-01-30", "2023-08-25"])
        #expect(QuickPicks.available { _ in false }.isEmpty)
    }

    @Test func dateRangeCoversBothYears() throws {
        let s = try store()
        #expect(s.dateRange == "2023-01-01"..."2024-12-31")
    }

    // MARK: Daily score copy

    @Test func scoreLine() {
        #expect(DayMath.scoreLine(score: 28, roads: 850) == "Above a normal day, across 850 DFW roads")
        #expect(DayMath.scoreLine(score: -15, roads: 850) == "Below a normal day, across 850 DFW roads")
        #expect(DayMath.scoreLine(score: 0, roads: 850) == "About a normal day, across 850 DFW roads")
        #expect(DayMath.scoreLine(score: 3, roads: 12) == "Above a normal day, across 12 DFW roads")
        #expect(DayMath.rareLine == "Ice is rare, so trust this less")
    }

    @Test func scoreLineUsesTheLoadedRoadCount() throws {
        let s = try store()
        s.selectedDate = "2024-09-23"
        let day = try #require(s.day)
        #expect(DayMath.dailyScoreText(day) == "+33%")
        #expect(DayMath.scoreLine(score: DayMath.dailyScore(day), roads: s.roads.count)
                == "Above a normal day, across \(s.roads.count) DFW roads")
    }

    @Test func demoDayWhyReadsWithoutContradiction() throws {
        let s = try store()
        s.selectedDate = "2024-09-23"
        #expect(DayMath.dayFacts(try #require(s.day)) == [
            WhyLine(title: "First rain after 11 dry days", detail: "Last rain at DFW Airport was Sep 11"),
            WhyLine(title: "Rain after 4 hot days", detail: "Counted from DFW Airport daily highs"),
            WhyLine(title: "Heavy rain, 17 mm", detail: "Measured at DFW Airport"),
        ])
    }

    // MARK: Daily score: the day's numbers

    @Test func dayNumbersOnTheDemoDays() throws {
        let s = try store()
        s.selectedDate = "2024-09-23"
        #expect(DayMath.dayNumbers(try #require(s.day).weather) == [
            DayNumber(value: "17 mm", label: "rain"),
            DayNumber(value: "12", label: "days since rain"),
            DayNumber(value: "79\u{00B0}F", label: "high"),
        ])
        s.selectedDate = "2024-08-19"
        let dry = DayMath.dayNumbers(try #require(s.day).weather)
        #expect(dry.first == DayNumber(value: "0 mm", label: "rain"))
        #expect(dry.map(\.value) == ["0 mm", "10", "107\u{00B0}F"])
    }

    @Test func rainUnderOneMillimetreKeepsItsDecimal() throws {
        // Rounding 0.3 mm to "0 mm" would read as no rain next to "Rain, 0.3 mm" in Why.
        let s = try store()
        s.selectedDate = "2023-01-30"
        #expect(DayMath.dayNumbers(try #require(s.day).weather).first?.value == "0.3 mm")
        #expect(DayMath.rainText(0) == "0")
        #expect(DayMath.rainText(0.8) == "0.8")
        #expect(DayMath.rainText(1.0) == "1")
        #expect(DayMath.rainText(3.6) == "4")
        #expect(DayMath.rainText(59.4) == "59")
    }

    // MARK: Daily score: busiest roads

    @Test func busiestRoadsOnTheDemoDay() throws {
        let s = try store()
        s.selectedDate = "2024-09-23"
        let day = try #require(s.day)
        let rows = s.busiestRows
        #expect(rows.map(\.name) == ["I-35E", "I-635", "I-20", "I-30", "US 75"])
        #expect(rows.map { DayMath.percentText($0.pred) } == ["+66%", "+44%", "+39%", "+32%", "+25%"])
        #expect(rows.map(\.level) == ["much higher", "far higher", "far higher", "about normal", "below normal"])
        // Every row is the road the level belongs to (looked up by id, never by name).
        #expect(Set(rows.map(\.roadId)) == Set(day.actualLevel.keys))
        for row in rows {
            #expect(row.pred == s.pred(roadId: row.roadId, date: "2024-09-23"))
            let level = try #require(day.actualLevel[row.roadId])
            #expect(row.level == DayMath.shortLevel(s.actualLevelNames[level]))
        }
    }

    @Test func busiestRowsNameTheirStretch() throws {
        // Each row is one surface stretch: I-30's row is its concrete stretch, not the asphalt one
        // that Roads to avoid lists at +62%.
        let s = try store()
        s.selectedDate = "2024-09-23"
        let rows = s.busiestRows
        let surface = Dictionary(uniqueKeysWithValues: rows.map { ($0.name, $0.surface) })
        #expect(surface["I-30"] == "concrete")
        #expect(surface["US 75"] == "concrete")
        #expect(surface["I-35E"] == "asphalt_over_concrete")
        #expect(surface["I-20"] == "asphalt_over_concrete")
        for row in rows {
            let road = try #require(s.roads.first { $0.id == row.roadId })
            #expect(row.surface == road.surface)
        }
        #expect(rows.first?.spokenLabel
                == "I-35E, asphalt over concrete, predicted 66% above normal, what happened: much higher")
        // A road without a surface reads without one.
        #expect(BusiestRow(roadId: "a", name: "A", surface: nil, pred: 1.2, level: "far higher").spokenLabel
                == "A, predicted 20% above normal, what happened: far higher")
    }

    @Test func shortLevelNames() {
        #expect(["below normal", "about normal", "higher than normal", "much higher than normal",
                 "far higher than normal"].map(DayMath.shortLevel)
                == ["below normal", "about normal", "higher", "much higher", "far higher"])
    }

    @Test func busiestRoadsNeedLevels() throws {
        let d = try JSONDecoder().decode(Day.self, from: Data("""
        {"date":"2023-04-02","weather":{"rain_mm":0,"days_since_rain":3,"high_f":72,"low_f":50,"thunder":false,"fog":false,"ice":false,"freezing":false},
         "reasons":[],"rare":false,"pred":[1.2],"alert":[],"actual_level":{"a":4,"b":9,"c":1}}
        """.utf8))
        let names = ["below normal", "about normal", "higher than normal", "much higher than normal", "far higher than normal"]
        // "b" has a level the file can't name and "c" isn't a known road: both are left out.
        let rows = DayMath.busiestRows(d, levelNames: names, name: { $0 == "c" ? nil : $0.uppercased() },
                                       surface: { $0 == "a" ? "concrete" : nil }, pred: { _ in 1.2 })
        #expect(rows == [BusiestRow(roadId: "a", name: "A", surface: "concrete", pred: 1.2, level: "far higher")])
        let none = try JSONDecoder().decode(Day.self, from: Data("""
        {"date":"2023-04-02","weather":{"rain_mm":0,"days_since_rain":3,"high_f":72,"low_f":50,"thunder":false,"fog":false,"ice":false,"freezing":false},
         "reasons":[],"rare":false,"pred":[],"alert":[],"actual_level":{}}
        """.utf8))
        #expect(DayMath.busiestRows(none, levelNames: names, name: { $0 }, surface: { _ in nil },
                                    pred: { _ in 1 }).isEmpty)
    }

    // MARK: Roads to avoid

    @Test func emptyStateDecision() throws {
        let s = try store()
        s.selectedDate = "2024-08-19"
        #expect(RoadsPageState(flaggedCount: s.flagged.count) == .empty)
        s.selectedDate = "2024-09-23"
        #expect(RoadsPageState(flaggedCount: s.flagged.count) == .list(count: 127))
        #expect(RoadsPageState(flaggedCount: 0) == .empty)
        #expect(RoadsPageState(flaggedCount: 1) == .list(count: 1))
    }

    @Test func roadsCopy() {
        #expect(RoadsCopy.countLine(127) == "127 roads today")
        #expect(RoadsCopy.countLine(1) == "1 road today")
        #expect(RoadsCopy.mapCaption(127) == "127 roads to avoid today")
        #expect(RoadsCopy.mapCaption(1) == "1 road to avoid today")
        #expect(RoadsCopy.mapCaption(0) == "Nothing flagged today.")
        #expect(RoadsCopy.emptyTitle == "Nothing to avoid today.")
        #expect(RoadsCopy.emptyDetail == "No road is running much above its normal.")
        #expect(RoadsCopy.rowLabel(name: "US 175", pred: 2.09) == "US 175, 109% above normal")
        #expect(RoadsCopy.rowLabel(name: "X", pred: 0.85) == "X, 15% below normal")
        #expect(RoadsCopy.rowLabel(name: "X", pred: 1.0) == "X, about normal")
    }

    // MARK: Deep link

    @Test func openRoadGoesToRoadsAndOpensThePopup() {
        let known: (String) -> Bool = { $0 == "state-ih35e-asphalt_over_concrete" }
        var nav = Navigation()
        let opened = nav.openRoad(id: "state-ih35e-asphalt_over_concrete", isKnown: known)
        #expect(opened)
        #expect(nav.page == .roads)
        #expect(nav.sheet == .road("state-ih35e-asphalt_over_concrete"))
        #expect(nav.popupRoadId == "state-ih35e-asphalt_over_concrete")

        // From another page with the day picker open: the picker gives way to the popup.
        var busy = Navigation(page: .score, sheet: .dayPicker)
        let replaced = busy.openRoad(id: "state-ih35e-asphalt_over_concrete", isKnown: known)
        #expect(replaced)
        #expect(busy.page == .roads)
        #expect(busy.sheet == .road("state-ih35e-asphalt_over_concrete"))
    }

    @Test func openRoadIgnoresUnknownIds() {
        var nav = Navigation(page: .map, sheet: nil)
        let opened = nav.openRoad(id: "nope", isKnown: { _ in false })
        #expect(!opened)
        #expect(nav == Navigation(page: .map, sheet: nil))
        #expect(nav.popupRoadId == nil)
    }

    @Test func delayedPopupNeverReplacesANewerSheet() {
        let known: (String) -> Bool = { _ in true }
        var target = Navigation(page: .score)
        target.openRoad(id: "state-ih30-concrete", isKnown: known)

        // Nothing changed while the page settled: the popup shows.
        var settled = Navigation(page: .roads)
        settled.finishOpening(target)
        #expect(settled.sheet == .road("state-ih30-concrete"))

        // The driver opened the day picker, or a second link opened another road, during the wait.
        var picker = Navigation(page: .roads, sheet: .dayPicker)
        picker.finishOpening(target)
        #expect(picker.sheet == .dayPicker)
        var newer = Navigation(page: .roads, sheet: .road("state-ih35e-asphalt_over_concrete"))
        newer.finishOpening(target)
        #expect(newer.sheet == .road("state-ih35e-asphalt_over_concrete"))

        // The driver left the page during the wait.
        var left = Navigation(page: .map)
        left.finishOpening(target)
        #expect(left.sheet == nil)
    }

    @Test func openRoadWorksWithTheRealRoads() throws {
        let s = try store()
        var nav = Navigation()
        let opened = nav.openRoad(id: "state-ih35e-asphalt_over_concrete", isKnown: { s.roadIndex[$0] != nil })
        #expect(opened)
        #expect(nav.popupRoadId == "state-ih35e-asphalt_over_concrete")
    }

    // MARK: Dynamic Type

    @Test func bodyTextScalesWithACap() {
        #expect(Theme.scaledSize(16, relativeTo: .body, dynamicType: .large) == 16)
        #expect(Theme.scaledSize(16, relativeTo: .body, dynamicType: .xLarge) > 16)
        #expect(Theme.scaledSize(16, relativeTo: .body, dynamicType: .accessibility5) <= 16 * 1.3 + 0.001)
        #expect(Theme.scaledSize(13, relativeTo: .footnote, dynamicType: .accessibility5) <= 13 * 1.3 + 0.001)
        #expect(Theme.scaledSize(13, relativeTo: .footnote, dynamicType: .small) < 13)
    }
}
