# Same Rain iPhone App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native iPhone app that shows the brain's daily road scores in the word-led design from the spec and sends a Time Sensitive phone notification when a real (or simulated) drive approaches a flagged road.

**Architecture:** One SwiftUI app target plus a Swift Testing unit-test target, in a new Xcode project in `app/`. Pure Swift model and alert code (no UI imports) is unit-tested against the real files in `data/`; SwiftUI views read one `@Observable` store. Location comes from `CLLocationManager` (background updates on), and both real fixes and simulated-drive fixes go through the same `AlertEngine`.

**Tech Stack:** Swift 6, SwiftUI, MapKit for SwiftUI (`Map`, `MapPolyline`), Core Location, UserNotifications, Swift Testing, Xcode 27.2, iOS 27.2 Simulator (iPhone 17 Pro).

**Spec:** `docs/superpowers/specs/2026-11-15-app-design.md`

## Global Constraints

- New project only, in `app/`; nothing copied from any other app.
- Read road ids from the files; never hard-code a road id outside tests.
- No network calls; location is never stored or sent.
- Font: Archivo variable font at width 125 for all text; fallback the system font with `.width(.expanded)`.
- Colors: ink `#17171B`, caption `#6D6D78`, risk `#D42F25`, map line `#E2342E`, calm `#2F8A57`, live `#22A55B`; tints rain `#EAF2FC`, ice `#E9F6F9`, dry `#FBF5EA`; symbols rain `#2D7FF9`, ice `#3BB7E0`, fog `#9AA3B2`, sun `#F5A623`, asphalt `#3A3F47`, lane `#F5C518`.
- Sizes: greeting 34 bold, home words 38 semibold, page titles 28 bold, body 16 to 17, captions 13.
- No pills, row dividers, boxed cards, gradients, eyebrow labels, emoji, names.
- Notification: title `Approaching risky road`, body `{display_name} · {N}% more crashes than normal today`, interruption level `.timeSensitive`.
- Alert rule: speed > 8.9 m/s; distance to polyline ≤ 805 m; "toward" = within 60 m, or distance fell since last fix, or |course − bearing| < 60°; re-armed only after > 805 m away and ≥ 600 s since its alert; one alert per update, highest `pred` first.
- Percent: N = round((pred − 1) × 100). Daily score = round((mean(pred) − 1) × 100), signed.
- Work happens on branch `app` (repo rule: no commits on main without the user's OK); commit after every task.

## Review Focus

1. A day with an empty `alert` list (Aug 25): Roads to avoid shows "Nothing to avoid today.", Map has no lines, no notification ever fires. Test in Task 2 and Task 3.
2. A fix with invalid speed (`speed < 0`, common in the Simulator's first fix): use the speed between the last two fixes; a first fix with invalid speed (no previous fix to derive from) never alerts. Test in Task 3.
6. A data file that fails to decode: home shows one plain line, "Couldn't read the road scores", and nothing crashes. Checked by hand in Task 4 (temporarily rename the file in the built bundle).
3. Two roads with the same display name (US 75 concrete and asphalt over concrete): the list adds a surface caption; the notification still uses `display_name`. Test in Task 2.
4. Location permission: with While Using or Always and updates running, the home line reads "Watching for risky roads"; denied or not yet decided, it reads "Location off · tap to turn on". Either way the app does not crash or spam prompts. Checked by hand in Task 6.
5. Selected day changes during a simulated drive: the engine switches to the new day's alert list on the next fix; nothing already alerted fires again in the same pass. Test in Task 3.

---

### Task 1: Project, font, data, permissions scaffold

**Files:**
- Create: `app/SameRain.xcodeproj` (via `mcp__xcode__XcodeNewProject`, iOS App, SwiftUI, Swift Testing, product `SameRain`, org `com.samerain`, into `app/`)
- Create: `app/SameRain/Resources/Archivo[wdth,wght].ttf`, `app/SameRain/Resources/OFL-Archivo.txt` (download from `https://github.com/google/fonts/raw/main/ofl/archivo/`)
- Create: `app/SameRain/Info.plist` (partial: `UIAppFonts`, `UIBackgroundModes` = [`location`], `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`)
- Create: `app/SameRain/SameRain.entitlements` (`com.apple.developer.usernotifications.time-sensitive` = true)
- Modify: `app/SameRain.xcodeproj/project.pbxproj` (folder reference `../data` → Copy Bundle Resources as `data`; `INFOPLIST_FILE`, `CODE_SIGN_ENTITLEMENTS`, `IPHONEOS_DEPLOYMENT_TARGET = 18.0`)
- Modify: `.gitignore` (add `app/**/xcuserdata` already covered; nothing else), `CLAUDE.md` (sections 1, 6, 8: the user and Claude Code build `app/`; the teammate first planned for it no longer does)

**Interfaces:**
- Produces: `Bundle.main.url(forResource: "data", withExtension: nil)` resolves to a folder containing `roads.geojson`, `scores_2023.json`, `routes.gpx` (and `scores_2024.json` when present).

- [ ] **Step 1:** Create branch `app`; create the project with `XcodeNewProject` (fallback: a hand-written `project.pbxproj` using `PBXFileSystemSynchronizedRootGroup` for `SameRain/` and `SameRainTests/`).
- [ ] **Step 2:** Download the font and license; add the plist keys, entitlements and the `data` folder reference.
- [ ] **Step 3:** Temporary `ContentView` prints `UIFont.fontNames(forFamilyName: "Archivo")` and the `data` folder listing to the log.
- [ ] **Step 4:** `session_set_defaults` (project `app/SameRain.xcodeproj`, scheme `SameRain`, simulator `iPhone 17 Pro`) and `build_run_sim`. Expected: launches; log shows an Archivo font name and the three data files.
- [ ] **Step 5:** Commit `app: new Xcode project with Archivo, data folder and permissions`.

### Task 2: Data layer and day math

**Files:**
- Create: `app/SameRain/Model/Road.swift`, `ScoresFile.swift`, `DataStore.swift`, `DayMath.swift`, `DemoRoutes.swift`
- Test: `app/SameRainTests/DataTests.swift`

**Interfaces:**
- Produces:
  - `struct Road: Identifiable { id: String; layer: String; displayName: String; road: String; surface: String?; roadClass: String; speedLimit: Int?; lanes: Int?; dailyTraffic: Int?; busy: Bool; checked: String; lines: [[CLLocationCoordinate2D]] }`
  - `struct ScoresFile: Decodable` mirroring the contract (`version, year, model, madeUp, alertThreshold, alertTopShare, actualLevelNames, roadIds, days`), `struct Day: Decodable { date: String; weather: Weather; reasons: [String]; rare: Bool; pred: [Double]; alert: [Int]; actualLevel: [String: Int] }`, `struct Weather: Decodable { rainMm: Double; daysSinceRain: Int; highF: Int; lowF: Int; thunder: Bool; fog: Bool; ice: Bool; freezing: Bool }` (snake_case keys)
  - `@Observable final class DataStore { roads: [Road]; roadIndex: [String: Int]; years: [ScoresFile]; selectedDate: String; var day: Day?; var flagged: [(road: Road, pred: Double)]  /* alert list, pred desc */; func pred(roadId: String, date: String) -> Double?; static func loadFromBundle() throws -> DataStore }`
  - `enum DayMath { static func percent(_ pred: Double) -> Int; static func dailyScore(_ day: Day) -> Int; static func symbolSet(_ w: Weather, rare: Bool) -> SymbolSet; static func dayFacts(_ day: Day) -> [(title: String, fact: String)]; static func roadWhy(road: Road, pred: Double, day: Day, levelNames: [String]) -> [String]; static func needsSurfaceCaption(_ flagged: [Road]) -> Set<String> }`
  - `enum SymbolSet { case rain(fog: Bool, thunder: Bool), ice(fog: Bool), dry(fog: Bool) }`
  - `struct DemoRoute { name: String; label: String; points: [CLLocationCoordinate2D]; times: [Date] }`, `enum DemoRoutes { static func load(from url: URL) throws -> [DemoRoute] }` (XMLParser over `trk`/`trkpt`/`time`/`desc`)

- [ ] **Step 1: Write the failing tests** in `DataTests.swift`:
  - `loadsRealFiles`: `roads.count == 850`, `years.first?.days.count == 365`, `roadIds == roads.map(\.id)` (as sets and order), header `alertThreshold == 1.14`, `alertTopShare == 0.15`, `actualLevelNames.count == 5`.
  - `dailyScoreMatchesFile`: Dec 15 → `28`, Aug 25 → `-15`, Jan 30 → `35`.
  - `percentRounds`: `percent(2.09) == 109`, `percent(1.89) == 89`, `percent(0.85) == -15`.
  - `flaggedOrderAndEmpty`: Dec 15 `flagged.count == 127`, first is `US 175` with pred `2.09`; Aug 25 `flagged.isEmpty`.
  - `appTest2SameNumbers`: 5 seeded-random (seed 42) road-days: `store.pred(roadId:date:)` equals the raw JSON value read with `JSONSerialization`.
  - `symbolSets`: Dec 15 → `.rain(fog: true, thunder: false)`; Jan 30 → `.ice(fog: true)`; Aug 25 → `.dry(fog: false)`; Oct 25 → `.rain(fog: true, thunder: true)`.
  - `surfaceCaptionForDuplicates`: on Dec 15, `needsSurfaceCaption` contains both US 75 ids.
  - `roadWhyUS175`: lines include `"Asphalt laid over concrete. On first rains this surface jumped more than plain concrete on the same highways (2021 to 2023)"` and `"70 mph, 4 lanes, about 76,000 cars a day"`; I-35E on Dec 15 includes `"What really happened: far higher than normal"`.
  - `routesParse`: 5 routes, route 1 has 240 points.
- [ ] **Step 2:** Run `test_sim`; expected FAIL (types missing).
- [ ] **Step 3:** Implement the files above. Traffic is rounded to the nearest thousand with a thousands separator; `dayFacts` uses `weather` only (e.g. `("Heavy rain, 15 mm", "Measured at DFW Airport")`, `("First rain after 14 dry days", "Last rain at DFW Airport was Nov 30")`, dry day `("No rain for 40 days", …)`, `("Hot, 110°F", "Measured at DFW Airport")`), mapping each `reasons` entry to a fact.
- [ ] **Step 4:** Run `test_sim`; expected PASS.
- [ ] **Step 5:** Commit `app: data layer reads roads, scores and routes; day math tested`.

### Task 3: Geometry and alert engine

**Files:**
- Create: `app/SameRain/Alert/Geo.swift`, `app/SameRain/Alert/AlertEngine.swift`
- Test: `app/SameRainTests/AlertTests.swift`

**Interfaces:**
- Consumes: `Road`, `DataStore.flagged`.
- Produces:
  - `struct Fix { coordinate: CLLocationCoordinate2D; speed: Double /* m/s, <0 = invalid */; course: Double /* deg, <0 = invalid */; time: Date }`
  - `enum Geo { static func distance(from p: CLLocationCoordinate2D, to lines: [[CLLocationCoordinate2D]]) -> (meters: Double, nearest: CLLocationCoordinate2D); static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double }` (local equirectangular projection around `p`, point-to-segment)
  - `struct AlertEngine { init(); mutating func setTargets(_ targets: [(road: Road, pred: Double)]); mutating func process(_ fix: Fix) -> (road: Road, pred: Double)? }` (keeps last fix, per-road last distance, last alert time, and armed flag)

- [ ] **Step 1: Write the failing tests** (synthetic straight road from (32.80,-96.80) to (32.90,-96.80) unless noted):
  - `firesWhenApproachingFast`: track due north toward the road start from 1.2 km south at 29 m/s, 5 s apart → exactly one alert, at the first fix with distance ≤ 805 m.
  - `firesWhenStartingOnRoad`: first fix on the road with valid speed 29 m/s → alert on that first fix (on the road counts as toward). Same track with `speed = -1` → alert on the second fix.
  - `quietWhenParked`: 60 fixes at 0 m/s 100 m from the road → no alert.
  - `quietWhenWalking`: 1.5 m/s toward the road → no alert.
  - `quietWhenMovingAway`: heading south from 300 m away at 29 m/s → no alert.
  - `onePerPass`: drive along the road for 20 min at 29 m/s → one alert; leave to 900 m, wait 11 min, come back → second alert; leave to 900 m but return after 3 min → no second alert.
  - `invalidSpeedUsesDerived`: fixes with `speed = -1`, 145 m apart every 5 s → alerts (derived 29 m/s).
  - `highestPredFirst`: two roads both qualifying on the same fix → returns the higher pred; the other fires on the next fix.
  - `targetsSwapMidDrive`: after an alert on road A, `setTargets` with a list still containing A → A does not re-alert in the same pass.
  - `route1OnDec15`: real route 1 through `DataStore` Dec 15 targets → first alert is `I-35E` (display name), and no road alerts twice.
  - `route5OnAug25`: real route 5 with Aug 25 targets → no alerts.
- [ ] **Step 2:** Run `test_sim`; expected FAIL.
- [ ] **Step 3:** Implement `Geo` and `AlertEngine` per Global Constraints' alert rule.
- [ ] **Step 4:** Run `test_sim`; expected PASS (all Task 2 tests still pass).
- [ ] **Step 5:** Commit `app: alert engine fires once per pass, tested on real routes`.

### Task 4: Theme, weather symbols, home and page transitions

**Files:**
- Create: `app/SameRain/UI/Theme.swift`, `WeatherSymbols.swift`, `HomeView.swift`, `RootView.swift`
- Modify: `app/SameRain/SameRainApp.swift`, delete `ContentView.swift`

**Interfaces:**
- Consumes: `DataStore`, `DayMath.symbolSet`.
- Produces:
  - `enum Theme { static func font(_ size: CGFloat, _ weight: Font.Weight) -> Font; static let ink, caption, risk, mapLine, calm, live: Color; static func tint(for set: SymbolSet) -> Color }` (Archivo via `UIFontDescriptor` with `kCTFontVariationAttribute` `[0x77647468 /*wdth*/: 125, 0x77676874 /*wght*/: weight]`)
  - `enum Page: String { case score, roads, map }`
  - `struct WeatherSymbolsLayer: View { let set: SymbolSet; let atBorder: Bool }` (positions from the prototype: home `HOME` and border `BORDER` lists in `alive-prototype-v3.html`; spring `response 0.6, dampingFraction 0.7`, stagger 25 ms; bob `±5 pt, ±4°`, 3 to 5 s, off under Reduce Motion)
  - `struct RootView: View` holds `@State page: Page?` and a `@Namespace`; `HomeView(namespace:onOpen:)`; inner pages get `title(namespace:page:onBack:)` via a shared `PageTitle` view using `matchedGeometryEffect(id: page.rawValue, in:)`.
- [ ] **Step 1:** Build the views; greeting by hour (5 to 11 morning, 12 to 16 afternoon, else evening); bottom line per spec with the date tappable (opens `DayPicker`, Task 5).
- [ ] **Step 2:** `build_run_sim`; screenshot home on Dec 15. Expected: tint `#EAF2FC`, blue rain symbols bobbing, three words centered in Archivo wide.
- [ ] **Step 3:** Tap "Daily score" (via `snapshot_ui`/tap or a launch argument `-page score`); screenshot mid-transition and after. Expected: symbols at the border, word in the title slot.
- [ ] **Step 4:** Commit `app: home screen with weather symbols and word-to-title transition`.

### Task 5: Daily score, roads, road popup, map, day picker

**Files:**
- Create: `app/SameRain/UI/DailyScoreView.swift`, `RoadsView.swift`, `RoadPopup.swift`, `MapPage.swift`, `DayPicker.swift`

**Interfaces:**
- Consumes: `DataStore`, `DayMath.dayFacts`, `DayMath.roadWhy`, `DayMath.needsSurfaceCaption`, `Theme`, `PageTitle`.
- Produces: `MapPage` exposes `@State var drive: DriveSimulator?` hook (filled in Task 6); `RoadsView` opens `RoadPopup(roadId:)` as a sheet; `RootView` accepts `openRoad(id:)` for the notification deep link.
- [ ] **Step 1:** Implement the pages with the exact copy in the spec ("Above a normal day, across 850 DFW roads", "Ice is rare, so trust this less", "Nothing to avoid today.", "Measured: busy enough to test on its own", "Estimated from roads built like this one"). Map: `Map` with `MapPolyline` per flagged line, stroke `Theme.mapLine` 4 pt, `UserAnnotation()`, initial camera over DFW core (32.80, −96.80), ~40 km span.
- [ ] **Step 2:** Day picker: quick picks Dec 15, Jan 30, Oct 25, Aug 25 (2023) plus a graphical `DatePicker` limited to loaded years; selection saved in `@AppStorage("selectedDate")`.
- [ ] **Step 3:** `build_run_sim`; screenshot every page on Dec 15, Jan 30 and Aug 25 (launch argument `-date 2023-08-25`). Expected: numbers match Task 2's tests; Aug 25 shows the empty state and green −15%.
- [ ] **Step 4:** Commit `app: daily score, roads, road popup, map and day picker`.

### Task 6: Location, notifications, simulated drive

**Files:**
- Create: `app/SameRain/Alert/LocationService.swift`, `Notifier.swift`, `DriveSimulator.swift`
- Modify: `RootView.swift`, `MapPage.swift`, `HomeView.swift`

**Interfaces:**
- Consumes: `AlertEngine`, `Fix`, `DataStore.flagged`, `DemoRoutes`.
- Produces:
  - `@Observable final class LocationService: NSObject, CLLocationManagerDelegate { var status: CLAuthorizationStatus; var isWatching: Bool; func requestPermissions(); func start(); var onFix: ((Fix) -> Void)? }` (When In Use first, then Always on the next authorization callback; `allowsBackgroundLocationUpdates = true`, `pausesLocationUpdatesAutomatically = false`, `activityType = .automotiveNavigation`)
  - `enum Notifier { static func requestAuthorization() async; static func send(road: Road, pred: Double) }` (`userInfo["roadId"]`, `.timeSensitive`, default sound)
  - `@Observable final class DriveSimulator { init(route: DemoRoute); var position: CLLocationCoordinate2D?; func start(onFix: @escaping (Fix) -> Void); func stop() }` (one point per second, 5× faster than real time, speed 29 m/s, course from consecutive points)
  - An `AppCoordinator` (in `RootView.swift`) owns one `AlertEngine`, refreshes targets when `selectedDate` changes, and routes fixes from both sources to `Notifier.send`.
- [ ] **Step 1:** Implement; notification tap sets `RootView` to Roads with `RoadPopup` for `roadId` (`UNUserNotificationCenterDelegate`, also presents banners while the app is in front).
- [ ] **Step 2:** In the Simulator: grant location Always and notifications; set Dec 15; send the app to the background; run `xcrun simctl location <udid> start --speed=29 --interval=1 -` with route 1's points on stdin. Expected: banner "Approaching risky road / I-35E · 89% more crashes than normal today" within a few seconds. Screenshot.
- [ ] **Step 3:** Map page "Simulate a drive" on route 1 with Dec 15 selected. Expected: moving dot, same banner. Route 5 on Aug 25: no banner.
- [ ] **Step 4:** Commit `app: background location, Time Sensitive notification, simulated drive`.

### Task 7: Video dry run and handoff

**Files:**
- Modify: `README.md` credits (Archivo OFL, SF Symbols, Apple frameworks), `docs/superpowers/specs/2026-11-15-app-design.md` (anything that changed while building)

- [ ] **Step 1:** In the Simulator open Apple Maps, start directions along route 1's road, start the `simctl location` route, record with `xcrun simctl io <udid> recordVideo app-drive.mov` (saved outside the repo). Expected: our banner drops in over Maps. If Maps can't navigate in the Simulator, record the Maps app just following the location and say so.
- [ ] **Step 2:** Run all tests (`test_sim`); expected all pass.
- [ ] **Step 3:** Commit `app: credits and notes after the video dry run`; tell the user the branch to merge.
