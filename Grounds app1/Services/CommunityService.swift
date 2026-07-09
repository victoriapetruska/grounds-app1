import Foundation
import CloudKit
import UIKit
import Combine

struct CommunityCheckIn: Identifiable {
    let id: String
    let shopName: String
    let userName: String
    let timestamp: Date
    let photoURL: URL?
    let caption: String?
}

/// Stores check-ins (with optional photos) in CloudKit's public database so every
/// user's visits are visible to the community — this is the app's only real backend.
@MainActor
class CommunityService: ObservableObject {
    @Published private(set) var recentCheckIns: [CommunityCheckIn] = []
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
    func postCheckIn(shopID: String, shopName: String, userName: String, photo: UIImage?, caption: String?) async {
        guard await isICloudAvailable() else {
            errorMessage = "Sign in to iCloud in Settings to share check-ins with the community."
            return
        }

        let record = CKRecord(recordType: Self.recordType)
        record["shopID"]    = shopID
        record["shopName"]  = shopName
        record["userName"]  = userName
        record["timestamp"] = Date()
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
        } catch {
            errorMessage = "Couldn't share your check-in: \(error.localizedDescription)"
        }

        if let tempFileURL {
            try? FileManager.default.removeItem(at: tempFileURL)
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
}
