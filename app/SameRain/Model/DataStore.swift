import Foundation
import Observation

nonisolated enum DataError: LocalizedError {
    case missingFolder(String)
    case badFile(String, String)
    case mismatch(String)

    var errorDescription: String? {
        switch self {
        case .missingFolder(let p): "The road data could not be found (\(p))."
        case .badFile(let f, let why): "The file \(f) could not be read: \(why)"
        case .mismatch(let why): "The road data does not line up: \(why)"
        }
    }
}

@Observable
final class DataStore {
    let roads: [Road]
    let roadIndex: [String: Int]
    /// One entry per scores file, oldest year first.
    let years: [ScoresFile]
    var selectedDate: String

    // date -> (year index, day index); per-year road id -> column in `pred`.
    private let dayLookup: [String: (year: Int, day: Int)]
    private let columns: [[String: Int]]

    init(roads: [Road], years: [ScoresFile]) throws {
        let sorted = years.sorted { $0.year < $1.year }
        var index: [String: Int] = [:]
        for (i, r) in roads.enumerated() { index[r.id] = i }
        var lookup: [String: (year: Int, day: Int)] = [:]
        var cols: [[String: Int]] = []
        for (y, file) in sorted.enumerated() {
            var c: [String: Int] = [:]
            for (i, id) in file.roadIds.enumerated() {
                guard index[id] != nil else {
                    throw DataError.mismatch("\(id) is in the \(file.year) scores but not on the map")
                }
                c[id] = i
            }
            for (d, day) in file.days.enumerated() {
                guard day.pred.count == file.roadIds.count else {
                    throw DataError.mismatch("\(day.date) has \(day.pred.count) scores for \(file.roadIds.count) roads")
                }
                lookup[day.date] = (y, d)
            }
            cols.append(c)
        }
        self.roads = roads
        self.roadIndex = index
        self.years = sorted
        self.dayLookup = lookup
        self.columns = cols
        let fallback = sorted.last?.days.first?.date ?? Self.preferredDefaults.last!
        let start = Self.preferredDefaults.first { lookup[$0] != nil } ?? fallback
        self.defaultDate = start
        self.selectedDate = start
        let dates = lookup.keys.sorted()
        self.dateRange = dates.first.flatMap { first in dates.last.map { first...$0 } }
    }

    /// Where the app remembers the chosen day between launches (`@AppStorage`).
    static let storedDateKey = "selectedDate"

    /// The demo days, in order of preference: the 2024 rain day the video uses, then the 2023 one.
    static let preferredDefaults = ["2024-09-23", "2023-12-15"]

    /// The day shown when nothing else is chosen: the first loaded demo day, else the latest
    /// year's first day.
    let defaultDate: String

    /// The first and last loaded days ("yyyy-MM-dd" sorts like the calendar).
    let dateRange: ClosedRange<String>?

    /// True when some loaded scores file has this day.
    func isLoaded(_ date: String) -> Bool { dayLookup[date] != nil }

    /// The day to show at launch: the debug override, else the remembered choice, each only if
    /// it is a loaded day; otherwise the default.
    func launchDate(stored: String?, override: String?) -> String {
        if let override, isLoaded(override) { return override }
        if let stored, isLoaded(stored) { return stored }
        return defaultDate
    }

    var day: Day? {
        guard let hit = dayLookup[selectedDate] else { return nil }
        return years[hit.year].days[hit.day]
    }

    /// The `actual_level_names` of the scores file that holds the selected day.
    var actualLevelNames: [String] {
        guard let hit = dayLookup[selectedDate] else { return [] }
        return years[hit.year].actualLevelNames
    }

    /// The selected day's alert list, highest score first, ties by lower index first.
    var flagged: [(road: Road, pred: Double)] {
        guard let hit = dayLookup[selectedDate] else { return [] }
        let file = years[hit.year]
        let day = file.days[hit.day]
        return day.alert.sorted { a, b in
            day.pred[a] != day.pred[b] ? day.pred[a] > day.pred[b] : a < b
        }.compactMap { i in
            guard i < file.roadIds.count, let r = roadIndex[file.roadIds[i]] else { return nil }
            return (roads[r], day.pred[i])
        }
    }

    /// The selected day's busiest roads, predicted against what happened (Daily score).
    var busiestRows: [BusiestRow] {
        guard let day else { return [] }
        return DayMath.busiestRows(day, levelNames: actualLevelNames,
                                   name: { id in roadIndex[id].map { roads[$0].displayName } },
                                   surface: { id in roadIndex[id].flatMap { roads[$0].surface } },
                                   pred: { id in pred(roadId: id, date: selectedDate) })
    }

    func pred(roadId: String, date: String) -> Double? {
        guard let hit = dayLookup[date], let col = columns[hit.year][roadId] else { return nil }
        return years[hit.year].days[hit.day].pred[col]
    }

    static func loadFromBundle() throws -> DataStore {
        guard let url = Bundle.main.url(forResource: "data", withExtension: nil) else {
            throw DataError.missingFolder("data folder not in the app")
        }
        return try load(from: url)
    }

    static func load(from folder: URL) throws -> DataStore {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
            throw DataError.missingFolder(folder.lastPathComponent)
        }
        let roadsURL = folder.appending(path: "roads.geojson")
        let roads: [Road]
        do { roads = try RoadsFile.decode(Data(contentsOf: roadsURL)) }
        catch { throw DataError.badFile("roads.geojson", error.localizedDescription) }

        let names = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        let scoreNames = names.filter { $0.hasPrefix("scores_") && $0.hasSuffix(".json") }.sorted()
        guard !scoreNames.isEmpty else { throw DataError.badFile("scores_*.json", "no scores file found") }
        var files: [ScoresFile] = []
        for n in scoreNames {
            do { files.append(try JSONDecoder().decode(ScoresFile.self, from: Data(contentsOf: folder.appending(path: n)))) }
            catch { throw DataError.badFile(n, error.localizedDescription) }
        }
        return try DataStore(roads: roads, years: files)
    }
}
