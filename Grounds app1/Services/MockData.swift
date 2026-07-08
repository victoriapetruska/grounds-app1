import Foundation
import CoreLocation

// MARK: - All mock data for Grounds app
struct MockData {

    // ── Coffee Shops (nationwide — fallback until MKLocalSearch loads real data) ──
    static let shops: [CoffeeShop] = [

        // New York, NY
        CoffeeShop(id: "1", name: "Onyx Coffee Lab", address: "1 E 57th St, New York, NY",
                   latitude: 40.7627, longitude: -73.9716, rating: 4.8, reviewCount: 312,
                   priceLevel: 3, tags: ["wifi", "specialty", "pour-over"],
                   hours: weekdayHours("7AM–9PM", weekend: "8AM–8PM"),
                   photos: placeholderPhotos(4), isVerified: true, checkInCount: 1204),
        CoffeeShop(id: "2", name: "Devoción", address: "69 Grand St, Brooklyn, NY",
                   latitude: 40.7139, longitude: -73.9598, rating: 4.9, reviewCount: 156,
                   priceLevel: 3, tags: ["specialty", "direct-trade", "instagrammable"],
                   hours: weekdayHours("8AM–6PM", weekend: "9AM–5PM"),
                   photos: placeholderPhotos(6), isVerified: true, checkInCount: 934),

        // Los Angeles, CA
        CoffeeShop(id: "3", name: "Blue Bottle Coffee", address: "582 Mateo St, Los Angeles, CA",
                   latitude: 34.0368, longitude: -118.2306, rating: 4.6, reviewCount: 489,
                   priceLevel: 3, tags: ["specialty", "third-wave", "clean", "pour-over"],
                   hours: weekdayHours("7AM–6PM", weekend: "8AM–6PM"),
                   photos: placeholderPhotos(4), isVerified: true, checkInCount: 2781),
        CoffeeShop(id: "4", name: "Verve Coffee Roasters", address: "833 S Spring St, Los Angeles, CA",
                   latitude: 34.0451, longitude: -118.2528, rating: 4.7, reviewCount: 342,
                   priceLevel: 2, tags: ["wifi", "roaster", "espresso", "cozy"],
                   hours: weekdayHours("7AM–7PM", weekend: "8AM–7PM"),
                   photos: placeholderPhotos(3), isVerified: true, checkInCount: 1523),

        // Chicago, IL
        CoffeeShop(id: "5", name: "Intelligentsia Coffee", address: "53 W Jackson Blvd, Chicago, IL",
                   latitude: 41.8783, longitude: -87.6297, rating: 4.7, reviewCount: 614,
                   priceLevel: 2, tags: ["specialty", "espresso", "wifi", "third-wave"],
                   hours: weekdayHours("6AM–8PM", weekend: "7AM–8PM"),
                   photos: placeholderPhotos(5), isVerified: true, checkInCount: 3402),
        CoffeeShop(id: "6", name: "Dark Matter Coffee", address: "738 N Western Ave, Chicago, IL",
                   latitude: 41.8997, longitude: -87.6892, rating: 4.5, reviewCount: 278,
                   priceLevel: 2, tags: ["cozy", "roaster", "pour-over", "dog-friendly"],
                   hours: weekdayHours("7AM–7PM", weekend: "8AM–6PM"),
                   photos: placeholderPhotos(3), isVerified: true, checkInCount: 1187),

        // Seattle, WA
        CoffeeShop(id: "7", name: "Stumptown Coffee", address: "1115 12th Ave, Seattle, WA",
                   latitude: 47.6148, longitude: -122.3142, rating: 4.6, reviewCount: 397,
                   priceLevel: 2, tags: ["cold-brew", "wifi", "popular", "espresso"],
                   hours: weekdayHours("6AM–8PM", weekend: "7AM–8PM"),
                   photos: placeholderPhotos(3), isVerified: true, checkInCount: 2190),
        CoffeeShop(id: "8", name: "Victrola Coffee Roasters", address: "310 E Pike St, Seattle, WA",
                   latitude: 47.6135, longitude: -122.3261, rating: 4.8, reviewCount: 511,
                   priceLevel: 2, tags: ["roaster", "specialty", "cozy", "wifi"],
                   hours: weekdayHours("6:30AM–7PM", weekend: "7AM–7PM"),
                   photos: placeholderPhotos(4), isVerified: true, checkInCount: 1876),

        // Austin, TX
        CoffeeShop(id: "9", name: "Cuvée Coffee", address: "2000 E 6th St, Austin, TX",
                   latitude: 30.2628, longitude: -97.7249, rating: 4.8, reviewCount: 445,
                   priceLevel: 2, tags: ["specialty", "roaster", "wifi", "third-wave"],
                   hours: weekdayHours("7AM–6PM", weekend: "8AM–5PM"),
                   photos: placeholderPhotos(4), isVerified: true, checkInCount: 1654),
        CoffeeShop(id: "10", name: "Fleet Coffee", address: "2427 Webberville Rd, Austin, TX",
                   latitude: 30.2671, longitude: -97.7121, rating: 4.7, reviewCount: 312,
                   priceLevel: 2, tags: ["cozy", "pour-over", "dog-friendly", "outdoor"],
                   hours: weekdayHours("7AM–5PM", weekend: "8AM–5PM"),
                   photos: placeholderPhotos(3), isVerified: true, checkInCount: 987),

        // San Francisco, CA
        CoffeeShop(id: "11", name: "Sightglass Coffee", address: "270 7th St, San Francisco, CA",
                   latitude: 37.7757, longitude: -122.4092, rating: 4.7, reviewCount: 892,
                   priceLevel: 3, tags: ["specialty", "beautiful", "instagrammable", "espresso"],
                   hours: weekdayHours("7AM–6PM", weekend: "8AM–6PM"),
                   photos: placeholderPhotos(5), isVerified: true, checkInCount: 4231),
        CoffeeShop(id: "12", name: "Ritual Coffee Roasters", address: "1026 Valencia St, San Francisco, CA",
                   latitude: 37.7566, longitude: -122.4213, rating: 4.6, reviewCount: 734,
                   priceLevel: 2, tags: ["roaster", "wifi", "pour-over", "specialty"],
                   hours: weekdayHours("6AM–8PM", weekend: "7AM–8PM"),
                   photos: placeholderPhotos(4), isVerified: true, checkInCount: 3187),

        // Miami, FL
        CoffeeShop(id: "13", name: "Panther Coffee", address: "2390 NW 2nd Ave, Miami, FL",
                   latitude: 25.7998, longitude: -80.1993, rating: 4.8, reviewCount: 567,
                   priceLevel: 2, tags: ["specialty", "wifi", "outdoor", "espresso"],
                   hours: weekdayHours("7AM–9PM", weekend: "8AM–9PM"),
                   photos: placeholderPhotos(4), isVerified: true, checkInCount: 2341),
        CoffeeShop(id: "14", name: "Wynwood Café", address: "255 NW 27th Ter, Miami, FL",
                   latitude: 25.8023, longitude: -80.2014, rating: 4.5, reviewCount: 289,
                   priceLevel: 2, tags: ["cozy", "instagrammable", "outdoor", "wifi"],
                   hours: weekdayHours("7AM–8PM", weekend: "8AM–8PM"),
                   photos: placeholderPhotos(3), isVerified: true, checkInCount: 1102),

        // Nashville, TN
        CoffeeShop(id: "15", name: "Barista Parlor", address: "610 Magazine St, Nashville, TN",
                   latitude: 36.1551, longitude: -86.7836, rating: 4.9, reviewCount: 1021,
                   priceLevel: 2, tags: ["specialty", "beautiful", "roaster", "cozy"],
                   hours: weekdayHours("7AM–9PM", weekend: "8AM–9PM"),
                   photos: placeholderPhotos(5), isVerified: true, checkInCount: 5102),

        // Denver, CO
        CoffeeShop(id: "16", name: "Huckleberry Roasters", address: "4301 Pecos St, Denver, CO",
                   latitude: 39.7821, longitude: -105.0173, rating: 4.7, reviewCount: 423,
                   priceLevel: 2, tags: ["roaster", "specialty", "wifi", "pour-over"],
                   hours: weekdayHours("6:30AM–5PM", weekend: "7AM–5PM"),
                   photos: placeholderPhotos(4), isVerified: true, checkInCount: 1876),

        // Portland, OR
        CoffeeShop(id: "17", name: "Water Avenue Coffee", address: "1028 SE Water Ave, Portland, OR",
                   latitude: 45.5179, longitude: -122.6611, rating: 4.8, reviewCount: 387,
                   priceLevel: 2, tags: ["roaster", "specialty", "third-wave", "cozy"],
                   hours: weekdayHours("7AM–6PM", weekend: "8AM–6PM"),
                   photos: placeholderPhotos(3), isVerified: true, checkInCount: 1543),

        // Boston, MA
        CoffeeShop(id: "18", name: "George Howell Coffee", address: "505 Washington St, Boston, MA",
                   latitude: 42.3535, longitude: -71.0618, rating: 4.7, reviewCount: 512,
                   priceLevel: 3, tags: ["specialty", "third-wave", "pour-over", "wifi"],
                   hours: weekdayHours("7AM–7PM", weekend: "8AM–6PM"),
                   photos: placeholderPhotos(4), isVerified: true, checkInCount: 2098),
    ]

