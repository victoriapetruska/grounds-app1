import Foundation
import CloudKit
import UIKit
import Combine

struct CommunityCheckIn: Identifiable {
    let id: String
    let shopID: String
    let shopName: String
    let userName: String
    let timestamp: Date
    let photoURL: URL?
    let caption: String?
}

/// Real per-user stats aggregated from CloudKit check-in records — no invented numbers.
struct CommunityLeaderboardEntry: Identifiable {
    let id: String          // Apple user identifier (stable, unlike userName)
    let userName: String
    let totalCheckIns: Int
    let totalShopsVisited: Int
    let weeklyCheckIns: Int
    let weeklyShopsVisited: Int
    let weeklyPhotos: Int
    let totalPhotos: Int
    let currentStreak: Int
    let longestStreak: Int
}

/// Stores check-ins (with optional photos) in CloudKit's public database so every
/// user's visits are visible to the community — this is the app's only real backend.
@MainActor
class CommunityService: ObservableObject {
    @Published private(set) var recentCheckIns: [CommunityCheckIn] = []
    @Published private(set) var leaderboard: [CommunityLeaderboardEntry] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let container = CKContainer(identifier: "iCloud.coffeeground.Grounds-app1")
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    private static let recordType = "CheckIn"

    func isICloudAvailable() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    /// Posts a check-in to the community feed. Best-effort: failures are surfaced via
    /// `errorMessage` but never block the local check-in that already happened.
    func postCheckIn(shopID: String, shopName: String, userID: String, userName: String, photo: UIImage?, caption: String?) async {
        guard await isICloudAvailable() else {
            errorMessage = "Sign in to iCloud in Settings to share check-ins with the community."
            return
        }

        let record = CKRecord(recordType: Self.recordType)
        record["shopID"]    = shopID
        record["shopName"]  = shopName
        record["userID"]    = userID
        record["userName"]  = userName
        record["timestamp"] = Date()
        record["hasPhoto"]  = photo != nil ? 1 : 0
        if let caption, !caption.isEmpty { record["caption"] = caption }

        var tempFileURL: URL?
        if let photo, let data = photo.jpegData(compressionQuality: 0.7) {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            do {
                try data.write(to: url)
                record["photo"] = CKAsset(fileURL: url)
                tempFileURL = url
            } catch {
                // Post without the photo rather than failing the whole check-in.
            }
        }

        do {
            _ = try await publicDB.save(record)
            errorMessage = nil
            // Refresh published state immediately so every screen observing it (Profile,
            // leaderboard, activity feed) reflects this check-in right away, rather than
            // waiting for a view's own "only fetch if empty" first-appearance guard.
            async let leaderboardRefresh: () = fetchLeaderboard()
            async let recentRefresh: () = fetchRecentCheckIns()
            _ = await (leaderboardRefresh, recentRefresh)
        } catch {
            errorMessage = "Couldn't share your check-in: \(error.localizedDescription)"
        }

        if let tempFileURL {
            try? FileManager.default.removeItem(at: tempFileURL)
        }
    }

    /// Real score for one participant of a Battle challenge, computed live from their check-ins
    /// within the challenge window — never a stored/stale number.
    func metricScore(forUserID userID: String, type: ChallengeType, from: Date, to: Date) async -> Int {
        let predicate = NSPredicate(format: "userID == %@ AND timestamp >= %@ AND timestamp <= %@", userID, from as NSDate, to as NSDate)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        do {
            let (results, _) = try await publicDB.records(
                matching: query,
                desiredKeys: ["shopID", "timestamp", "hasPhoto"],
                resultsLimit: CKQueryOperation.maximumResults
            )
            let records = results.compactMap { try? $1.get() }

            switch type {
            case .shops, .smallBiz:
                // Every shop Grounds surfaces is already independent (chains are filtered).
                return Set(records.compactMap { $0["shopID"] as? String }).count
            case .photos:
                return records.filter { ($0["hasPhoto"] as? Int ?? 0) == 1 }.count
            case .checkIns:
                return records.count
            case .streak:
                let calendar = Calendar.current
                let days = Set(records.compactMap { ($0["timestamp"] as? Date).map { calendar.startOfDay(for: $0) } })
                return Self.longestStreak(fromDays: days, calendar: calendar)
            }
        } catch {
            return 0
        }
    }

    /// Real check-in count for a shop, straight from CloudKit — never a made-up number.
    func checkInCount(forShopID shopID: String) async -> Int {
        let predicate = NSPredicate(format: "shopID == %@", shopID)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        do {
            let (results, _) = try await publicDB.records(
                matching: query,
                desiredKeys: [],   // we only need the count, not the field values
                resultsLimit: CKQueryOperation.maximumResults
            )
            return results.count
        } catch {
            return 0
        }
    }

