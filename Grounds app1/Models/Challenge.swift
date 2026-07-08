import Foundation

// MARK: - Challenge Type

enum ChallengeType: String, Codable, CaseIterable, Identifiable {
    case shops    = "Most Shops"
    case photos   = "Most Photos"
    case smallBiz = "Small Biz Visits"
    case streak   = "Longest Streak"
    case checkIns = "Most Check-ins"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .shops:    return "map.fill"
        case .photos:   return "camera.fill"
        case .smallBiz: return "storefront.fill"
        case .streak:   return "flame.fill"
        case .checkIns: return "mappin.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .shops:    return "Visit the most unique coffee shops"
        case .photos:   return "Post the most check-in photos"
        case .smallBiz: return "Visit the most independent shops"
        case .streak:   return "Maintain the longest daily streak"
        case .checkIns: return "Log the most total check-ins"
        }
    }
}

// MARK: - Challenge Duration

enum ChallengeDuration: Int, Codable, CaseIterable {
    case threeDays  = 3
    case oneWeek    = 7
    case twoWeeks   = 14
    case oneMonth   = 30

    var label: String {
        switch self {
        case .threeDays: return "3 Days"
        case .oneWeek:   return "1 Week"
        case .twoWeeks:  return "2 Weeks"
        case .oneMonth:  return "1 Month"
        }
    }
}

// MARK: - Challenge Status

enum ChallengeStatus: String, Codable {
    case pending   // waiting for opponent to accept
    case active    // in progress
    case completed // finished — winner determined
    case declined  // opponent said no
}

// MARK: - Challenge Model

struct Challenge: Identifiable, Codable {
    let id: String
    let type: ChallengeType
    let duration: ChallengeDuration
    let startDate: Date
    let endDate: Date
    var status: ChallengeStatus

    // Participants
    let challengerID: String
    let challengerName: String
    let challengerAvatar: String?

    let opponentID: String
    let opponentName: String
    let opponentAvatar: String?

    // Live scores
    var challengerScore: Int
    var opponentScore: Int

    // MARK: - Computed

    var timeRemaining: String {
        let diff = endDate.timeIntervalSinceNow
        guard diff > 0 else { return "Ended" }
        let days  = Int(diff / 86400)
        let hours = Int((diff.truncatingRemainder(dividingBy: 86400)) / 3600)
        if days > 0 { return "\(days)d \(hours)h left" }
        if hours > 0 { return "\(hours)h left" }
        let mins = Int(diff / 60)
        return "\(mins)m left"
    }

    var challengerLeading: Bool { challengerScore >= opponentScore }

    /// 0.0 – 1.0 representing challenger's share of total
    var challengerProgress: Double {
        let total = challengerScore + opponentScore
        guard total > 0 else { return 0.5 }
        return Double(challengerScore) / Double(total)
    }

    var winnerName: String? {
        guard status == .completed else { return nil }
        if challengerScore > opponentScore { return challengerName }
        if opponentScore > challengerScore { return opponentName }
        return "Tie"
    }
}

// MARK: - Mock challenges

extension Challenge {
    static let mockChallenges: [Challenge] = [
        Challenge(
            id: "ch1",
            type: .shops,
            duration: .oneWeek,
            startDate: Date().addingTimeInterval(-86400 * 3),
            endDate:   Date().addingTimeInterval( 86400 * 4),
            status: .active,
            challengerID: "me",    challengerName: "Victoria", challengerAvatar: nil,
            opponentID:   "u2",    opponentName:   "Emma W.",  opponentAvatar: nil,
            challengerScore: 4, opponentScore: 3
        ),
        Challenge(
            id: "ch2",
            type: .photos,
            duration: .threeDays,
            startDate: Date().addingTimeInterval(-86400 * 1),
            endDate:   Date().addingTimeInterval( 86400 * 2),
            status: .active,
            challengerID: "u3",   challengerName: "Jake R.",   challengerAvatar: nil,
            opponentID:   "me",   opponentName:   "Victoria",  opponentAvatar: nil,
            challengerScore: 5, opponentScore: 3
        ),
        Challenge(
            id: "ch3",
            type: .smallBiz,
            duration: .oneWeek,
            startDate: Date().addingTimeInterval(-86400 * 2),
            endDate:   Date().addingTimeInterval( 86400 * 5),
            status: .pending,
            challengerID: "u4",   challengerName: "Sofia L.",  challengerAvatar: nil,
            opponentID:   "me",   opponentName:   "Victoria",  opponentAvatar: nil,
            challengerScore: 0, opponentScore: 0
        ),
        Challenge(
            id: "ch4",
            type: .streak,
            duration: .twoWeeks,
            startDate: Date().addingTimeInterval(-86400 * 14),
            endDate:   Date().addingTimeInterval(-86400 * 1),
            status: .completed,
            challengerID: "me",   challengerName: "Victoria",  challengerAvatar: nil,
            opponentID:   "u5",   opponentName:   "Marcus T.", opponentAvatar: nil,
            challengerScore: 12, opponentScore: 9
        ),
    ]
}
