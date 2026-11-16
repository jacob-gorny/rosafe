import SwiftUI
import UIKit

/// The day's weather as seven soft tiles: white rounded squares, each holding one colored SF Symbol,
/// floating gently around the words on home. On an inner page three of them glide to the screen
/// edges, half cut off, and the other four slide out. Style C ("soft tiles") of the approved
/// mockup `five-styles-v3.html`.
struct WeatherTilesLayer: View {
    /// Seven symbol names, in the order of `TileLayout.home` (`WeatherTiles.symbols`).
    let symbols: [String]
    /// True while an inner page is open.
    let onPage: Bool
    /// True on the Map page: its map box covers the two edge tiles, so they step away (fade)
    /// instead of peeking out beside the map.
    var hideSides = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            if reduceMotion {
                // No float, no glide: the two arrangements simply crossfade.
                ZStack {
                    field(in: geo.size, onPage: false).opacity(onPage ? 0 : 1)
                    field(in: geo.size, onPage: true).opacity(onPage ? 1 : 0)
                }
                .animation(.easeInOut(duration: 0.3), value: onPage)
            } else {
                field(in: geo.size, onPage: onPage)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func field(in size: CGSize, onPage: Bool) -> some View {
        ZStack {
            ForEach(symbols.indices, id: \.self) { i in
                let spot = TileLayout.spot(i, onPage: onPage, in: size)
                let isSide = TileLayout.pageSpot(i).map { $0 != .corner } ?? false
                WeatherTile(symbol: symbols[i], index: i, floats: !reduceMotion)
                    // The glide: a little overshoot, 25 ms apart per tile, whatever animation the
                    // page change itself carries.
                    .animation(TileLayout.glide.delay(Double(i) * 0.025)) { content in
                        content
                            .rotationEffect(.degrees(spot.turn))
                            .opacity(spot.shown ? 1 : 0)
                            .position(x: spot.x, y: spot.y)
                    }
                    .opacity(hideSides && isSide ? 0 : 1)
                    .animation(.easeInOut(duration: 0.25), value: hideSides)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

/// One tile: 76 pt, white, corner radius 22, a soft shadow and a hairline one, the symbol in the
/// middle. It floats ±5 pt on its own slow cycle; a new day's symbol crossfades in.
private struct WeatherTile: View {
    let symbol: String
    let index: Int
    let floats: Bool

    @State private var drifted = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: TileLayout.cornerRadius, style: .continuous)
        // Even tiles start high and odd ones low, so neighbours move against each other.
        let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
        ZStack {
            shape.fill(.white)
                .shadow(color: Theme.tileShadow.opacity(0.14), radius: 14, x: 0, y: 10)
            shape.fill(.white)
                .shadow(color: Theme.tileShadow.opacity(0.08), radius: 1, x: 0, y: 1)
            TileGlyph(name: symbol)
                .id(symbol)
                .transition(.opacity)
        }
        .frame(width: TileLayout.side, height: TileLayout.side)
        .animation(.easeInOut(duration: 0.4), value: symbol)
        .offset(y: floats ? (drifted ? direction : -direction) * TileLayout.float : 0)
        .onAppear {
            // One 7 s swing each way, forever; the start is staggered so the tiles never move in step.
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true).delay(Double(index) * 0.9)) {
                drifted = true
            }
        }
    }
}

/// A tile's symbol in the app's weather colors, fitted to a 50 × 40 pt box.
private struct TileGlyph: View {
    let name: String

    var body: some View {
        let ink = Self.palette(name)
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.palette)
            .foregroundStyle(ink.0, ink.1, ink.2)
            .frame(width: 50, height: 40)
    }

    /// Palette layers, first to last. Never red: red means risk only.
    static func palette(_ name: String) -> (Color, Color, Color) {
        switch name {
        case "cloud.rain.fill", "cloud.drizzle.fill": (Theme.cloud, Theme.rainBlue, Theme.rainBlue)
        // The bolt shares the cloud's layer, so it takes the storm-cloud slate.
        case "cloud.bolt.rain.fill": (Theme.stormCloud, Theme.rainBlue, Theme.rainBlue)
        case "drop.fill": (Theme.rainBlue, Theme.rainBlue, Theme.rainBlue)
        case "umbrella.fill": (Theme.umbrellaBlue, Theme.umbrellaBlue, Theme.umbrellaBlue)
        // Layers: the mercury, the sun or snowflake, the thermometer's outline.
        case "thermometer.sun.fill": (Theme.caption, Theme.sunYellow, Theme.sunYellow)
        case "thermometer.snowflake": (Theme.caption, Theme.iceCyan, Theme.iceCyan)
        case "snowflake": (Theme.iceCyan, Theme.iceCyan, Theme.iceCyan)
        case "cloud.snow.fill": (Theme.cloud, Theme.iceCyan, Theme.iceCyan)
        case "exclamationmark.triangle.fill": (Theme.ink, Theme.laneYellow, Theme.laneYellow)
        case "wind": (Theme.stormCloud, Theme.stormCloud, Theme.stormCloud)
        case "cloud.fog.fill": (Theme.fogGray, Theme.fogGray, Theme.fogGray)
        case "sun.max.fill": (Theme.sunYellow, Theme.sunYellow, Theme.sunYellow)
        case "cloud.sun.fill": (Theme.cloud, Theme.sunYellow, Theme.sunYellow)
        case "sun.haze.fill": (Theme.sunYellow, Theme.fogGray, Theme.fogGray)
        // car.fill, road.lanes, sunglasses.fill.
        default: (Theme.asphalt, Theme.asphalt, Theme.asphalt)
        }
    }
}

