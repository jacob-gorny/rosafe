import SwiftUI
import UIKit

/// Daily score: how the whole network runs today against a normal day, the day's weather in three
/// numbers, why, and the busiest roads, predicted against what happened.
/// The score itself sits beside the title (`DailyScoreNumber`).
struct DailyScoreView: View {
    let store: DataStore

    var body: some View {
        if let day = store.day {
            let score = DayMath.dailyScore(day)
            let busiest = store.busiestRows
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScoreLine(text: DayMath.scoreLine(score: score, roads: store.roads.count))
                        .padding(.top, 4)
                    if day.rare {
                        Text(DayMath.rareLine)
                            .captionText()
                            .padding(.top, 2)
                    }
                    DayNumbersRow(numbers: DayMath.dayNumbers(day.weather))
                        .padding(.top, 22)
                    WhyList(lines: DayMath.dayFacts(day), style: .page)
                        .padding(.top, 28)
                    if !busiest.isEmpty {
                        BusiestRoads(rows: busiest)
                            .padding(.top, 26)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollEdgeFade(top: 0)
        }
    }
}

/// The day's score as a signed whole percent: red above a normal day, green below, gray at 0.
struct DailyScoreNumber: View {
    let day: Day

    var body: some View {
        let score = DayMath.dailyScore(day)
        Text(DayMath.dailyScoreText(day))
            .font(Theme.font(28, .bold))
            .monospacedDigit()
            .foregroundStyle(Theme.percentColor(score))
            .lineLimit(1)
            .fixedSize()
            .accessibilityLabel(Self.spoken(score))
    }

    /// "28 percent above a normal day", for VoiceOver.
    static func spoken(_ score: Int) -> String {
        score == 0 ? "About a normal day" : "\(abs(score)) percent \(score > 0 ? "above" : "below") a normal day"
    }
}

/// "Above a normal day, across 850 DFW roads" on one line when it fits; otherwise broken after
/// the comma, so "DFW roads" never hangs alone on a second line.
private struct ScoreLine: View {
    let text: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(text)
                .fixedSize()
            Text(text.replacingOccurrences(of: ", ", with: ",\n"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .captionText()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Three numbers in a row, no boxes: "17 mm" rain, "12" days since rain, "79°F" high. The columns
/// spread across the page, first at the left margin and last at the right. A label wraps before a
/// number ever shrinks; the numbers shrink only if even that doesn't fit.
private struct DayNumbersRow: View {
    let numbers: [DayNumber]

    var body: some View {
        // One line each; else "days since / rain"; else "days / since rain"; else smaller numbers.
        ViewThatFits(in: .horizontal) {
            row(labelWidth: nil, fixed: true)
            row(labelWidth: 84, fixed: true)
            row(labelWidth: 70, fixed: true)
            row(labelWidth: 70, fixed: false)
        }
    }

    /// `labelWidth` caps the middle label ("days since rain", the only long one) so it wraps, to
    /// three lines at the largest text sizes. A capped frame takes the cap's full width, so the short
    /// labels stay uncapped and the last number keeps to the right margin. `fixed` keeps every number
    /// at 28 pt.
    private func row(labelWidth: CGFloat?, fixed: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(numbers.enumerated()), id: \.offset) { i, number in
                let cap = i == 1 ? labelWidth : nil
                if i > 0 { Spacer(minLength: 14) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(number.value)
                        .font(Theme.font(28, .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: fixed, vertical: false)
                    Text(number.label)
                        .captionText()
                        .lineLimit(3)
                        .fixedSize(horizontal: cap == nil, vertical: true)
                        .frame(maxWidth: cap, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// "Busiest roads: predicted, then what happened": one row per surface stretch with a crash level
/// that day, as its name with the surface under it, the model's red "+N%" and the level
/// ("much higher"), all in aligned columns. Each row is one VoiceOver element.
private struct BusiestRoads: View {
    let rows: [BusiestRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Busiest roads: predicted, then what happened")
                .scaledFont(17, .bold, relativeTo: .headline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                ForEach(rows, id: \.roadId) { row in
                    GridRow(alignment: .firstTextBaseline) {
                        // Two stretches of one road can both be here; the surface tells them apart
                        // (and from the same road's other stretch on Roads to avoid).
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.name)
                                .scaledFont(17)
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            if let surface = DayMath.surfaceLabel(row.surface) {
                                Text(surface)
                                    .captionText()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // One VoiceOver element per row: a modifier on a GridRow reaches each
                        // cell, so the first cell speaks the whole row and the others are hidden.
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(row.spokenLabel)
                        Text(DayMath.percentText(row.pred))
                            .scaledFont(17, .bold)
                            .monospacedDigit()
                            .foregroundStyle(Theme.percentColor(DayMath.percent(row.pred)))
                            .fixedSize()
                            .gridColumnAlignment(.trailing)
                            .accessibilityHidden(true)
                        Text(row.level)
                            .captionText(14)
                            .fixedSize()
                            .gridColumnAlignment(.trailing)
                            .accessibilityHidden(true)
                    }
                }
            }
            .padding(.top, 14)
            Text("What happened is a level we worked out from TxDOT's crash records for that road, never a count.")
                .captionText()
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
    }
}

extension BusiestRow {
    /// The row as one VoiceOver line: "I-35E, asphalt over concrete, predicted 66% above normal,
    /// what happened: much higher".
    nonisolated var spokenLabel: String {
        [name, DayMath.surfaceLabel(surface)?.lowercased(),
         "predicted \(RoadsCopy.spokenPercent(pred))", "what happened: \(level)"]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

/// How a "Why" list is set: larger on Daily score, smaller in the road popup.
enum WhyStyle {
    case page, popup

    var heading: CGFloat { self == .page ? 17 : 15 }
    var headingStyle: UIFont.TextStyle { self == .page ? .headline : .subheadline }
    var title: CGFloat { self == .page ? 18 : 16 }
    var detail: CGFloat { self == .page ? 14 : 13 }
    /// Between a bullet's title and its detail.
    var titleGap: CGFloat { self == .page ? 3 : 2 }
    /// Between bullets.
    var spacing: CGFloat { self == .page ? 16 : 12 }
    var top: CGFloat { self == .page ? 10 : 9 }
}

/// "Why", then one bullet per line: a bold fact with its measured detail under it.
struct WhyList: View {
    let lines: [WhyLine]
    var style: WhyStyle = .popup

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Why")
                .scaledFont(style.heading, .bold, relativeTo: style.headingStyle)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: style.spacing) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    WhyBullet(line: line, style: style)
                }
            }
            .padding(.top, style.top)
        }
    }
}

private struct WhyBullet: View {
    let line: WhyLine
    let style: WhyStyle

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Circle()
                .fill(Theme.ink)
                .frame(width: 6, height: 6)
                // Sits on the middle of the title's lowercase letters.
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + style.title * 0.094 }
            VStack(alignment: .leading, spacing: style.titleGap) {
                Text(line.title)
                    .scaledFont(style.title, .semibold)
                    .foregroundStyle(Theme.ink)
                if let detail = line.detail {
                    Text(detail)
                        .captionText(style.detail)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
