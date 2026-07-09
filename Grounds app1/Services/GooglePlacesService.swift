import Foundation
import CoreLocation

// MARK: - Google Places API Response Models

private nonisolated struct NearbyResponse: Decodable {
    let results: [PlaceResult]
    let status: String
    let nextPageToken: String?
    enum CodingKeys: String, CodingKey {
        case results, status
        case nextPageToken = "next_page_token"
    }
}

private nonisolated struct PlaceResult: Decodable {
    let placeId: String
    let name: String
    let vicinity: String?
    let geometry: Geometry
    let rating: Double?
    let userRatingsTotal: Int?
    let priceLevel: Int?
    let openingHours: OpenStatus?
    let photos: [PhotoRef]?
    let types: [String]?
    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name, vicinity, geometry, rating
        case userRatingsTotal = "user_ratings_total"
        case priceLevel       = "price_level"
        case openingHours     = "opening_hours"
        case photos, types
    }
}

private nonisolated struct Geometry: Decodable {
    let location: LatLng
}
private nonisolated struct LatLng: Decodable {
    let lat: Double
    let lng: Double
}
private nonisolated struct OpenStatus: Decodable {
    let openNow: Bool?
    enum CodingKeys: String, CodingKey { case openNow = "open_now" }
}
private nonisolated struct PhotoRef: Decodable {
    let photoReference: String
    enum CodingKeys: String, CodingKey { case photoReference = "photo_reference" }
}

// MARK: - Place Details Response

private nonisolated struct DetailsResponse: Decodable {
    let result: DetailsResult?
    let status: String
}

private nonisolated struct DetailsResult: Decodable {
    let formattedPhoneNumber: String?
    let openingHours: WeekdayHours?
    let reviews: [GoogleReviewPayload]?
    enum CodingKeys: String, CodingKey {
        case formattedPhoneNumber = "formatted_phone_number"
        case openingHours         = "opening_hours"
        case reviews
    }
}

private nonisolated struct WeekdayHours: Decodable {
    let weekdayText: [String]?          // ["Monday: 7:00 AM – 9:00 PM", …]
    enum CodingKeys: String, CodingKey { case weekdayText = "weekday_text" }
}

private nonisolated struct GoogleReviewPayload: Decodable {
    let authorName: String
    let profilePhotoUrl: String?
    let rating: Int
    let text: String
    let time: TimeInterval
    enum CodingKeys: String, CodingKey {
        case authorName      = "author_name"
        case profilePhotoUrl = "profile_photo_url"
        case rating, text, time
    }
}

nonisolated struct GoogleDetails {
    let hours: [String: String]
    let phone: String?
    let reviews: [Review]
}

// MARK: - Service