    // ── Reviews ───────────────────────────────────────────────────────────────
    static let reviews: [Review] = [
        Review(id: "r1", shopID: "1", userID: "u2", userName: "Emma W.",
               userAvatar: nil, rating: 5.0,
               title: "Best pour-over in the city",
               body: "Came here on a recommendation and was blown away. The Ethiopian single origin they had was absolutely incredible — floral, bright, and complex. The barista took time to explain the process. Worth every penny.",
               photoURLs: [], videoURL: nil,
               date: Date().addingTimeInterval(-86400 * 2),
               likes: 34, isVerifiedVisit: true),

        Review(id: "r2", shopID: "1", userID: "u3", userName: "Jake R.",
               userAvatar: nil, rating: 4.5,
               title: "Solid specialty shop",
               body: "Love this place for working. Great wifi, outlets everywhere, and the oat latte is consistently excellent. Gets busy around 10am but worth it.",
               photoURLs: [], videoURL: nil,
               date: Date().addingTimeInterval(-86400 * 5),
               likes: 21, isVerifiedVisit: true),

        Review(id: "r3", shopID: "2", userID: "u4", userName: "Sofia L.",
               userAvatar: nil, rating: 4.0,
               title: "Neighborhood gem",
               body: "Such a chill spot. Brought my dog and they had a water bowl outside. The cortado was spot on and prices are reasonable for the area.",
               photoURLs: [], videoURL: nil,
               date: Date().addingTimeInterval(-86400 * 1),
               likes: 15, isVerifiedVisit: true),

        Review(id: "r4", shopID: "3", userID: "u5", userName: "Marcus T.",
               userAvatar: nil, rating: 5.0,
               title: "Draft latte = life changing",
               body: "La Colombe's draft latte is unlike anything else. Cold, creamy, slightly sweet without adding anything. This is my daily stop. Staff is always friendly and fast.",
               photoURLs: [], videoURL: nil,
               date: Date().addingTimeInterval(-3600 * 6),
               likes: 47, isVerifiedVisit: true),
    ]

