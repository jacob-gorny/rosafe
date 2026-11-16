import SwiftUI

/// The road popup (a sheet): the road's name and score today, then why, all facts from the data.
struct RoadPopup: View {
    let store: DataStore
    let roadId: String

    var body: some View {
        Group {
            if let i = store.roadIndex[roadId], let day = store.day {
                content(road: store.roads[i], day: day,
                        pred: store.pred(roadId: roadId, date: store.selectedDate))
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func content(road: Road, day: Day, pred: Double?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(road.displayName)
                        .font(Theme.font(28, .bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    if let pred {
                        Text(DayMath.percentText(pred))
                            .font(Theme.font(28, .bold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.percentColor(DayMath.percent(pred)))
                            .fixedSize()
                            .accessibilityLabel(RoadsCopy.spokenPercent(pred))
                    }
                }
                WhyList(lines: DayMath.roadWhy(road: road, pred: pred ?? 1, day: day,
                                               levelNames: store.actualLevelNames))
                    .padding(.top, 20)
                Text(DayMath.checkedLine(road))
                    .captionText()
                    .padding(.top, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 34)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
    }
}