actor GooglePlacesService {
    static let shared = GooglePlacesService()

    private let base = "https://maps.googleapis.com/maps/api/place"
    private var apiKey: String { PlacesConfig.googleAPIKey }

    // Keyed by grid cell → avoids duplicate network requests for same area
    private var cache: [String: [CoffeeShop]] = [:]

    // MARK: - Nearby Search (up to 60 results per location via pagination)
    func fetchNearby(
        coordinate: CLLocationCoordinate2D,
        radius: Int = PlacesConfig.nearbyRadiusMeters,
        forceRefresh: Bool = false
    ) async throws -> [CoffeeShop] {

        let key = cacheKey(coordinate)
        if !forceRefresh, let cached = cache[key] { return cached }

        var allShops: [CoffeeShop] = []
        var nextToken: String? = nil
        var page = 0

        repeat {
            let urlString: String
            if let token = nextToken {
                // Google requires ~2 s before pagetoken is valid
                try await Task.sleep(nanoseconds: 2_200_000_000)
                urlString = "\(base)/nearbysearch/json?pagetoken=\(token)&key=\(apiKey)"
            } else {
                urlString = "\(base)/nearbysearch/json"
                    + "?location=\(coordinate.latitude),\(coordinate.longitude)"
                    + "&radius=\(radius)"
                    + "&type=cafe"
                    + "&key=\(apiKey)"
            }

            guard let url = URL(string: urlString) else { break }
            let (data, _) = try await URLSession.shared.data(from: url)
            let response  = try JSONDecoder().decode(NearbyResponse.self, from: data)

            guard response.status == "OK" || response.status == "ZERO_RESULTS" else {
                throw PlacesError.apiError(response.status)
            }

            allShops.append(contentsOf: response.results.map { makeCoffeeShop($0) })
            nextToken = response.nextPageToken
            page += 1

        } while nextToken != nil && page < PlacesConfig.maxPagesPerSearch

        cache[key] = allShops
        return allShops
    }

    // MARK: - Place Details (hours, phone, reviews)
    func fetchDetails(placeID: String) async throws -> GoogleDetails? {
        let fields = "formatted_phone_number,opening_hours,reviews"
        let urlStr = "\(base)/details/json?place_id=\(placeID)&fields=\(fields)&key=\(apiKey)"
        guard let url = URL(string: urlStr) else { return nil }
        let (data, _)  = try await URLSession.shared.data(from: url)
        let response   = try JSONDecoder().decode(DetailsResponse.self, from: data)
        guard let result = response.result else { return nil }

        var hoursDict: [String: String] = [:]
        let dayNames = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
        if let weekdayText = result.openingHours?.weekdayText {
            for line in weekdayText {
                for day in dayNames {
                    if line.hasPrefix(day) {
                        hoursDict[day] = line.replacingOccurrences(of: "\(day): ", with: "")
                    }
                }
            }
        }

        let reviews = (result.reviews ?? []).map { r in
            Review(
                id:              UUID().uuidString,
                shopID:          placeID,
                userID:          r.authorName,
                userName:        r.authorName,
                userAvatar:      r.profilePhotoUrl,
                rating:          Double(r.rating),
                title:           "",
                body:            r.text,
                photoURLs:       [],
                videoURL:        nil,
                date:            Date(timeIntervalSince1970: r.time),
                likes:           0,
                isVerifiedVisit: false
            )
        }

        return GoogleDetails(hours: hoursDict, phone: result.formattedPhoneNumber, reviews: reviews)
    }

    // MARK: - Photo URL
    static func photoURL(reference: String, maxWidth: Int = 600) -> String {
        "https://maps.googleapis.com/maps/api/place/photo"
            + "?maxwidth=\(maxWidth)"
            + "&photoreference=\(reference)"
            + "&key=\(PlacesConfig.googleAPIKey)"
    }

    // MARK: - Cache
    func clearCache() { cache.removeAll() }

    private func cacheKey(_ coord: CLLocationCoordinate2D) -> String {
        let g = PlacesConfig.gridCellDegrees
        return "\(Int(coord.latitude / g))_\(Int(coord.longitude / g))"
    }

    // MARK: - Mapping
    private func makeCoffeeShop(_ p: PlaceResult) -> CoffeeShop {
        let photoURLs = (p.photos ?? []).prefix(6).map {
            GooglePlacesService.photoURL(reference: $0.photoReference)
        }

        return CoffeeShop(
            id:           p.placeId,
            name:         p.name,
            address:      p.vicinity ?? "",
            latitude:     p.geometry.location.lat,
            longitude:    p.geometry.location.lng,
            rating:       p.rating ?? 4.2,
            reviewCount:  p.userRatingsTotal ?? 0,
            priceLevel:   p.priceLevel ?? 2,
            tags:         tagsFrom(p.types ?? []),
            hours:        [:],            // filled lazily via fetchDetails
            photos:       Array(photoURLs),
            isVerified:   true,
            checkInCount: 0,   // real count comes from CommunityService, not invented
            placeID:      p.placeId,
            openNow:      p.openingHours?.openNow
        )
    }

    private func tagsFrom(_ types: [String]) -> [String] {
        let typeMap: [String: String] = [
            "cafe":       "espresso",
            "bakery":     "food",
            "bar":        "evening",
            "meal_takeaway": "fast",
            "store":      "retail",
        ]
        var tags = types.compactMap { typeMap[$0] }
        let extras = ["wifi","cozy","specialty","pour-over","cold-brew","outdoor","dog-friendly"]
        tags += extras.shuffled().prefix(2)
        return Array(Set(tags)).prefix(5).map { $0 }
    }
}

// MARK: - Error
enum PlacesError: LocalizedError {
    case apiError(String)
    var errorDescription: String? {
        switch self {
        case .apiError(let s): return "Google Places error: \(s)"
        }
    }
}
