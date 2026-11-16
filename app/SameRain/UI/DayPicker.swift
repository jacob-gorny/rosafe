import SwiftUI

/// A demo day worth showing, with a 1 to 3 word label.
nonisolated struct QuickPick: Equatable, Identifiable, Sendable {
    let date: String
    let label: String
    var id: String { date }
}

nonisolated enum QuickPicks {
    /// In this order. 2024 is the test year (opened once); 2023 is the practice year.
    /// Sep 23, 2024 is the video's demo day. Aug 19, 2024 is the hottest 2024 day with no rain,
    /// fog, thunder, ice or holiday and no alerts (picked by that rule, not by what happened).
    static let all: [QuickPick] = [
        QuickPick(date: "2024-09-23", label: "First rain"),
        QuickPick(date: "2024-04-20", label: "Storm"),
        QuickPick(date: "2024-08-19", label: "Hot and dry"),
        QuickPick(date: "2023-12-15", label: "First rain"),
        QuickPick(date: "2023-01-30", label: "Ice"),
        QuickPick(date: "2023-08-25", label: "Dry"),
    ]

    /// The quick picks whose day is loaded, in order.
    static func available(_ isLoaded: (String) -> Bool) -> [QuickPick] {
        all.filter { isLoaded($0.date) }
    }
}

/// The day picker (a sheet): the demo days first, then a calendar limited to the loaded years.
/// Picking a day shows it everywhere and closes the sheet.
struct DayPicker: View {
    let store: DataStore
    let onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pick a day")
                    .font(Theme.font(28, .bold))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("2024 is the test year the model never saw. 2023 is the practice year.")
                    .captionText()
                    .padding(.top, 4)

                VStack(spacing: 0) {
                    ForEach(QuickPicks.available(store.isLoaded)) { pick in
                        QuickPickRow(pick: pick, selected: pick.date == store.selectedDate) {
                            choose(pick.date, after: .zero)
                        }
                    }
                }
                .padding(.top, 12)

                if let range = calendarRange {
                    DatePicker("Day", selection: calendarDate, in: range, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(Theme.ink)
                        .environment(\.timeZone, CalendarDay.utc)
                        .environment(\.calendar, CalendarDay.calendar)
                        .padding(.top, 14)
                        .padding(.horizontal, -8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 34)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var calendarRange: ClosedRange<Date>? {
        guard let r = store.dateRange,
              let first = CalendarDay.date(r.lowerBound), let last = CalendarDay.date(r.upperBound) else { return nil }
        return first...last
    }

    /// The calendar works in UTC days, so a picked day maps straight to a scores-file date.
    private var calendarDate: Binding<Date> {
        Binding {
            CalendarDay.date(store.selectedDate) ?? .now
        } set: { picked in
            // Leave a beat so the picked day's circle shows before the sheet closes.
            choose(CalendarDay.string(picked), after: .milliseconds(350))
        }
    }

    private func choose(_ date: String, after delay: Duration) {
        guard store.isLoaded(date) else { return }
        onPick(date)
        Task { @MainActor in
            if delay > .zero { try? await Task.sleep(for: delay) }
            dismiss()
        }
    }
}

private struct QuickPickRow: View {
    let pick: QuickPick
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(DayLabel.long(pick.date))
                    .scaledFont(17, selected ? .semibold : .medium)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(pick.label)
                    .scaledFont(16)
                    .foregroundStyle(selected ? Theme.ink : Theme.caption)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .opacity(selected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPress())
        .accessibilityLabel("\(DayLabel.long(pick.date)), \(pick.label)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Scores-file dates ("2024-09-23") as calendar days in UTC, for the date picker.
nonisolated enum CalendarDay {
    static let utc = TimeZone(identifier: "UTC")!

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = utc
        return c
    }

    private static var formatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = utc
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    static func date(_ iso: String) -> Date? { formatter.date(from: iso) }
    static func string(_ date: Date) -> String { formatter.string(from: date) }
}