    func fetchRecentCheckIns(limit: Int = 30) async {
        isLoading = true
        defer { isLoading = false }

        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: limit)
            recentCheckIns = results.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                let photoURL = (record["photo"] as? CKAsset)?.fileURL
                return CommunityCheckIn(
                    id:        record.recordID.recordName,
                    shopID:    record["shopID"] as? String ?? "",
                    shopName:  record["shopName"] as? String ?? "a coffee shop",
                    userName:  record["userName"] as? String ?? "Someone",
                    timestamp: record["timestamp"] as? Date ?? Date(),
                    photoURL:  photoURL,
                    caption:   record["caption"] as? String
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Real check-in history for one user — powers the Profile screen's activity feed and
    /// stamp card. Single-field equality predicate, same safe pattern as checkInCount(forShopID:).
    func fetchCheckIns(forUserID userID: String, limit: Int = 30) async -> [CommunityCheckIn] {
        let predicate = NSPredicate(format: "userID == %@", userID)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: limit)
            return results.compactMap { _, result in
                guard let record = try? result.get() else { return nil }
                let photoURL = (record["photo"] as? CKAsset)?.fileURL
                return CommunityCheckIn(
                    id:        record.recordID.recordName,
                    shopID:    record["shopID"] as? String ?? "",
                    shopName:  record["shopName"] as? String ?? "a coffee shop",
                    userName:  record["userName"] as? String ?? "Someone",
                    timestamp: record["timestamp"] as? Date ?? Date(),
                    photoURL:  photoURL,
                    caption:   record["caption"] as? String
                )
            }
        } catch {
            return []
        }
    }

    /// Real global leaderboard: aggregates every user's check-ins into weekly counts and
    /// consecutive-day streaks. Not a "friends" leaderboard — there's no friend graph — but
    /// every number here is computed from real check-in records, not invented.
    func fetchLeaderboard(limit: Int = 1000) async {
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]

        do {
            let (results, _) = try await publicDB.records(
                matching: query,
                desiredKeys: ["userID", "userName", "shopID", "timestamp", "hasPhoto"],
                resultsLimit: limit
            )

            struct RawCheckIn { let date: Date; let shopID: String; let hasPhoto: Bool }
            var byUser: [String: (name: String, checkIns: [RawCheckIn])] = [:]

            for (_, result) in results {
                guard let record = try? result.get(),
                      let userID = record["userID"] as? String else { continue }
                let name = record["userName"] as? String ?? "Someone"
                let date = record["timestamp"] as? Date ?? Date()
                let shopID = record["shopID"] as? String ?? ""
                let hasPhoto = (record["hasPhoto"] as? Int ?? 0) == 1
                byUser[userID, default: (name, [])].checkIns.append(RawCheckIn(date: date, shopID: shopID, hasPhoto: hasPhoto))
                byUser[userID]?.name = name   // keep most recent display name
            }

            let calendar = Calendar.current
            let now = Date()
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

            leaderboard = byUser.map { userID, entry in
                let checkIns = entry.checkIns
                let weekly = checkIns.filter { $0.date >= weekAgo }
                let uniqueDays = Set(checkIns.map { calendar.startOfDay(for: $0.date) })

                return CommunityLeaderboardEntry(
                    id:                 userID,
                    userName:           entry.name,
                    totalCheckIns:      checkIns.count,
                    totalShopsVisited:  Set(checkIns.map(\.shopID)).count,
                    weeklyCheckIns:     weekly.count,
                    weeklyShopsVisited: Set(weekly.map(\.shopID)).count,
                    weeklyPhotos:       weekly.filter(\.hasPhoto).count,
                    totalPhotos:        checkIns.filter(\.hasPhoto).count,
                    currentStreak:      Self.currentStreak(fromDays: uniqueDays, calendar: calendar, today: now),
                    longestStreak:      Self.longestStreak(fromDays: uniqueDays, calendar: calendar)
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Consecutive days ending today or yesterday (a streak stays "active" the day after a visit).
    private static func currentStreak(fromDays days: Set<Date>, calendar: Calendar, today: Date) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: today)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor), days.contains(yesterday) else {
                return 0
            }
            cursor = yesterday
        }
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Longest run of consecutive days anywhere in the history.
    private static func longestStreak(fromDays days: Set<Date>, calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        let sorted = days.sorted()
        var longest = 1
        var current = 1
        for i in 1..<sorted.count {
            if let expected = calendar.date(byAdding: .day, value: 1, to: sorted[i - 1]), expected == sorted[i] {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }
}
