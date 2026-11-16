import SwiftUI
import MapKit

/// Map: Apple Maps in a rounded box, with only the day's flagged roads drawn in red.
/// Every other road is ordinary Apple Maps.
///
/// The road shapes are averaged crash positions (`roads.geojson`), so zoomed in they can sit a
/// little off the real road; the default zoom is city level, where that doesn't show.
struct MapPage<Footer: View>: View {
    let store: DataStore
    /// The simulated car, while a drive runs: drawn as a dot, and the camera follows it.
    let car: CLLocationCoordinate2D?
    /// The slot under the caption: the "Simulate a drive" control.
    @ViewBuilder let footer: () -> Footer

    @State private var camera = MapDefaults.dfwCore
    @Environment(\.pageInset) private var pageInset

    init(store: DataStore, car: CLLocationCoordinate2D? = nil, @ViewBuilder footer: @escaping () -> Footer) {
        self.store = store
        self.car = car
        self.footer = footer
    }

    var body: some View {
        let flagged = store.flagged
        VStack(alignment: .leading, spacing: 0) {
            Map(position: $camera) {
                ForEach(flagged, id: \.road.id) { item in
                    ForEach(item.road.lines.indices, id: \.self) { j in
                        MapPolyline(coordinates: item.road.lines[j])
                            .stroke(Theme.mapLine, lineWidth: 4)
                    }
                }
                UserAnnotation()
                if let car {
                    Annotation("Simulated car", coordinate: car, anchor: .center) {
                        CarDot()
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: 12, x: 0, y: 8)
            // The map box breaks out of the page column to 14 pt from the screen edge, like the
            // prototype's `.mapbox`. It covers the two edge tiles, which hide on this page.
            .padding(.horizontal, 14 - pageInset)
            .padding(.top, 18)
            .onChange(of: car.map { [$0.latitude, $0.longitude] }, initial: true) { old, _ in
                guard let car else { return }
                // A new drive glides to the car; after that the camera moves with it, one point a second.
                let animation: Animation = old == nil ? .easeInOut(duration: 0.6) : .linear(duration: 1)
                withAnimation(animation) {
                    camera = .region(MKCoordinateRegion(center: car, latitudinalMeters: MapDefaults.followMeters,
                                                        longitudinalMeters: MapDefaults.followMeters))
                }
            }

            HStack(spacing: 9) {
                if !flagged.isEmpty {
                    // The key: the red line on the map means a road to avoid.
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.mapLine)
                        .frame(width: 22, height: 4)
                        .accessibilityHidden(true)
                }
                Text(RoadsCopy.mapCaption(flagged.count))
                    .captionText()
            }
            .padding(.top, 16)

            footer()
        }
    }
}

extension MapPage where Footer == EmptyView {
    init(store: DataStore) {
        self.init(store: store, footer: { EmptyView() })
    }
}

/// The simulated car: an ink dot with a white ring, unlike the blue dot of the phone's own location.
private struct CarDot: View {
    var body: some View {
        Circle()
            .fill(Theme.ink)
            .frame(width: 16, height: 16)
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            .accessibilityLabel("Simulated car")
    }
}

enum MapDefaults {
    /// The DFW core, about 40 km across: city level, so every flagged road reads as a line.
    static let dfwCore = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 32.80, longitude: -96.80),
        latitudinalMeters: 40_000, longitudinalMeters: 40_000))

    /// How much the camera shows around the simulated car: a few miles, so the dot visibly moves
    /// and the flagged roads ahead are in view.
    static let followMeters = 9_000.0
}