    // ── Check-ins ─────────────────────────────────────────────────────────────
    static let checkIns: [CheckIn] = [
        CheckIn(id: "c1", shopID: "1", shopName: "Onyx Coffee Lab", userID: "me",
                date: Date().addingTimeInterval(-3600 * 2),
                note: "Perfect morning start 🌅", photoURL: nil,
                drink: "Ethiopian Pour-Over", pointsEarned: 10),
        CheckIn(id: "c2", shopID: "3", shopName: "La Colombe", userID: "me",
                date: Date().addingTimeInterval(-86400 * 3),
                note: nil, photoURL: nil,
                drink: "Draft Latte", pointsEarned: 10),
        CheckIn(id: "c3", shopID: "2", shopName: "Birch Coffee", userID: "me",
                date: Date().addingTimeInterval(-86400 * 7),
                note: "WFH day ☕💻", photoURL: nil,
                drink: "Oat Latte", pointsEarned: 10),
        CheckIn(id: "c4", shopID: "4", shopName: "Blue Bottle Coffee", userID: "me",
                date: Date().addingTimeInterval(-86400 * 14),
                note: nil, photoURL: nil,
                drink: "New Orleans Iced", pointsEarned: 15),
        CheckIn(id: "c5", shopID: "5", shopName: "Stumptown Coffee", userID: "me",
                date: Date().addingTimeInterval(-86400 * 21),
                note: "First time here — love it!", photoURL: nil,
                drink: "Cold Brew", pointsEarned: 20),
    ]

