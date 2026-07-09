import Foundation
import CloudKit
import Combine

struct GroundsUserProfile: Identifiable, Equatable {
    let id: String       // Apple user identifier
    let username: String
    let name: String
    let bio: String
}

enum FriendRequestStatus: String {
    case pending, accepted, declined
}

struct FriendRequestRecord: Identifiable {
    let id: String        // CKRecord.recordID.recordName
    let fromUserID: String
    let fromUserName: String
    let fromUsername: String
    let toUserID: String
    let toUserName: String
    let toUsername: String
    let status: FriendRequestStatus
    let timestamp: Date
}

/// Real friends, friend requests, and challenges — all stored in CloudKit's public database.
/// Nothing in this file is mock data; everyone found here is a real Grounds user.
@MainActor
class SocialService: ObservableObject {
    @Published private(set) var friends: [GroundsUserProfile] = []
    @Published private(set) var incomingRequests: [FriendRequestRecord] = []
    @Published private(set) var outgoingRequests: [FriendRequestRecord] = []
    @Published private(set) var searchResults: [GroundsUserProfile] = []
    @Published private(set) var challenges: [Challenge] = []
    @Published var errorMessage: String?

    private let container = CKContainer(identifier: "iCloud.coffeeground.Grounds-app1")
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    private static let profileRecordType = "UserProfile"
    private static let friendRequestRecordType = "FriendRequest"
    private static let challengeRecordType = "Challenge"

    /// A CloudKit record type only exists in the schema after its first successful save —
    /// querying it before that returns "did not find record type", which just means "no data
    /// yet", not a real error worth surfacing to the user.
    private func isMissingSchema(_ error: Error) -> Bool {
        (error as? CKError)?.code == .unknownItem
            || error.localizedDescription.contains("did not find record type")
    }

    // MARK: - Profile directory

    /// Makes the current user discoverable by username. Call after sign-in and after bio edits.
    func upsertProfile(userID: String, username: String, name: String, bio: String) async {
        let recordID = CKRecord.ID(recordName: "profile_\(userID)")
        do {
            let record = (try? await publicDB.record(for: recordID))
                ?? CKRecord(recordType: Self.profileRecordType, recordID: recordID)
            record["userID"]   = userID
            record["username"] = username.lowercased()
            record["name"]     = name
            record["bio"]      = bio
            _ = try await publicDB.save(record)
        } catch {
            print("[Grounds] Failed to upsert profile: \(error.localizedDescription)")
        }
    }

    func searchUsers(query: String, excludingUserID: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 2 else { searchResults = []; return }

        // BEGINSWITH requires a "Searchable" CloudKit schema index that isn't auto-created,
        // so fetch broadly and filter by prefix locally instead — no CloudKit Dashboard
        // configuration needed. NSPredicate(value: true) looked like the way to do that,
        // but it actually requires the system `recordName` field to be marked Queryable
        // (a schema setting most record types don't have), and fails with "Invalid
        // Arguments" instead of just returning everything. A real-field predicate that's
        // always true — userID is set on every profile — gets "everything" without that.
        let ckQuery = CKQuery(recordType: Self.profileRecordType, predicate: NSPredicate(format: "userID != %@", ""))
        do {
            let (results, _) = try await publicDB.records(matching: ckQuery, resultsLimit: 200)
            searchResults = results.compactMap { _, result -> GroundsUserProfile? in
                guard let record = try? result.get(),
                      let userID = record["userID"] as? String,
                      userID != excludingUserID,
                      let username = record["username"] as? String,
                      username.hasPrefix(trimmed)
                else { return nil }
                return GroundsUserProfile(
                    id:       userID,
                    username: username,
                    name:     record["name"] as? String ?? "Someone",
                    bio:      record["bio"] as? String ?? ""
                )
            }
            .prefix(20)
            .map { $0 }
            errorMessage = nil
        } catch {
            if isMissingSchema(error) { searchResults = [] } else { errorMessage = error.localizedDescription }
        }
    }

    // MARK: - Friend requests

    func sendFriendRequest(from: GroundsUserProfile, to: GroundsUserProfile) async {
        let record = CKRecord(recordType: Self.friendRequestRecordType)
        record["fromUserID"]   = from.id
        record["fromUserName"] = from.name
        record["fromUsername"] = from.username
        record["toUserID"]     = to.id
        record["toUserName"]   = to.name
        record["toUsername"]   = to.username
        record["status"]       = FriendRequestStatus.pending.rawValue
        record["timestamp"]    = Date()
        do {
            _ = try await publicDB.save(record)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't send friend request: \(error.localizedDescription)"
        }
    }

    func respondToFriendRequest(_ request: FriendRequestRecord, accept: Bool) async {
        let recordID = CKRecord.ID(recordName: request.id)
        do {
            let record = try await publicDB.record(for: recordID)
            record["status"] = (accept ? FriendRequestStatus.accepted : .declined).rawValue
            _ = try await publicDB.save(record)
            incomingRequests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = "Couldn't respond to friend request: \(error.localizedDescription)"
        }
    }

