import Foundation

struct Review: Identifiable, Codable {
    let id: String
    let shopID: String
    let userID: String
    let userName: String
    let userAvatar: String?
    let rating: Double
    let title: String
    let body: String
    let photoURLs: [String]
    let videoURL: String?       // Pro only
    let date: Date
    var likes: Int
    var isVerifiedVisit: Bool   // user actually checked in
    var isLikedByMe: Bool = false

    var timeAgo: String {
        let diff = Calendar.current.dateComponents([.day, .hour, .minute], from: date, to: Date())
        if let days = diff.day, days > 0 { return days == 1 ? "1 day ago" : "\(days) days ago" }
        if let hours = diff.hour, hours > 0 { return "\(hours)h ago" }
        if let mins = diff.minute, mins > 0 { return "\(mins)m ago" }
        return "Just now"
    }
}

struct CheckIn: Identifiable, Codable {
    let id: String
    let shopID: String
    let shopName: String
    let userID: String
    let date: Date
    var note: String?
    var photoURL: String?
    var drink: String?          // "Oat Latte", "Espresso", etc.
    let pointsEarned: Int

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
