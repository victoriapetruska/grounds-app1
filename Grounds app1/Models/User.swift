import Foundation

struct User: Identifiable, Codable {
    let id: String
    var name: String
    var username: String
    var bio: String
    var avatarURL: String?
    var visitedShopIDs: [String]
    var checkInCount: Int
    var reviewCount: Int
    var friendIDs: [String]
    var badges: [Badge]
    var isPremium: Bool
    var joinDate: Date
    var favoriteShopIDs: [String]
    var homeCity: String

    // ── Streak & competition stats ─────────────────────────────────────────────
    var currentStreak: Int      = 0   // consecutive days with ≥1 check-in
    var longestStreak: Int      = 0   // all-time best streak
    var weeklyShopsVisited: Int = 0   // unique shops this calendar week
    var weeklyPhotos: Int       = 0   // photos posted this week
    var totalPhotos: Int        = 0   // all-time photos posted at shops
    var smallBizVisits: Int     = 0   // check-ins at independent (non-chain) shops
    var lastCheckInDate: Date?  = nil // for streak calculation

    // ── Computed ──────────────────────────────────────────────────────────────
    var visitedCount: Int { visitedShopIDs.count }

    /// Overall score: check-ins + (reviews × 3) + (unique shops × 2) + (photos × 2)
    var score: Int { checkInCount + (reviewCount * 3) + (visitedShopIDs.count * 2) + (totalPhotos * 2) }

    /// Streak is "active" if they checked in today or yesterday
    var isStreakActive: Bool {
        guard let last = lastCheckInDate else { return false }
        return Calendar.current.isDateInToday(last) || Calendar.current.isDateInYesterday(last)
    }

    var streakFlameLevel: Int {
        switch currentStreak {
        case 0:    return 0
        case 1...3: return 1
        case 4...6: return 2
        case 7...13: return 3
        default:   return 4
        }
    }

    static let placeholder = User(
        id: "me",
        name: "Victoria",
        username: "victoria.coffee",
        bio: "Chasing the perfect espresso ☕",
        avatarURL: nil,
        visitedShopIDs: ["1","2","3","4","5"],
        checkInCount: 23,
        reviewCount: 8,
        friendIDs: ["u2","u3","u4"],
        badges: [Badge.all[0], Badge.all[1]],
        isPremium: false,
        joinDate: Calendar.current.date(byAdding: .month, value: -3, to: Date())!,
        favoriteShopIDs: ["1","3"],
        homeCity: "New York, NY",
        currentStreak: 5,
        longestStreak: 12,
        weeklyShopsVisited: 4,
        weeklyPhotos: 3,
        totalPhotos: 19,
        smallBizVisits: 18,
        lastCheckInDate: Date()
    )
}

struct LeaderboardEntry: Identifiable {
    let id: String
    let rank: Int
    let user: User
    var isCurrentUser: Bool = false
}
