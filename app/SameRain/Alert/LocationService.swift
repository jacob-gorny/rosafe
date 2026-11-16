import Foundation
import CoreLocation
import Observation
import UIKit
import os

/// The phone's own location, fed fix by fix to the alert engine.
///
/// Permissions, in the order iOS requires: nothing at launch while undecided; "Location off"
/// asks for When In Use; once that's granted it asks for Always (once), then notifications.
/// Updates run in the background (`UIBackgroundModes: location`), so the alert arrives while
/// Apple Maps is in front.
///
/// Privacy (app test 9): each location is turned into a `Fix` and handed on. Nothing here stores,
/// logs or sends a location.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var status: CLAuthorizationStatus = .notDetermined
    private(set) var isUpdating = false

    /// Authorized (When In Use or Always) and receiving updates: the home line's "Watching".
    var isWatching: Bool { Self.isAuthorized(status) && isUpdating }

    /// Every new fix, in order.
    @ObservationIgnored var onFix: ((Fix) -> Void)?
    /// Time to ask for notifications: after the Always question was answered, or at once when
    /// location was already allowed. May run more than once; iOS asks the driver only the first time.
    @ObservationIgnored var onReadyForNotifications: (() -> Void)?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var askedAlways = false
    @ObservationIgnored private var awaitingAlways = false
    @ObservationIgnored private var activeObserver: NSObjectProtocol?

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        // No distance filter: the engine's jitter guard and its 5-second cadence need every fix.
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        status = manager.authorizationStatus
        // Core Location reports the current status to the delegate right away, which starts
        // updates when location is already allowed.
        manager.delegate = self
        // If the driver keeps "While Using" at the Always question, iOS may not call back; the app
        // becoming active again after the prompt is the sign it was answered.
        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.appBecameActive() }
        }
    }

    /// "Location off" was tapped: ask, start, or send the driver to Settings if they said no.
    func requestPermissions() {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            start()
        }
    }

    /// Starts updates if location is allowed. Background updates are switched on only now.
    func start() {
        guard Self.isAuthorized(status), !isUpdating else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
        isUpdating = true
    }

    private func stop() {
        guard isUpdating else { return }
        manager.stopUpdatingLocation()
        isUpdating = false
    }

    nonisolated static func isAuthorized(_ s: CLAuthorizationStatus) -> Bool {
        s == .authorizedWhenInUse || s == .authorizedAlways
    }

    /// A location as the engine sees it, with its real accuracy (the engine's guards need it).
    nonisolated static func fix(from location: CLLocation) -> Fix {
        Fix(coordinate: location.coordinate, speed: location.speed, course: location.course,
            time: location.timestamp, horizontalAccuracy: location.horizontalAccuracy)
    }

    /// Fixes older than this when they arrive are left out.
    nonisolated static let maxFixAge: TimeInterval = 10

    /// True for a current location. Core Location's first delivery after starting can be a cached
    /// one, minutes old and still carrying the speed it had then; fed to the engine, it could alert
    /// a parked driver who just opened the app.
    nonisolated static func isFresh(_ location: CLLocation, now: Date = .now) -> Bool {
        now.timeIntervalSince(location.timestamp) <= maxFixAge
    }

    private func authorizationChanged(_ s: CLAuthorizationStatus) {
        let wasAwaitingAlways = awaitingAlways
        awaitingAlways = false
        status = s
        switch s {
        case .authorizedAlways:
            start()
            onReadyForNotifications?()
        case .authorizedWhenInUse:
            start()
            if !askedAlways {
                askedAlways = true
                awaitingAlways = true
                manager.requestAlwaysAuthorization()
            } else if wasAwaitingAlways {
                onReadyForNotifications?()
            }
        default:
            // Denied, restricted, or undecided again (Settings can reset it): updates stop, so
            // home never says "Watching" without permission.
            stop()
        }
    }

    private func appBecameActive() {
        guard awaitingAlways else { return }
        awaitingAlways = false
        onReadyForNotifications?()
    }

    // MARK: CLLocationManagerDelegate
    // Core Location calls these on the thread that made the manager: the main thread.

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        MainActor.assumeIsolated { authorizationChanged(s) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let now = Date.now
        let fixes = locations.filter { Self.isFresh($0, now: now) }.map(Self.fix(from:))
        MainActor.assumeIsolated {
            for f in fixes { onFix?(f) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let code = (error as? CLError)?.code
        // Only the error code is logged, never a location.
        Self.log.error("Location error \(code?.rawValue ?? -1, privacy: .public)")
        if code == .denied {
            MainActor.assumeIsolated { stop() }
        }
    }

    nonisolated private static let log = Logger(subsystem: "com.samerain.SameRain", category: "location")
}
