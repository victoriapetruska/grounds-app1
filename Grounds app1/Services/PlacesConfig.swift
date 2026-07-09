import Foundation

/// Holds API keys for map data sources.
/// To configure:
///  1. In Xcode: File → New → File → Property List → name it "Secrets.plist"
///  2. Add key: GOOGLE_PLACES_API_KEY  (String)  → paste your key as the value
///  3. Get a key at: https://console.cloud.google.com → Enable "Places API"
nonisolated struct PlacesConfig {

    // MARK: - Google Places API Key
    static var googleAPIKey: String {
        // Read from Secrets.plist (never commit that file to git)
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let raw  = dict["GOOGLE_PLACES_API_KEY"] as? String {
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, key != "YOUR_API_KEY_HERE" {
                return key
            }
        }
        return ""
    }

    static var hasGoogleKey: Bool { !googleAPIKey.isEmpty }

    // MARK: - Search settings
    static let nearbyRadiusMeters: Int = 3_000   // ~1.9 mi per search
    static let maxPagesPerSearch:  Int = 3        // up to 60 results per location (20/page)
    static let gridCellDegrees:  Double = 0.08   // cache cell ~5 mi — avoids re-fetching same area
}
