import Foundation
import MapKit
import CoreLocation
import Combine
import SwiftUI

@MainActor
class MapViewModel: ObservableObject {

    // ── Published state ───────────────────────────────────────────────────────
    @Published var shops: [CoffeeShop]      = MockData.shops
    @Published var selectedShop: CoffeeShop?
    @Published var searchText: String        = ""
    @Published var isSearching: Bool         = false
    @Published var hasCenteredOnUser: Bool   = false
    @Published var dataSource: DataSource    = .loading

    // Default: continental US center — snaps to GPS on first location fix
    @Published var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
        span:   MKCoordinateSpan(latitudeDelta: 60.0, longitudeDelta: 60.0)
    )
    @Published var filterTag: String?        = nil
    @Published var showOnlyOpen: Bool        = false
    @Published var currentShopReviews: [Review] = []

    enum DataSource { case loading, google, apple, mock }

    let allTags = ["wifi","dog-friendly","outdoor","specialty",
                   "pour-over","cold-brew","espresso","cozy"]

    // ── Region dedup: track which grid cells have already been fetched ────────
    private var fetchedCells: Set<String>    = []

    // ── Filtered shops for map + list ─────────────────────────────────────────
    var filteredShops: [CoffeeShop] {
        var result = shops
        if showOnlyOpen { result = result.filter { $0.isOpenNow } }
        if let tag = filterTag { result = result.filter { $0.tags.contains(tag) } }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.address.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    // ── Location handling ─────────────────────────────────────────────────────
    func centerOnUser(_ location: CLLocation) {
        let coord = location.coordinate
        withAnimation(.easeInOut(duration: 0.8)) {
            mapRegion = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        }
        Task { await fetchNearby(coordinate: coord) }
    }

    // ── Primary entry point — called on pan, location fix, and search ─────────
    func fetchNearby(coordinate: CLLocationCoordinate2D? = nil,
                     region: MKCoordinateRegion? = nil,
                     forceRefresh: Bool = false) async {

        let center = coordinate ?? region?.center ?? mapRegion.center
        let cellKey = gridKey(center)

        // Skip if this cell was already loaded (unless forced)
        if !forceRefresh && fetchedCells.contains(cellKey) { return }

        isSearching = true
        defer { isSearching = false }

        // ── 1. Try Google Places (real ratings, photos, hours, live open status)
        if PlacesConfig.hasGoogleKey {
            do {
                let fetched = try await GooglePlacesService.shared.fetchNearby(
                    coordinate: center,
                    forceRefresh: forceRefresh
                )
                if !fetched.isEmpty {
                    mergeShops(fetched)
                    fetchedCells.insert(cellKey)
                    dataSource = .google
                    return
                }
            } catch {
                print("[Grounds] Google Places error: \(error.localizedDescription)")
                // Fall through to Apple Maps
            }
        }

        // ── 2. Fallback: Apple Maps MKLocalSearch (works everywhere, no key needed)
        await fetchFromAppleMaps(center: center, cellKey: cellKey)
    }

    // ── Called when user taps "Search this area" after panning ───────────────
    func fetchForVisibleRegion() {
        Task { await fetchNearby(region: mapRegion, forceRefresh: true) }
    }

    // ── Lazy-load rich details for a shop (phone, hours, reviews) ─────────────
    func enrichShop(_ shop: CoffeeShop) async {
        guard let placeID = shop.placeID, PlacesConfig.hasGoogleKey else { return }
        guard let idx = shops.firstIndex(where: { $0.id == shop.id }) else { return }

        do {
            guard let details = try await GooglePlacesService.shared.fetchDetails(placeID: placeID)
            else { return }

            let existing = shops[idx]
            let updated = CoffeeShop(
                id: existing.id, name: existing.name, address: existing.address,
                latitude: existing.latitude, longitude: existing.longitude,
                rating: existing.rating, reviewCount: existing.reviewCount,
                priceLevel: existing.priceLevel, tags: existing.tags,
                hours: details.hours.isEmpty ? existing.hours : details.hours,
                photos: existing.photos, isVerified: existing.isVerified,
                checkInCount: existing.checkInCount, isFavorited: existing.isFavorited,
                placeID: existing.placeID, openNow: existing.openNow,
                phoneNumber: details.phone,
                website: existing.website
            )

            shops[idx] = updated
            // Also update selectedShop if it's this one
            if selectedShop?.id == shop.id {
                selectedShop = updated
                currentShopReviews = details.reviews
            }
        } catch {
            print("[Grounds] Detail fetch error: \(error.localizedDescription)")
        }
    }

    // ── UI helpers ─────────────────────────────────────────────────────────────
    func selectShop(_ shop: CoffeeShop) {
        selectedShop = shop
        currentShopReviews = []
        Task { await enrichShop(shop) }
    }

    func clearSelection() { selectedShop = nil }

    func toggleFavorite(_ shopID: String) {
        if let idx = shops.firstIndex(where: { $0.id == shopID }) {
            shops[idx].isFavorited.toggle()
            if selectedShop?.id == shopID { selectedShop = shops[idx] }
        }
    }

    func checkIn(to shop: CoffeeShop) {
        if let idx = shops.firstIndex(where: { $0.id == shop.id }) {
            shops[idx].checkInCount += 1
        }
    }

    // ── Private helpers ────────────────────────────────────────────────────────

    private func fetchFromAppleMaps(center: CLLocationCoordinate2D, cellKey: String) async {
        let searchRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "coffee shop"
        request.region = searchRegion
        request.resultTypes = .pointOfInterest

        do {
            let response = try await MKLocalSearch(request: request).start()
            let fetched: [CoffeeShop] = response.mapItems.compactMap { item in
                guard let name = item.name else { return nil }
                let address = [
                    item.placemark.subThoroughfare,
                    item.placemark.thoroughfare,
                    item.placemark.locality,
                    item.placemark.administrativeArea
                ].compactMap { $0 }.joined(separator: " ")

                return CoffeeShop(
                    id:           "\(item.placemark.coordinate.latitude)_\(item.placemark.coordinate.longitude)",
                    name:         name,
                    address:      address,
                    latitude:     item.placemark.coordinate.latitude,
                    longitude:    item.placemark.coordinate.longitude,
                    rating:       Double.random(in: 3.8...5.0).rounded(to: 1),
                    reviewCount:  Int.random(in: 20...600),
                    priceLevel:   Int.random(in: 1...3),
                    tags:         randomTags(),
                    hours:        MockData.weekdayHours("7AM–8PM", weekend: "8AM–7PM"),
                    photos:       [],
                    isVerified:   Bool.random(),
                    checkInCount: 0,   // real count comes from CommunityService, not invented
                    phoneNumber:  item.phoneNumber,
                    website:      item.url?.absoluteString
                )
            }
            if !fetched.isEmpty {
                mergeShops(fetched)
                fetchedCells.insert(cellKey)
                dataSource = .apple
            }
        } catch {
            // Keep existing shops on failure — mock data already loaded
            dataSource = .mock
        }
    }

    /// Major chains to exclude — Grounds only surfaces independent, small-business coffee shops.
    private static let chainDenylist: [String] = [
        "starbucks", "dunkin", "peet's coffee", "peets coffee", "tim hortons",
        "costa coffee", "dutch bros", "caribou coffee", "coffee bean & tea leaf",
        "tully's coffee", "krispy kreme", "mccafe", "mcdonald's", "mcdonalds",
        "7-eleven", "7 eleven", "circle k", "wawa", "quiktrip", "speedway",
        "sheetz", "casey's general store", "caseys general store",
        "cumberland farms", "racetrac", "kwik trip", "ampm", "am/pm",
    ]

    private func isChain(_ name: String) -> Bool {
        let normalized = name.lowercased()
        return Self.chainDenylist.contains { normalized.contains($0) }
    }

    /// Merge new shops into the list — deduplicate by id, prefer newer entries, drop chains.
    /// Also drops any leftover mock/seed shops the moment real results arrive, so a real
    /// fetch always fully replaces the placeholder data instead of mixing with it forever.
    private func mergeShops(_ newShops: [CoffeeShop]) {
        let independentShops = newShops.filter { !isChain($0.name) }
        let realShops = shops.filter { !$0.isMock }
        var dict: [String: CoffeeShop] = Dictionary(uniqueKeysWithValues: realShops.map { ($0.id, $0) })
        for shop in independentShops {
            // Preserve user state (favorites, checkIns) if shop already exists
            if let existing = dict[shop.id] {
                var updated = shop
                updated.isFavorited  = existing.isFavorited
                updated.checkInCount = max(existing.checkInCount, shop.checkInCount)
                dict[shop.id] = updated
            } else {
                dict[shop.id] = shop
            }
        }
        shops = Array(dict.values).sorted { $0.rating > $1.rating }
    }

    private func gridKey(_ coord: CLLocationCoordinate2D) -> String {
        let g = PlacesConfig.gridCellDegrees
        return "\(Int(coord.latitude / g))_\(Int(coord.longitude / g))"
    }

    private func randomTags() -> [String] {
        allTags.shuffled().prefix(Int.random(in: 2...4)).map { $0 }
    }
}

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
