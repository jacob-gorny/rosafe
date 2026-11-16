import SwiftUI

/// Under the map: "Simulate a drive", or while one runs, what it is and a way to end it.
struct DriveControls: View {
    let store: DataStore
    let coordinator: AppCoordinator
    let onPickRoute: () -> Void

    var body: some View {
        Group {
            if coordinator.drive != nil {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(DriveCopy.running)
                        .scaledFont(16, .medium)
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 8)
                    Button { coordinator.endDrive() } label: {
                        Text("End drive")
                            .scaledFont(16, .semibold)
                            .foregroundStyle(Theme.ink)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(RowPress())
                }
            } else if !coordinator.routes.isEmpty {
                Button(action: onPickRoute) {
                    HStack(spacing: 8) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .accessibilityHidden(true)
                        Text("Simulate a drive")
                            .scaledFont(16, .semibold)
                    }
                    .foregroundStyle(Theme.ink)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowPress())
                .accessibilityHint("Replays a demo drive through the real alert, at five times speed")
            }
        }
        .padding(.top, 6)
        // Warm the route picker's counts while the map is up, so the sheet opens with them.
        .task(id: store.selectedDate) { _ = await coordinator.loadAlertCounts() }
    }
}

/// The sheet behind "Simulate a drive": the five demo drives, each with how many alerts it sends
/// on the selected day (worked out by running it through the alert code). Picking one starts it.
struct RoutePicker: View {
    let store: DataStore
    let coordinator: AppCoordinator
    @State private var counts: [Int]?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Simulate a drive")
                    .font(Theme.font(28, .bold))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                // Plain words: Archivo has no multiplication sign.
                Text("A demo drive at 5 times real speed, through the real alert, with the roads flagged on \(DayLabel.long(store.selectedDate)).")
                    .captionText()
                    .padding(.top, 4)

                VStack(spacing: 0) {
                    ForEach(coordinator.routes.indices, id: \.self) { i in
                        let route = coordinator.routes[i]
                        RouteRow(label: route.label, caption: counts.map { DriveCopy.alertsLine($0[i]) }) {
                            coordinator.startDrive(route)
                            dismiss()
                        }
                    }
                }
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 34)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: store.selectedDate) { counts = await coordinator.loadAlertCounts() }
    }
}

private struct RouteRow: View {
    let label: String
    /// "2 alerts today"; nil while it's being worked out.
    let caption: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .scaledFont(17, .medium)
                    .foregroundStyle(Theme.ink)
                Text(caption ?? " ")
                    .captionText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPress())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Starts this drive")
    }
}