/// Which seven symbols the tiles show, in the order of `TileLayout.home`. All seven differ.
enum WeatherTiles {
    static func symbols(for day: Day) -> [String] {
        symbols(for: DayMath.symbolSet(day.weather, rare: day.rare), reasons: day.reasons)
    }

    /// Fog swaps the wind tile for a fog cloud. On rain days, "Rain after N hot days" swaps the
    /// drizzle cloud for a hot thermometer.
    static func symbols(for set: SymbolSet, reasons: [String]) -> [String] {
        let mist = { (fog: Bool) in fog ? "cloud.fog.fill" : "wind" }
        switch set {
        case let .rain(fog, thunder):
            let hot = reasons.contains { $0.hasPrefix("Rain after") }
            return [thunder ? "cloud.bolt.rain.fill" : "cloud.rain.fill", "drop.fill", "umbrella.fill", "car.fill",
                    "road.lanes", hot ? "thermometer.sun.fill" : "cloud.drizzle.fill", mist(fog)]
        case let .ice(fog):
            return ["snowflake", "thermometer.snowflake", "cloud.snow.fill", "car.fill", "road.lanes",
                    "exclamationmark.triangle.fill", mist(fog)]
        case let .dry(fog):
            return ["sun.max.fill", "thermometer.sun.fill", "cloud.sun.fill", "car.fill", "road.lanes",
                    sunglasses, mist(fog)]
        }
    }

    /// Sunglasses, or sun haze on a system whose SF Symbols lack them.
    private static let sunglasses = UIImage(systemName: "sunglasses.fill") != nil ? "sunglasses.fill" : "sun.haze.fill"
}

/// Where a tile sits: its center in points, its turn in degrees, and whether it shows.
nonisolated struct TileSpot: Equatable, Sendable {
    var x: CGFloat
    var y: CGFloat
    var turn: Double
    var shown: Bool
}

nonisolated enum TileLayout {
    static let side: CGFloat = 76
    static let cornerRadius: CGFloat = 22
    /// How far a tile floats up and down, in points.
    static let float: CGFloat = 5
    /// The least space between a page tile and the page column.
    static let gap: CGFloat = 8

    /// Home spots as fractions of the screen, with their turns: the mockup's points on its
    /// 402 × 874 pt screen. They clear the greeting, the words and the bottom line from the
    /// iPhone SE's 375 × 667 up.
    static let home: [(x: CGFloat, y: CGFloat, turn: Double)] = [
        (340, 196, 6), (70, 214, -8), (20, 520, 10), (384, 560, -6), (110, 690, 4), (300, 700, -4), (400, 296, 8),
    ].map { (x: $0.0 / 402, y: $0.1 / 874, turn: $0.2) }

    /// The three tiles an inner page keeps: the day's main symbol on the right edge, the second
    /// weather symbol on the left edge and the car in the bottom-right corner.
    enum PageSpot { case rightEdge, leftEdge, corner }

    static func pageSpot(_ i: Int) -> PageSpot? {
        switch i {
        case 0: .rightEdge
        case 2: .leftEdge
        case 3: .corner
        default: nil
        }
    }

    /// The inner pages' side margin: 48 pt, so a half-cut edge tile clears the text by `gap`; less
    /// on narrow phones, where the title and its score need 300 pt (the edge tiles then show less).
    static func pageInset(width: CGFloat) -> CGFloat {
        min(48, max(32, ((width - 300) / 2).rounded(.down)))
    }

    /// The space under the page column: it clears the corner tile, floating, by 8 pt.
    static let pageBottom: CGFloat = 64

    /// The glide between home and page spots.
    static let glide = Animation.spring(response: 0.6, dampingFraction: 0.72)

    /// Half the width of a tile turned by `turn` degrees: how far it reaches from its center.
    static func reach(_ turn: Double) -> CGFloat {
        let r = turn * .pi / 180
        return side / 2 * CGFloat(abs(cos(r)) + abs(sin(r)))
    }

    static func spot(_ i: Int, onPage: Bool, in size: CGSize) -> TileSpot {
        let h = home[i % home.count]
        let atHome = TileSpot(x: h.x * size.width, y: h.y * size.height, turn: h.turn, shown: true)
        guard onPage else { return atHome }
        let inset = pageInset(width: size.width)
        switch pageSpot(i) {
        case .rightEdge:
            let turn = 3.0
            return TileSpot(x: size.width - (inset - gap) + reach(turn), y: size.height * 0.40, turn: turn, shown: true)
        case .leftEdge:
            let turn = -3.0
            return TileSpot(x: inset - gap - reach(turn), y: size.height * 0.72, turn: turn, shown: true)
        case .corner:
            let turn = -4.0
            return TileSpot(x: size.width - 26, y: size.height - pageBottom + 8 + float + reach(turn),
                            turn: turn, shown: true)
        case nil:
            // Out past the nearest side edge, at the same height.
            let r = reach(h.turn) + 12
            return TileSpot(x: atHome.x < size.width / 2 ? -r : size.width + r, y: atHome.y, turn: h.turn, shown: false)
        }
    }
}
