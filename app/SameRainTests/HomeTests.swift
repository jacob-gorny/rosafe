import Testing
import Foundation
import UIKit
import CoreText
@testable import SameRain

struct HomeTests {
    private func at(hour: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 11; c.day = 15; c.hour = hour; c.minute = 30
        return Calendar.current.date(from: c)!
    }

    @Test func greetingByHour() {
        #expect(Greeting.text(at: at(hour: 4)) == "Good evening")
        #expect(Greeting.text(at: at(hour: 5)) == "Good morning")
        #expect(Greeting.text(at: at(hour: 11)) == "Good morning")
        #expect(Greeting.text(at: at(hour: 12)) == "Good afternoon")
        #expect(Greeting.text(at: at(hour: 16)) == "Good afternoon")
        #expect(Greeting.text(at: at(hour: 17)) == "Good evening")
        #expect(Greeting.text(at: at(hour: 0)) == "Good evening")
    }

    @Test func dayLabel() {
        #expect(DayLabel.long("2023-12-15") == "Dec 15, 2023")
        #expect(DayLabel.long("2023-01-30") == "Jan 30, 2023")
        #expect(DayLabel.long("not a date") == "not a date")
    }

    // MARK: Weather tiles

    @MainActor
    @Test func rainTilesWithThunderFogAndHotDays() {
        let names = WeatherTiles.symbols(for: .rain(fog: true, thunder: true),
                                         reasons: ["First rain after 11 dry days", "Rain after 4 hot days", "Heavy rain (17 mm)"])
        #expect(names == ["cloud.bolt.rain.fill", "drop.fill", "umbrella.fill", "car.fill", "road.lanes",
                          "thermometer.sun.fill", "cloud.fog.fill"])
    }

    @MainActor
    @Test func plainRainTiles() {
        // "First rain after…" is about dry days, not hot ones, so the drizzle cloud stays.
        let names = WeatherTiles.symbols(for: .rain(fog: false, thunder: false),
                                         reasons: ["First rain after 14 dry days", "Rain (3.6 mm)"])
        #expect(names == ["cloud.rain.fill", "drop.fill", "umbrella.fill", "car.fill", "road.lanes",
                          "cloud.drizzle.fill", "wind"])
    }

    @MainActor
    @Test func iceTiles() {
        #expect(WeatherTiles.symbols(for: .ice(fog: false), reasons: ["Ice on the roads"])
                == ["snowflake", "thermometer.snowflake", "cloud.snow.fill", "car.fill", "road.lanes",
                    "exclamationmark.triangle.fill", "wind"])
        #expect(WeatherTiles.symbols(for: .ice(fog: true), reasons: []).last == "cloud.fog.fill")
    }

    @MainActor
    @Test func dryTiles() {
        #expect(WeatherTiles.symbols(for: .dry(fog: false), reasons: [])
                == ["sun.max.fill", "thermometer.sun.fill", "cloud.sun.fill", "car.fill", "road.lanes",
                    "sunglasses.fill", "wind"])
        #expect(WeatherTiles.symbols(for: .dry(fog: true), reasons: []).last == "cloud.fog.fill")
    }

    @MainActor
    @Test func everyTileSetIsSevenRealSymbolsWithNoTwinNeighbours() {
        let sets: [SymbolSet] = [.rain(fog: false, thunder: false), .rain(fog: true, thunder: false),
                                 .rain(fog: false, thunder: true), .rain(fog: true, thunder: true),
                                 .ice(fog: false), .ice(fog: true), .dry(fog: false), .dry(fog: true)]
        for set in sets {
            for reasons in [[], ["Rain after 3 hot days"]] {
                let names = WeatherTiles.symbols(for: set, reasons: reasons)
                #expect(names.count == 7)
                #expect(Set(names).count == 7)
                for (a, b) in zip(names, names.dropFirst()) { #expect(a != b) }
                for n in names { #expect(UIImage(systemName: n) != nil, "\(n) is not an SF Symbol here") }
            }
        }
    }

    @MainActor
    @Test func demoDayTilesComeFromTheDay() throws {
        let store = try DataStore.loadFromBundle()
        store.selectedDate = "2024-09-23"
        let day = try #require(store.day)
        #expect(WeatherTiles.symbols(for: day) == ["cloud.bolt.rain.fill", "drop.fill", "umbrella.fill", "car.fill",
                                                   "road.lanes", "thermometer.sun.fill", "cloud.fog.fill"])
        store.selectedDate = "2023-01-30"
        #expect(WeatherTiles.symbols(for: try #require(store.day)).first == "snowflake")
        store.selectedDate = "2024-08-19"
        #expect(WeatherTiles.symbols(for: try #require(store.day)).first == "sun.max.fill")
    }

    @Test func homeTilesSitWhereTheMockupPutsThem() {
        // The approved mockup is 402 × 874 points; on that screen the spots land exactly on it.
        let size = CGSize(width: 402, height: 874)
        let expected: [(CGFloat, CGFloat, Double)] = [(340, 196, 6), (70, 214, -8), (20, 520, 10), (384, 560, -6),
                                                      (110, 690, 4), (300, 700, -4), (400, 296, 8)]
        #expect(TileLayout.home.count == 7)
        for (i, e) in expected.enumerated() {
            let spot = TileLayout.spot(i, onPage: false, in: size)
            #expect(abs(spot.x - e.0) < 0.01 && abs(spot.y - e.1) < 0.01)
            #expect(spot.turn == e.2)
            #expect(spot.shown)
        }
    }

    @Test func pageTilesStayClearOfThePageColumn() {
        for size in [CGSize(width: 375, height: 667), CGSize(width: 390, height: 844),
                     CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)] {
            let inset = TileLayout.pageInset(width: size.width)
            // The Daily score title and its score (about 293 pt) fit between the insets.
            #expect(size.width - 2 * inset >= 295)
            let shown = (0..<7).map { TileLayout.spot($0, onPage: true, in: size) }.enumerated().filter { $0.element.shown }
            #expect(shown.map(\.offset) == [0, 2, 3])
            let float = TileLayout.float
            let right = TileLayout.spot(0, onPage: true, in: size)
            #expect(right.x - TileLayout.reach(right.turn) >= size.width - inset + 8 - 0.01)
            #expect(right.x < size.width + TileLayout.side / 2)     // still on the edge, not gone
            #expect(abs(right.y - size.height * 0.40) < 0.01)
            let left = TileLayout.spot(2, onPage: true, in: size)
            #expect(left.x + TileLayout.reach(left.turn) <= inset - 8 + 0.01)
            #expect(left.x > -TileLayout.side / 2)
            #expect(abs(left.y - size.height * 0.72) < 0.01)
            let corner = TileLayout.spot(3, onPage: true, in: size)
            #expect(corner.y - TileLayout.reach(corner.turn) - float >= size.height - TileLayout.pageBottom + 8 - 0.01)
            #expect(corner.x > size.width / 2)
            // The other four leave the screen entirely.
            for i in [1, 4, 5, 6] {
                let s = TileLayout.spot(i, onPage: true, in: size)
                let r = TileLayout.reach(s.turn)
                #expect(!s.shown)
                #expect(s.x + r <= 0 || s.x - r >= size.width)
            }
        }
        #expect(TileLayout.pageInset(width: 402) == 48)
    }

    @MainActor
    @Test func archivoIsWide() throws {
        // The bundled variable font at width 125 sets a word visibly wider than at width 100,
        // same weight.
        let wide = try #require(Theme.archivo(size: 38, wght: 600))
        let base = try #require(UIFont(name: "ArchivoRoman-Regular", size: 38))
        let attribute = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let axes: [NSNumber: NSNumber] = [NSNumber(value: 0x7764_7468): 100, NSNumber(value: 0x7767_6874): 600]
        let normal = UIFont(descriptor: base.fontDescriptor.addingAttributes([attribute: axes]), size: 38)
        let word = "Roads to avoid"
        let wideWidth = (word as NSString).size(withAttributes: [.font: wide]).width
        let normalWidth = (word as NSString).size(withAttributes: [.font: normal]).width
        #expect(wideWidth > normalWidth * 1.12)
    }
}
