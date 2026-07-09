import Foundation
import CoreLocation
import MapKit

struct CoffeeShop: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let rating: Double
    let reviewCount: Int
    let priceLevel: Int          // 1–4 ($–$$$$)
    let tags: [String]
    let hours: [String: String]  // "Monday": "7AM–8PM"
    let photos: [String]         // Direct URLs (Google Photos or placeholder)
    let isVerified: Bool
    var checkInCount: Int
    var isFavorited: Bool = false

    // ── Enriched fields from Google Places / Apple Maps ──────────────────────
    var placeID: String?         // Google Place ID (used for detail fetches)
    var openNow: Bool?           // Live open/closed from API (overrides hours calc)
    var phoneNumber: String?     // Formatted phone number
    var website: String?         // Website URL

    // ── Computed ──────────────────────────────────────────────────────────────
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var priceString: String { String(repeating: "$", count: max(1, priceLevel)) }

    var todayHours: String {
        let days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        let today = days[Calendar.current.component(.weekday, from: Date()) - 1]
        return hours[today] ?? "Hours unavailable"
    }

    var isOpenNow: Bool {
        // Prefer live API value when available
        if let live = openNow { return live }
        return !todayHours.lowercased().contains("closed") &&
               todayHours != "Hours unavailable"
    }

    var mapItem: MKMapItem {
        let placemark = MKPlacemark(coordinate: coordinate)
        let item      = MKMapItem(placemark: placemark)
        item.name     = name
        if let phone  = phoneNumber { item.phoneNumber = phone }
        if let web    = website, let url = URL(string: web) { item.url = url }
        return item
    }
}

// MARK: - Badge Model
struct Badge: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: String
    let requirement: Int
    var isEarned: Bool = false

    static let all: [Badge] = [
        Badge(id: "first_sip",   name: "First Sip",       description: "Check in to your first coffee shop",  icon: "cup.and.saucer.fill",  color: "C4793A", requirement: 1),
        Badge(id: "regular",     name: "Regular",          description: "Check in 10 times",                  icon: "star.fill",             color: "D4A853", requirement: 10),
        Badge(id: "explorer",    name: "Explorer",         description: "Visit 25 different shops",            icon: "map.fill",              color: "4A7C59", requirement: 25),
        Badge(id: "connoisseur", name: "Connoisseur",      description: "Leave 20 reviews",                   icon: "pencil.and.outline",    color: "9B6A4A", requirement: 20),
        Badge(id: "pioneer",     name: "Pioneer",          description: "First check-in at a new shop",       icon: "flag.fill",             color: "C0392B", requirement: 1),
        Badge(id: "century",     name: "Century",          description: "100 total check-ins",                icon: "100.circle.fill",       color: "8B5E3C", requirement: 100),
        Badge(id: "social",      name: "Social Butterfly", description: "Add 10 friends",                     icon: "person.3.fill",         color: "5B8DB8", requirement: 10),
        Badge(id: "reviewer",    name: "Critic",           description: "Write 5 reviews with photos",        icon: "camera.fill",           color: "7B68EE", requirement: 5),
    ]
}