    func fetchFriendsAndRequests(myID: String) async {
        // CloudKit's query parser rejects some OR predicates across different fields
        // ("invalid predicate: unexpected expression"), so fetch broadly and filter to
        // "involves me" locally. A real-field predicate (timestamp is always set, and
        // it's what we'd index anyway) avoids the recordName-Queryable requirement that
        // NSPredicate(value: true) triggers.
        let query = CKQuery(recordType: Self.friendRequestRecordType,
                             predicate: NSPredicate(format: "timestamp > %@", NSDate(timeIntervalSince1970: 0)))
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 500)
            var friendsList: [GroundsUserProfile] = []
            var incoming: [FriendRequestRecord] = []
            var outgoing: [FriendRequestRecord] = []

            for (_, result) in results {
                guard let record = try? result.get(),
                      let fromID = record["fromUserID"] as? String,
                      let fromName = record["fromUserName"] as? String,
                      let fromUsername = record["fromUsername"] as? String,
                      let toID = record["toUserID"] as? String,
                      let toName = record["toUserName"] as? String,
                      let toUsername = record["toUsername"] as? String,
                      let statusRaw = record["status"] as? String,
                      let status = FriendRequestStatus(rawValue: statusRaw),
                      let timestamp = record["timestamp"] as? Date,
                      fromID == myID || toID == myID
                else { continue }

                let req = FriendRequestRecord(
                    id: record.recordID.recordName,
                    fromUserID: fromID, fromUserName: fromName, fromUsername: fromUsername,
                    toUserID: toID, toUserName: toName, toUsername: toUsername,
                    status: status, timestamp: timestamp
                )

                switch status {
                case .accepted:
                    let iSent = fromID == myID
                    friendsList.append(GroundsUserProfile(
                        id:       iSent ? toID : fromID,
                        username: iSent ? toUsername : fromUsername,
                        name:     iSent ? toName : fromName,
                        bio:      ""
                    ))
                case .pending:
                    if toID == myID { incoming.append(req) }
                    else if fromID == myID { outgoing.append(req) }
                case .declined:
                    break
                }
            }
            friends = friendsList
            incomingRequests = incoming
            outgoingRequests = outgoing
            errorMessage = nil
        } catch {
            if isMissingSchema(error) {
                friends = []; incomingRequests = []; outgoingRequests = []
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Challenges

    func createChallenge(_ challenge: Challenge) async {
        let record = CKRecord(recordType: Self.challengeRecordType, recordID: CKRecord.ID(recordName: challenge.id))
        record["type"]           = challenge.type.rawValue
        record["duration"]       = challenge.duration.rawValue
        record["startDate"]      = challenge.startDate
        record["endDate"]        = challenge.endDate
        record["status"]         = challenge.status.rawValue
        record["challengerID"]   = challenge.challengerID
        record["challengerName"] = challenge.challengerName
        record["opponentID"]     = challenge.opponentID
        record["opponentName"]   = challenge.opponentName
        do {
            _ = try await publicDB.save(record)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't create challenge: \(error.localizedDescription)"
        }
    }

    func respondToChallenge(_ challenge: Challenge, accept: Bool) async {
        let recordID = CKRecord.ID(recordName: challenge.id)
        do {
            let record = try await publicDB.record(for: recordID)
            record["status"] = (accept ? ChallengeStatus.active : .declined).rawValue
            if accept { record["startDate"] = Date() }
            _ = try await publicDB.save(record)
        } catch {
            errorMessage = "Couldn't respond to challenge: \(error.localizedDescription)"
        }
    }

    func markChallengeCompleted(_ id: String) async {
        let recordID = CKRecord.ID(recordName: id)
        guard let record = try? await publicDB.record(for: recordID) else { return }
        record["status"] = ChallengeStatus.completed.rawValue
        _ = try? await publicDB.save(record)
    }

    func fetchChallenges(myID: String) async {
        // Same OR-predicate issue as fetchFriendsAndRequests — fetch broadly, filter locally,
        // using a real-field predicate (startDate) instead of NSPredicate(value: true) so it
        // doesn't need the recordName-Queryable schema setting.
        let query = CKQuery(recordType: Self.challengeRecordType,
                             predicate: NSPredicate(format: "startDate > %@", NSDate(timeIntervalSince1970: 0)))
        query.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        do {
            let (results, _) = try await publicDB.records(matching: query, resultsLimit: 200)
            challenges = results.compactMap { _, result in
                guard let record = try? result.get(),
                      let typeRaw = record["type"] as? String, let type = ChallengeType(rawValue: typeRaw),
                      let durationRaw = record["duration"] as? Int, let duration = ChallengeDuration(rawValue: durationRaw),
                      let startDate = record["startDate"] as? Date,
                      let endDate = record["endDate"] as? Date,
                      let statusRaw = record["status"] as? String, let status = ChallengeStatus(rawValue: statusRaw),
                      let challengerID = record["challengerID"] as? String,
                      let challengerName = record["challengerName"] as? String,
                      let opponentID = record["opponentID"] as? String,
                      let opponentName = record["opponentName"] as? String,
                      challengerID == myID || opponentID == myID
                else { return nil }

                return Challenge(
                    id: record.recordID.recordName, type: type, duration: duration,
                    startDate: startDate, endDate: endDate, status: status,
                    challengerID: challengerID, challengerName: challengerName, challengerAvatar: nil,
                    opponentID: opponentID, opponentName: opponentName, opponentAvatar: nil,
                    challengerScore: 0, opponentScore: 0   // filled in live by BattlesView from real check-ins
                )
            }
            errorMessage = nil
        } catch {
            if isMissingSchema(error) { challenges = [] } else { errorMessage = error.localizedDescription }
        }
    }
}