    // ── Friends / Leaderboard ─────────────────────────────────────────────────
    static let friends: [User] = [
        User(id: "u2", name: "Emma Wilson", username: "emma.sips",
             bio: "Oat milk convert ☕", avatarURL: nil,
             visitedShopIDs: Array((1...18).map { "\($0)" }),
             checkInCount: 67, reviewCount: 22, friendIDs: ["me","u3"],
             badges: Badge.all.prefix(4).map { $0 }, isPremium: true,
             joinDate: Date().addingTimeInterval(-86400 * 200),
             favoriteShopIDs: ["1","6"], homeCity: "New York, NY",
             currentStreak: 9, longestStreak: 21,
             weeklyShopsVisited: 3, weeklyPhotos: 5,
             totalPhotos: 58, smallBizVisits: 41,
             lastCheckInDate: Date().addingTimeInterval(-3600)),

        User(id: "u3", name: "Jake Rivera", username: "jakedrinks",
             bio: "Espresso or nothing", avatarURL: nil,
             visitedShopIDs: Array((1...12).map { "\($0)" }),
             checkInCount: 41, reviewCount: 9, friendIDs: ["me","u2"],
             badges: Badge.all.prefix(2).map { $0 }, isPremium: false,
             joinDate: Date().addingTimeInterval(-86400 * 120),
             favoriteShopIDs: ["3","5"], homeCity: "New York, NY",
             currentStreak: 3, longestStreak: 8,
             weeklyShopsVisited: 2, weeklyPhotos: 2,
             totalPhotos: 17, smallBizVisits: 9,
             lastCheckInDate: Date().addingTimeInterval(-86400)),

        User(id: "u4", name: "Sofia Lee", username: "sofiasips",
             bio: "Finding hidden gems 🗺️", avatarURL: nil,
             visitedShopIDs: Array((1...31).map { "\($0)" }),
             checkInCount: 112, reviewCount: 45, friendIDs: ["me"],
             badges: Badge.all.prefix(6).map { $0 }, isPremium: true,
             joinDate: Date().addingTimeInterval(-86400 * 365),
             favoriteShopIDs: ["6","7"], homeCity: "Brooklyn, NY",
             currentStreak: 22, longestStreak: 34,
             weeklyShopsVisited: 6, weeklyPhotos: 8,
             totalPhotos: 134, smallBizVisits: 89,
             lastCheckInDate: Date()),

        User(id: "u5", name: "Marcus Thomas", username: "marcusbrews",
             bio: "Coffee + code = life", avatarURL: nil,
             visitedShopIDs: Array((1...8).map { "\($0)" }),
             checkInCount: 29, reviewCount: 11, friendIDs: ["me"],
             badges: Badge.all.prefix(2).map { $0 }, isPremium: false,
             joinDate: Date().addingTimeInterval(-86400 * 60),
             favoriteShopIDs: ["3"], homeCity: "Manhattan, NY",
             currentStreak: 0, longestStreak: 5,
             weeklyShopsVisited: 1, weeklyPhotos: 0,
             totalPhotos: 6, smallBizVisits: 7,
             lastCheckInDate: Date().addingTimeInterval(-86400 * 2)),
    ]

    // ── Leaderboard ───────────────────────────────────────────────────────────
    static func leaderboard(currentUser: User) -> [LeaderboardEntry] {
        var all = friends.map { LeaderboardEntry(id: $0.id, rank: 0, user: $0) }
        all.append(LeaderboardEntry(id: currentUser.id, rank: 0, user: currentUser, isCurrentUser: true))
        let sorted = all.sorted { $0.user.score > $1.user.score }
        return sorted.enumerated().map { i, entry in
            LeaderboardEntry(id: entry.id, rank: i + 1, user: entry.user, isCurrentUser: entry.isCurrentUser)
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    static func weekdayHours(_ weekday: String, weekend: String) -> [String: String] {
        ["Monday": weekday, "Tuesday": weekday, "Wednesday": weekday,
         "Thursday": weekday, "Friday": weekday,
         "Saturday": weekend, "Sunday": weekend]
    }

    static func placeholderPhotos(_ count: Int) -> [String] {
        (0..<count).map { _ in "https://source.unsplash.com/featured/400x300?coffee" }
    }

    static func reviews(for shopID: String) -> [Review] {
        reviews.filter { $0.shopID == shopID }
    }
}
