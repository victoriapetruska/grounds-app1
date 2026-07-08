import Foundation
import CoreLocation

// MARK: - Yelp Fusion API Response Models

private nonisolated struct SearchResponse: Decodable {
    let businesses: [Business]
}

private nonisolated struct Business: Decodable {
    let id: String
    let name: String
    let imageUrl: String?
    let url: String?
    let isClosed: Bool
    let rating: Double?
    let reviewCount: Int?
    let price: String?
    let coordinates: Coordinates
    let location: BusinessLocation
    let categories: [Category]
    enum CodingKeys: String, CodingKey {
        case id, name, url, rating, price, coordinates, location, categories
        case imageUrl    = "image_url"
        case isClosed    = "is_closed"
        case reviewCount = "review_count"
    }
}

private nonisolated struct Coordinates: Decodable {
    let latitude: Double
    let longitude: Double
}

private nonisolated struct BusinessLocation: Decodable {
    let displayAddress: [String]?
    enum CodingKeys: String, CodingKey { case displayAddress = "display_address" }
}

private nonisolated struct Category: Decodable {
    let alias: String
    let title: String
}

// MARK: - Business Details Response

private nonisolated struct DetailsResponse: Decodable {
    let photos: [String]?
    let hours: [Hours]?
    let displayPhone: String?
    enum CodingKeys: String, CodingKey {
        case photos, hours
        case displayPhone = "display_phone"
    }
}

private nonisolated struct Hours: Decodable {
    let isOpenNow: Bool?
    let open: [OpenInterval]?
    enum CodingKeys: String, CodingKey {
        case isOpenNow = "is_open_now"
        case open
    }
}

private nonisolated struct OpenInterval: Decodable {
    let day: Int      // 0 = Monday ... 6 = Sunday
    let start: String // "0800"
    let end: String   // "2000"
}

nonisolated struct YelpDetails {
    let photos: [String]
    let hours: [String: String]
    let phone: String?
    let isOpenNow: Bool?
}

// MARK: - Service

actor YelpService {
    static let shared = YelpService()

    private let base = "https://api.yelp.com/v3/businesses"
    private var apiKey: String { PlacesConfig.yelpAPIKey }

    // Keyed by grid cell → avoids duplicate network requests for same area
    private var cache: [String: [CoffeeShop]] = [:]

    // MARK: - Nearby Search
    func fetchNearby(
        coordinate: CLLocationCoordinate2D,
        radius: Int = PlacesConfig.nearbyRadiusMeters,
        forceRefresh: Bool = false
    ) async throws -> [CoffeeShop] {

        let key = cacheKey(coordinate)
        if !forceRefresh, let cached = cache[key] { return cached }

        var components = URLComponents(string: "\(base)/search")!
        components.queryItems = [
            URLQueryItem(name: "latitude",   value: "\(coordinate.latitude)"),
            URLQueryItem(name: "longitude",  value: "\(coordinate.longitude)"),
            URLQueryItem(name: "radius",     value: "\(min(radius, 40_000))"),
            URLQueryItem(name: "categories", value: "coffee,coffeeroasteries"),
            URLQueryItem(name: "limit",      value: "50"),
            URLQueryItem(name: "sort_by",    value: "best_match"),
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw PlacesError.apiError("Yelp API error (status \(http.statusCode)): \(body)")
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        let shops = decoded.businesses.map { makeCoffeeShop($0) }
        cache[key] = shops
        return shops
    }

    // MARK: - Business Details (full photos, hours, phone)
    func fetchDetails(businessID: String) async throws -> YelpDetails? {
        guard let url = URL(string: "\(base)/\(businessID)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw PlacesError.apiError("Yelp API error (status \(http.statusCode))")
        }

        let decoded = try JSONDecoder().decode(DetailsResponse.self, from: data)

        var hoursDict: [String: String] = [:]
        let dayNames = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
        if let intervals = decoded.hours?.first?.open {
            for interval in intervals {
                let day = dayNames[interval.day]
                let formatted = "\(formatTime(interval.start)) – \(formatTime(interval.end))"
                hoursDict[day] = formatted
            }
        }

        return YelpDetails(
            photos:    decoded.photos ?? [],
            hours:     hoursDict,
            phone:     decoded.displayPhone,
            isOpenNow: decoded.hours?.first?.isOpenNow
        )
    }

    // MARK: - Cache
    func clearCache() { cache.removeAll() }

    private func cacheKey(_ coord: CLLocationCoordinate2D) -> String {
        let g = PlacesConfig.gridCellDegrees
        return "\(Int(coord.latitude / g))_\(Int(coord.longitude / g))"
    }

    // MARK: - Mapping
    private func makeCoffeeShop(_ b: Business) -> CoffeeShop {
        CoffeeShop(
            id:           b.id,
            name:         b.name,
            address:      b.location.displayAddress?.joined(separator: ", ") ?? "",
            latitude:     b.coordinates.latitude,
            longitude:    b.coordinates.longitude,
            rating:       b.rating ?? 4.2,
            reviewCount:  b.reviewCount ?? 0,
            priceLevel:   b.price?.count ?? 2,
            tags:         tagsFrom(b.categories),
            hours:        [:],                 // filled lazily via fetchDetails
            photos:       b.imageUrl.map { [$0] } ?? [],
            isVerified:   true,
            checkInCount: Int.random(in: 50...5000),
            placeID:      b.id,
            openNow:      b.isClosed ? false : nil,  // only know "permanently closed"; live hours need details
            website:      b.url
        )
    }

    private func tagsFrom(_ categories: [Category]) -> [String] {
        let categoryMap: [String: String] = [
            "coffee":           "espresso",
            "coffeeroasteries": "specialty",
            "bakeries":         "food",
            "bagels":           "food",
            "tea":              "specialty",
        ]
        var tags = categories.compactMap { categoryMap[$0.alias] }
        let extras = ["wifi","cozy","specialty","pour-over","cold-brew","outdoor","dog-friendly"]
        tags += extras.shuffled().prefix(2)
        return Array(Set(tags)).prefix(5).map { $0 }
    }

    private func formatTime(_ raw: String) -> String {
        guard raw.count == 4,
              let hour = Int(raw.prefix(2)),
              let minute = Int(raw.suffix(2)) else { return raw }
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return minute == 0 ? "\(displayHour) \(period)" : String(format: "%d:%02d %@", displayHour, minute, period)
    }
}

// MARK: - Error
enum PlacesError: LocalizedError {
    case apiError(String)
    var errorDescription: String? {
        switch self {
        case .apiError(let s): return "Places error: \(s)"
        }
    }
}
