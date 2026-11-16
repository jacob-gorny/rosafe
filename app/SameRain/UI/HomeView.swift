import SwiftUI

/// Home: a greeting, three words that each open a page, and one quiet line at the bottom.
/// It stays in place while a page is open (its parts fade out), so the tapped word can fly
/// into the page title and back.
struct HomeView: View {
    let namespace: Namespace.ID
    /// The open page, or nil when home is showing.
    let page: Page?
    let screen: ScreenFrame
    /// The selected day, like "Dec 15, 2023"; nil when the road scores couldn't be read.
    let dateText: String?
    /// True when location is allowed (While Using or Always) and updates are running.
    var isWatching = false
    let onOpen: (Page) -> Void
    var onPickDay: () -> Void = {}
    var onTurnOnLocation: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var onHome: Bool { page == nil }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if onHome {
                Greeting()
                    .padding(.leading, 24)
                    .padding(.top, screen.insets.top + 10)
                    .transition(.opacity)
            }

            if let dateText {
                words
                    .position(x: screen.size.width / 2, y: screen.size.height * 0.468)
                if onHome {
                    bottomLine(date: dateText)
                        .position(x: screen.size.width / 2, y: screen.size.height - screen.insets.bottom - 22)
                        .transition(.opacity)
                }
            } else {
                // The scores didn't load: say so plainly, and offer nothing to open.
                Text("Couldn't read the road scores")
                    .font(Theme.font(17))
                    .foregroundStyle(Theme.ink)
                    .position(x: screen.size.width / 2, y: screen.size.height * 0.468)
            }
        }
        .frame(width: screen.size.width, height: screen.size.height, alignment: .topLeading)
    }

    private var words: some View {
        VStack(spacing: 2) {
            ForEach(Page.allCases) { p in
                ZStack {
                    // Holds the slot, so the other words stay put while this one is away.
                    Text(p.title)
                        .font(Theme.font(.home))
                        .fixedSize()
                        .hidden()
                    if page != p {
                        Button { onOpen(p) } label: {
                            MorphingWord(text: p.title, rest: .home)
                        }
                        .buttonStyle(PressScale())
                        .matchedWord(p, in: namespace, enabled: !reduceMotion)
                        .opacity(onHome ? 1 : 0)
                        .transition(reduceMotion ? .wordFade(rest: .home) : .wordMorph(from: .title, rest: .home))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .allowsHitTesting(onHome)
        // Faded out while a page is open, so VoiceOver skips them too.
        .accessibilityHidden(!onHome)
    }

    /// One quiet line: "Watching for risky roads · Sep 23, 2024" with a live dot, or
    /// "Location off · Sep 23, 2024". The date opens the day picker in both states; "Location off"
    /// starts turning location on. Each tap target is at least 44 pt tall.
    private func bottomLine(date: String) -> some View {
        HStack(spacing: 0) {
            if isWatching {
                HStack(spacing: 7) {
                    Circle()
                        .fill(Theme.live)
                        .frame(width: 8, height: 8)
                        .background {
                            Circle().fill(Theme.live.opacity(0.18)).frame(width: 16, height: 16)
                        }
                        .accessibilityHidden(true)
                    Text("Watching for risky roads")
                }
            } else {
                Button(action: onTurnOnLocation) {
                    Text("Location off").tapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityHint("Turns on location so the app can warn you about risky roads")
            }
            Text(" · ")
                .accessibilityHidden(true)
            Button(action: onPickDay) {
                Text(date).tapTarget()
            }
            .buttonStyle(.plain)
            .accessibilityHint("Picks another day")
        }
        .font(Theme.font(13))
        .foregroundStyle(Theme.caption)
        .lineLimit(1)
        .fixedSize()
    }
}

private extension View {
    /// At least 44 pt tall to tap, without changing how the line looks.
    func tapTarget() -> some View {
        frame(minHeight: 44).contentShape(Rectangle())
    }
}

/// "Good morning", "Good afternoon" or "Good evening" by the phone's clock. Never a name.
struct Greeting: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(Self.text(at: context.date))
                .font(Theme.font(34, .bold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// 5 to 11 morning, 12 to 16 afternoon, otherwise evening.
    nonisolated static func text(at date: Date, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5...11: "Good morning"
        case 12...16: "Good afternoon"
        default: "Good evening"
        }
    }
}

/// How a scores-file date reads on screen.
nonisolated enum DayLabel {
    /// "2023-12-15" → "Dec 15, 2023". Dates are calendar days, so this works in UTC.
    static func long(_ iso: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: iso) else { return iso }
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
