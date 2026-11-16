import SwiftUI

/// What the Roads to avoid page shows: the list, or the empty state on a day with no alerts.
enum RoadsPageState: Equatable {
    case empty
    case list(count: Int)

    init(flaggedCount: Int) {
        self = flaggedCount > 0 ? .list(count: flaggedCount) : .empty
    }
}

/// The words on Roads to avoid and under the map.
nonisolated enum RoadsCopy {
    static let emptyTitle = "Nothing to avoid today."
    static let emptyDetail = "No road is running much above its normal."

    /// Under the list: "127 roads today".
    static func countLine(_ n: Int) -> String { n == 1 ? "1 road today" : "\(n) roads today" }

    /// Under the map: "127 roads to avoid today", or "Nothing flagged today."
    static func mapCaption(_ n: Int) -> String {
        switch n {
        case 0: "Nothing flagged today."
        case 1: "1 road to avoid today"
        default: "\(n) roads to avoid today"
        }
    }

    /// VoiceOver label for a row: "US 175, 109% above normal".
    static func rowLabel(name: String, pred: Double) -> String {
        "\(name), \(spokenPercent(pred))"
    }

    /// "109% above normal", "15% below normal" or "about normal".
    static func spokenPercent(_ pred: Double) -> String {
        let n = DayMath.percent(pred)
        return n == 0 ? "about normal" : "\(abs(n))% \(n > 0 ? "above" : "below") normal"
    }
}

/// Roads to avoid: the day's flagged roads, worst first, as a name and a red "+N%".
/// Tapping a row opens that road's popup.
struct RoadsView: View {
    let store: DataStore
    let onOpenRoad: (String) -> Void

    var body: some View {
        let flagged = store.flagged
        switch RoadsPageState(flaggedCount: flagged.count) {
        case .empty:
            VStack(alignment: .leading, spacing: 4) {
                Text(RoadsCopy.emptyTitle)
                    .scaledFont(17)
                    .foregroundStyle(Theme.ink)
                Text(RoadsCopy.emptyDetail)
                    .captionText()
            }
            .padding(.top, 18)
        case .list(let count):
            let captioned = DayMath.needsSurfaceCaption(flagged.map(\.road))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(flagged, id: \.road.id) { item in
                        RoadRow(road: item.road, pred: item.pred,
                                showsSurface: captioned.contains(item.road.id)) {
                            onOpenRoad(item.road.id)
                        }
                    }
                    Text(RoadsCopy.countLine(count))
                        .captionText()
                        .padding(.top, 6)
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeFade()
        }
    }
}

private struct RoadRow: View {
    let road: Road
    let pred: Double
    let showsSurface: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(road.displayName)
                        .scaledFont(17, .medium)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    // Two surface stretches of one road share a name; the surface tells them apart.
                    if showsSurface, let surface = DayMath.surfaceLabel(road.surface) {
                        Text(surface)
                            .captionText()
                    }
                }
                Spacer(minLength: 0)
                Text(DayMath.percentText(pred))
                    .scaledFont(17, .semibold)
                    .monospacedDigit()
                    .foregroundStyle(Theme.percentColor(DayMath.percent(pred)))
                    .fixedSize()
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPress())
        .accessibilityLabel(RoadsCopy.rowLabel(name: road.displayName, pred: pred)
                            + (showsSurface ? ", " + (DayMath.surfaceLabel(road.surface) ?? "") : ""))
        .accessibilityHint("Shows why this road is flagged")
    }
}

/// A row dims while pressed, instead of a highlight box.
struct RowPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.45 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
