#!/usr/bin/env swift
// Dev tool for the demo video. macOS only, run with `swift`. NOT part of the SameRain app target:
// the app's own code makes no network calls. This script asks Apple Maps (MKDirections) for a driving
// route, so the filmed drive follows Apple's own road geometry and stays on the route of Apple
// Maps directions (the Simulator's Maps shows steps, not live navigation) while the Simulator plays it.
//
// Usage:
//   swift app/tools/video-route.swift [startLat startLon endLat endLon] [outFile]
// With no coordinates it uses the filmed drive: east on Singleton Blvd in West Dallas, across
// the Trinity on Commerce St, then south on I-35E through the I-30 interchange to the Dallas Zoo
// (a public place, so Maps shows "To Dallas Zoo", not a house address). Apple picks the roads;
// check the printed steps if traffic changes them.
//
// Writes one "lat,lon" line per point, evenly spaced 23 m apart along the route, to outFile
// (default: $TMPDIR/same-rain-video/video-waypoints.txt). Keep that file outside the repo. Feed it to
//   xcrun simctl location <udid> start --speed=24 --interval=1 - < video-waypoints.txt
// simctl seems to spend at least one update on every waypoint, so the points sit a little closer
// than 24 m: the car then moves one point a second (about 23 m/s, 51 mph). With uneven, shorter
// spacing the same command crawled at about 13 m/s.

import Foundation
import MapKit

let spacing = 23.0 // meters between written points

var args = Array(CommandLine.arguments.dropFirst())
var start = CLLocationCoordinate2D(latitude: 32.7786, longitude: -96.8276)
var end = CLLocationCoordinate2D(latitude: 32.7406, longitude: -96.8153)
if args.count >= 4, let a = Double(args[0]), let b = Double(args[1]), let c = Double(args[2]), let d = Double(args[3]) {
    start = CLLocationCoordinate2D(latitude: a, longitude: b)
    end = CLLocationCoordinate2D(latitude: c, longitude: d)
    args.removeFirst(4)
}
let outURL: URL = args.first.map { URL(fileURLWithPath: $0) }
    ?? FileManager.default.temporaryDirectory
        .appendingPathComponent("same-rain-video", isDirectory: true)
        .appendingPathComponent("video-waypoints.txt")

func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    CLLocation(latitude: a.latitude, longitude: a.longitude)
        .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}

func fmt(_ c: CLLocationCoordinate2D) -> String {
    String(format: "%.6f,%.6f", c.latitude, c.longitude)
}

let request = MKDirections.Request()
request.source = MKMapItem(location: CLLocation(latitude: start.latitude, longitude: start.longitude), address: nil)
request.destination = MKMapItem(location: CLLocation(latitude: end.latitude, longitude: end.longitude), address: nil)
request.transportType = .automobile
request.requestsAlternateRoutes = false

let response: MKDirections.Response
do {
    response = try await MKDirections(request: request).calculate()
} catch {
    FileHandle.standardError.write(Data("Directions failed: \(error)\n".utf8))
    exit(1)
}
guard let route = response.routes.first else {
    FileHandle.standardError.write(Data("No route returned\n".utf8))
    exit(1)
}

// The route's polyline, resampled to one point every `spacing` meters along it, plus the end.
let polyline = route.polyline
let raw = UnsafeBufferPointer(start: polyline.points(), count: polyline.pointCount).map(\.coordinate)
var dense: [CLLocationCoordinate2D] = [raw[0]]
var nextMark = spacing   // distance along the route of the next point to write
var travelled = 0.0      // distance along the route at the start of the current segment
for i in 1..<raw.count {
    let q = raw[i - 1], p = raw[i]
    let len = meters(q, p)
    while len > 0, nextMark <= travelled + len {
        let t = (nextMark - travelled) / len
        dense.append(CLLocationCoordinate2D(latitude: q.latitude + (p.latitude - q.latitude) * t,
                                            longitude: q.longitude + (p.longitude - q.longitude) * t))
        nextMark += spacing
    }
    travelled += len
}
if let last = raw.last, meters(dense.last!, last) > 1 { dense.append(last) }

try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try dense.map(fmt).joined(separator: "\n").appending("\n").write(to: outURL, atomically: true, encoding: .utf8)

print("Requested start: \(fmt(start))")
print("Requested end:   \(fmt(end))")
print("Route start:     \(fmt(raw.first!))")
print("Route end:       \(fmt(raw.last!))")
print(String(format: "Route: %.0f m, %.0f s expected, %d polyline points, %d written",
             route.distance, route.expectedTravelTime, raw.count, dense.count))
for step in route.steps where !step.instructions.isEmpty {
    print(String(format: "  %6.0f m  %@", step.distance, step.instructions))
}
print("Waypoints: \(outURL.path)")
// Maps only follows the drive when the route starts at "My Location", so set the Simulator there first.
print("Simulator start: xcrun simctl location <udid> set \(fmt(raw.first!))")
print("Apple Maps: maps://?daddr=\(fmt(raw.last!))&dirflg=d")
