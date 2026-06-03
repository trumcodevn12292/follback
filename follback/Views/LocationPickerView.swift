import SwiftUI
import MapKit
import CoreLocation
import Combine

struct LocationPickerView: View {
    @Binding var locationName: String?
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = LocationPickerManager()
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPin: CLLocationCoordinate2D?
    @State private var resolvedAddress: String?
    @State private var hasUserSelection = false

    var body: some View {
        ZStack {
            Color.filmBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.filmText)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.filmSurface))
                    }
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Map
                MapReader { reader in
                    Map(position: $cameraPosition) {
                        if let pin = selectedPin {
                            Marker("", coordinate: pin)
                                .tint(Color.filmAccent)
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .onTapGesture { position in
                        if let coord = reader.convert(position, from: .local) {
                            hasUserSelection = true
                            withAnimation {
                                selectedPin = coord
                            }
                            reverseGeocode(coord)
                            searchResults = []
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // Bottom card
                VStack(spacing: 14) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundColor(Color.filmTertiary)
                        TextField("Search location...", text: $searchText)
                            .font(.system(size: 15))
                            .foregroundColor(Color.filmText)
                            .onSubmit { performSearch() }
                        .onChange(of: searchText) { _, newValue in
                            if newValue.count >= 2 {
                                performSearch()
                            } else if newValue.isEmpty {
                                searchResults = []
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.filmSurface)
                    )

                    // Search results
                    if !searchResults.isEmpty {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                ForEach(searchResults, id: \.self) { item in
                                    Button {
                                        selectMapItem(item)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name ?? "Unknown")
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundColor(Color.filmText)
                                                    .lineLimit(1)
                                                if let subtitle = formattedAddress(for: item) {
                                                    Text(subtitle)
                                                        .font(.system(size: 12))
                                                        .foregroundColor(Color.filmTertiary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.filmTertiary)
                                        }
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().background(Color.filmBorder.opacity(0.2))
                                }
                            }
                        }
                        .frame(maxHeight: 160)
                    }

                    // Current location address
                    if let address = resolvedAddress {
                        Text(address)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color.filmText)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }

                    // Use current location button
                    Button {
                        locationManager.requestLocation()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                            Text("Use Current Location")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(Color.filmAccent)
                    }
                    .buttonStyle(.plain)

                    // Confirm button
                    Button {
                        locationName = resolvedAddress
                        if let pin = selectedPin {
                            self.latitude = pin.latitude
                            self.longitude = pin.longitude
                        }
                        dismiss()
                    } label: {
                        Text("Confirm Location")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color.filmText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.filmSurface)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.filmBackground)
                )
            }
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.currentLatitude) { _, newLat in
            guard !hasUserSelection else { return }
            guard let lat = newLat, let lng = locationManager.currentLongitude else { return }
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            selectedPin = coord
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
            reverseGeocode(coord)
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        if let pin = selectedPin {
            request.region = MKCoordinateRegion(
                center: pin,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        MKLocalSearch(request: request).start { response, _ in
            searchResults = response?.mapItems ?? []
        }
    }

    private func selectMapItem(_ item: MKMapItem) {
        hasUserSelection = true
        guard let coord = item.location?.coordinate else { return }
        withAnimation {
            selectedPin = coord
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
        resolvedAddress = formattedAddress(for: item) ?? item.name ?? "Selected location"
        searchResults = []
        searchText = ""
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        Task {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            guard let request = MKReverseGeocodingRequest(location: location) else { return }
            if let items = try? await request.mapItems, let mapItem = items.first {
                await MainActor.run {
                    resolvedAddress = formattedAddress(for: mapItem) ?? mapItem.name ?? "Selected location"
                }
            }
        }
    }

    private func formattedAddress(for item: MKMapItem) -> String? {
        let addr = item.address
        if let short = addr.shortAddress, !short.isEmpty {
            return short
        }
        let full = addr.fullAddress
        return full.isEmpty ? nil : full
    }
}

// MARK: - Location Manager

class LocationPickerManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLatitude: Double?
    @Published var currentLongitude: Double?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            currentLatitude = loc.coordinate.latitude
            currentLongitude = loc.coordinate.longitude
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently handle - user can search manually
    }
}


