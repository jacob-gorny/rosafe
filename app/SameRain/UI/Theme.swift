import SwiftUI
import UIKit
import CoreText

/// Colors and type for the whole app (spec: "The look (decided)").
enum Theme {
    // MARK: Colors

    static let ink = Color(hex: 0x17171B)
    static let caption = Color(hex: 0x6D6D78)
    /// Only for "above normal" numbers.
    static let risk = Color(hex: 0xD42F25)
    /// Flagged roads on the map.
    static let mapLine = Color(hex: 0xE2342E)
    /// A below-normal score.
    static let calm = Color(hex: 0x2F8A57)
    /// The "watching" dot only.
    static let live = Color(hex: 0x22A55B)

    /// A signed percent's color: risk red above 0, calm green below, caption gray at exactly 0.
    static func percentColor(_ n: Int) -> Color {
        n > 0 ? risk : n < 0 ? calm : caption
    }

    /// The flat background tint of the day's weather. No gradients.
    static func tint(for set: SymbolSet) -> Color {
        switch set {
        case .rain: Color(hex: 0xEAF2FC)
        case .ice: Color(hex: 0xE9F6F9)
        case .dry: Color(hex: 0xFBF5EA)
        }
    }

    // Weather symbol colors, on the white tiles.
    static let rainBlue = Color(hex: 0x2D7FF9)
    static let iceCyan = Color(hex: 0x3BB7E0)
    static let fogGray = Color(hex: 0x9AA3B2)
    static let sunYellow = Color(hex: 0xF5A623)
    static let asphalt = Color(hex: 0x3A3F47)
    static let laneYellow = Color(hex: 0xF5C518)
    static let cloud = Color(hex: 0xC9DAF5)
    static let stormCloud = Color(hex: 0x8FA6C8)
    static let umbrellaBlue = Color(hex: 0x1F5FD6)
    /// The tiles' shadows, at 14% (soft) and 8% (hairline).
    static let tileShadow = Color(hex: 0x284678)

    // MARK: Type

    /// Archivo at its widest setting (width axis 125) for all text.
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        font(size, wght: weight.archivoWeight)
    }

    /// Same, with the weight as a number on Archivo's 100...900 axis, so a word can morph
    /// smoothly between two weights (the home word becoming a page title).
    static func font(_ size: CGFloat, wght: CGFloat) -> Font {
        // Rounded so a morph between two sizes reuses a bounded set of fonts.
        let key = FontKey(size: (size * 4).rounded() / 4, wght: wght.rounded())
        if let hit = fontCache[key] { return hit }
        let made: Font
        if let ui = archivo(size: key.size, wght: key.wght) {
            made = Font(ui as CTFont)
        } else {
            made = .system(size: key.size, weight: Font.Weight(archivoWeight: key.wght)).width(.expanded)
        }
        fontCache[key] = made
        return made
    }

    /// The bundled variable font at width 125 and the given weight, or nil if it didn't load.
    static func archivo(size: CGFloat, wght: CGFloat) -> UIFont? {
        guard let base = UIFont(name: "ArchivoRoman-Regular", size: size) else { return nil }
        let axes: [NSNumber: NSNumber] = [
            NSNumber(value: 0x7764_7468): 125,                            // 'wdth'
            NSNumber(value: 0x7767_6874): NSNumber(value: Double(wght)),  // 'wght'
        ]
        let attribute = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = base.fontDescriptor.addingAttributes([attribute: axes])
        return UIFont(descriptor: descriptor, size: size)
    }

    private struct FontKey: Hashable {
        let size: CGFloat
        let wght: CGFloat
    }

    private static var fontCache: [FontKey: Font] = [:]
}

extension Color {
    /// A color from a 0xRRGGBB literal.
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

extension Font.Weight {
    /// Where this weight sits on Archivo's weight axis.
    var archivoWeight: CGFloat {
        switch self {
        case .ultraLight: 100
        case .thin: 200
        case .light: 300
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        case .black: 900
        default: 400
        }
    }

    /// The nearest system weight, for the fallback font.
    init(archivoWeight w: CGFloat) {
        let all: [Font.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        self = all.min { abs($0.archivoWeight - w) < abs($1.archivoWeight - w) } ?? .regular
    }
}

/// A word's size and weight. Animatable, so a home word (38 semibold) can morph into a
/// page title (28 bold) as it flies, using the variable font's weight axis.
nonisolated struct WordStyle: Equatable, Sendable {
    var size: CGFloat
    var wght: CGFloat

    /// Home words: 38 semibold.
    static let home = WordStyle(size: 38, wght: 600)
    /// Page titles: 28 bold.
    static let title = WordStyle(size: 28, wght: 700)
}

extension Theme {
    static func font(_ style: WordStyle) -> Font { font(style.size, wght: style.wght) }
}

// MARK: Dynamic Type

extension Theme {
    /// Body and caption text on the inner pages grow with the reader's text size, up to 1.3 times
    /// the design size, so the wide font still fits the page. Titles and home words stay fixed.
    static let maxTextScale: CGFloat = 1.3

    /// `size` scaled like the system's `style` at the given Dynamic Type size, capped at 1.3×.
    static func scaledSize(_ size: CGFloat, relativeTo style: UIFont.TextStyle,
                           dynamicType: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicType))
        let scaled = UIFontMetrics(forTextStyle: style).scaledValue(for: size, compatibleWith: traits)
        return min(scaled, size * maxTextScale)
    }
}

/// Archivo at a design size that follows Dynamic Type (see `Theme.scaledSize`).
struct ScaledFont: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let style: UIFont.TextStyle
    @Environment(\.dynamicTypeSize) private var dynamicType

    func body(content: Content) -> some View {
        content.font(Theme.font(Theme.scaledSize(size, relativeTo: style, dynamicType: dynamicType), weight))
    }
}

extension View {
    /// Inner-page text (body 16 to 17 pt, the 15 pt "Why") that scales with Dynamic Type.
    func scaledFont(_ size: CGFloat, _ weight: Font.Weight = .regular,
                    relativeTo style: UIFont.TextStyle = .body) -> some View {
        modifier(ScaledFont(size: size, weight: weight, style: style))
    }

    /// Caption text (13 pt unless given, caption gray) that scales with Dynamic Type.
    func captionText(_ size: CGFloat = 13) -> some View {
        modifier(ScaledFont(size: size, weight: .regular, style: .footnote))
            .foregroundStyle(Theme.caption)
    }
}

// MARK: Scrolling

extension View {
    /// Rows dissolve over a short distance where a page's scroll area ends, instead of being cut
    /// mid-letter; matching content margins let the first and last rows rest clear of the fade.
    func scrollEdgeFade(top: CGFloat = 10, bottom: CGFloat = 28) -> some View {
        contentMargins(.top, top, for: .scrollContent)
            .contentMargins(.bottom, bottom, for: .scrollContent)
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: top)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: bottom)
                }
            }
    }
}
