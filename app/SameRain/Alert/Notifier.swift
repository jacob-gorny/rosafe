import Foundation
import UserNotifications
import os

/// Whatever shows the alert to the driver. The app uses `Notifier`; tests use a fake.
@MainActor
protocol NotificationSending: AnyObject {
    func send(road: Road, pred: Double)
    /// Runs `then` once the driver has been asked about notifications: after the one-time prompt
    /// if they never were, else right away.
    func askIfUndecided(then: @escaping @MainActor () -> Void)
}

extension NotificationSending {
    /// Nothing to ask: runs `then` at once (the tests' fake).
    func askIfUndecided(then: @escaping @MainActor () -> Void) { then() }
}

/// The phone notification: "Approaching risky road / I-35E · 66% more crashes than normal today".
/// A local notification, Time Sensitive so it can break through Focus (Driving Focus included) when
/// the driver allows it, with the default sound. No push server; nothing leaves the phone.
final class Notifier: NSObject, NotificationSending, UNUserNotificationCenterDelegate {
    nonisolated static let title = "Approaching risky road"

    /// Called with the road id when the driver taps a notification.
    var onOpenRoad: ((String) -> Void)?

    nonisolated static func content(road: Road, pred: Double) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "\(road.displayName) \u{00B7} \(DayMath.percent(pred))% more crashes than normal today"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["roadId": road.id]
        return content
    }

    /// True when the driver has never been asked about notifications.
    nonisolated static func isUndecided() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined
    }

    /// A phone that never went through the location flow was never asked about notifications;
    /// it is asked now, and `then` runs once that is answered (at once if it was asked before).
    func askIfUndecided(then: @escaping @MainActor () -> Void) {
        Task {
            if await Self.isUndecided() { await Self.requestAuthorization() }
            then()
        }
    }

    /// Asks for banners and sound. iOS shows the prompt only the first time.
    static func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            Self.log.error("Notification permission failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Makes this the notification center's delegate. Call it at launch, so a tap that opens the
    /// app reaches `onOpenRoad`. The center holds its delegate weakly; the coordinator keeps this.
    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Shows the notification now (no trigger), under a fresh identifier so none replaces another.
    func send(road: Road, pred: Double) {
        let request = UNNotificationRequest(identifier: "alert-\(road.id)-\(UUID().uuidString)",
                                            content: Self.content(road: road, pred: pred), trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Notifier.log.error("Couldn't show the alert: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: UNUserNotificationCenterDelegate
    // The completion-handler forms, not the async ones: the async forms' bridge calls the system's
    // completion handler from a background thread, and UIKit then stops the app ("Call must be
    // made on main thread"; found tapping a notification in the Simulator). Here the handler is
    // always called on the main thread.

    /// With the app in front (a simulated drive), still show the banner and play the sound.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler:
                                            @escaping (UNNotificationPresentationOptions) -> Void) {
        Self.onMain { completionHandler([.banner, .list, .sound]) }
    }

    /// A tap opens that road's popup.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let roadId = response.actionIdentifier == UNNotificationDefaultActionIdentifier
            ? response.notification.request.content.userInfo["roadId"] as? String : nil
        Self.onMain {
            if let roadId { self.onOpenRoad?(roadId) }
            completionHandler()
        }
    }

    /// Runs `work` on the main thread: now if already there (iOS calls these delegate methods on
    /// the main thread), else on the main queue.
    nonisolated private static func onMain(_ work: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { work() }
        } else {
            DispatchQueue.main.async { work() }
        }
    }

    nonisolated private static let log = Logger(subsystem: "com.samerain.SameRain", category: "alert")
}
