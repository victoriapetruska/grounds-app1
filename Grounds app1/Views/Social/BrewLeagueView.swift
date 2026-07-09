import SwiftUI
import Combine

struct BrewLeagueView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var community: CommunityService
    @State private var resetCountdown = ""
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private static let emptyEntry = { (id: String, name: String) in
        CommunityLeaderboardEntry(
            id: id, userName: name, totalCheckIns: 0, totalShopsVisited: 0,
            weeklyCheckIns: 0, weeklyShopsVisited: 0, weeklyPhotos: 0, totalPhotos: 0,
            currentStreak: 0, longestStreak: 0
        )
    }

    // "You" always appears, even with zero real check-ins yet.
    var me: CommunityLeaderboardEntry {
        community.leaderboard.first(where: { $0.id == auth.currentUser.id })
            ?? Self.emptyEntry(auth.currentUser.id, auth.currentUser.name)
    }

    var allEntries: [CommunityLeaderboardEntry] {
        community.leaderboard.contains(where: { $0.id == auth.currentUser.id })
            ? community.leaderboard
            : community.leaderboard + [me]
    }

    var weeklyRanked: [CommunityLeaderboardEntry] {
        allEntries.sorted { $0.weeklyShopsVisited > $1.weeklyShopsVisited }
    }

    var streakRanked: [CommunityLeaderboardEntry] {
        allEntries.sorted { $0.currentStreak > $1.currentStreak }
    }

    // Ranked by all-time check-ins — every shop Grounds surfaces is already independent
    // (chains are filtered out), so this doubles as the "small biz champion" ranking.
    var mostVisitsRanked: [CommunityLeaderboardEntry] {
        allEntries.sorted { $0.totalCheckIns > $1.totalCheckIns }
    }

    var myRank: Int {
        (mostVisitsRanked.firstIndex(where: { $0.id == me.id }) ?? mostVisitsRanked.count) + 1
    }

    var recentPhotos: [CommunityCheckIn] {
        community.recentCheckIns.filter { $0.photoURL != nil }.prefix(4).map { $0 }
    }

    var body: some View {
        ZStack {
            G.parchment.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {

                    // ── Your rank, unified ─────────────────────────────────────
                    YourLeagueCard(entry: me, rank: myRank, resetCountdown: resetCountdown)
                        .padding(.horizontal, 16)

                    // ── This week ────────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        PaperSectionHeader("THIS WEEK", subtitle: "shops visited")
                            .padding(.horizontal, 20)
                        VStack(spacing: 8) {
                            ForEach(Array(weeklyRanked.prefix(6).enumerated()), id: \.offset) { i, entry in
                                LeagueRow(rank: i + 1, entry: entry, isCurrentUser: entry.id == me.id,
                                          metric: entry.weeklyShopsVisited, metricLabel: "shops")
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // ── Streak kings ─────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        PaperSectionHeader("STREAK KINGS", subtitle: "consecutive days")
                            .padding(.horizontal, 20)
                        VStack(spacing: 8) {
                            ForEach(Array(streakRanked.prefix(6).enumerated()), id: \.offset) { i, entry in
                                LeagueRow(rank: i + 1, entry: entry, isCurrentUser: entry.id == me.id,
                                          metric: entry.currentStreak, metricLabel: "days")
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // ── Small biz champion ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        PaperSectionHeader("SMALL BIZ CHAMPION", subtitle: "all-time, independents only")
                            .padding(.horizontal, 20)
                        VStack(spacing: 8) {
                            if mostVisitsRanked.allSatisfy({ $0.totalCheckIns == 0 }) {
                                PaperEmptyRow(text: "No check-ins yet — be the first on the board.")
                            } else {
                                ForEach(Array(mostVisitsRanked.prefix(3).enumerated()), id: \.offset) { i, entry in
                                    LeagueRow(rank: i + 1, entry: entry, isCurrentUser: entry.id == me.id,
                                              metric: entry.totalCheckIns, metricLabel: "check-ins")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // ── Photo wall ────────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 10) {
                        PaperSectionHeader("PHOTO WALL", subtitle: "recent check-ins")
                            .padding(.horizontal, 20)
                        if recentPhotos.isEmpty {
                            PaperEmptyRow(text: "No check-in photos yet — be the first to share one.")
                                .padding(.horizontal, 16)
                        } else {
                            PhotoWallSection(checkIns: recentPhotos)
                                .padding(.horizontal, 16)
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.top, 16)
            }
        }
        .onAppear { updateCountdown() }
        .onReceive(timer) { _ in updateCountdown() }
        .task {
            await community.fetchLeaderboard()
            if community.recentCheckIns.isEmpty {
                await community.fetchRecentCheckIns()
            }
        }
    }

    private func updateCountdown() {
        let cal  = Calendar.current
        var comps = DateComponents()
        comps.weekday = 1  // Sunday
        comps.hour    = 0
        comps.minute  = 0
        comps.second  = 0
        guard let next = cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime) else { return }
        let diff  = next.timeIntervalSinceNow
        let days  = Int(diff / 86400)
        let hours = Int((diff.truncatingRemainder(dividingBy: 86400)) / 3600)
        let mins  = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
        resetCountdown = days > 0
            ? "Resets in \(days)d \(hours)h"
            : "Resets in \(hours)h \(mins)m"
    }
}

// MARK: - Your League Card (unified — replaces the old 4-box streak card)

struct YourLeagueCard: View {
    let entry: CommunityLeaderboardEntry
    let rank: Int
    let resetCountdown: String

    /// Streak visualized as a row of small filled/outline dots (max 7 shown, then a
    /// "+N" mono suffix) — lighter-weight than a full StampMark, since this repeats
    /// per day rather than marking a single earned, distinct achievement.
    private var streakDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<min(entry.currentStreak, 7), id: \.self) { _ in
                Circle().fill(G.stampRed).frame(width: 8, height: 8)
            }
            ForEach(0..<max(0, min(7, 7) - min(entry.currentStreak, 7)), id: \.self) { _ in
                Circle().stroke(G.kraftLine, lineWidth: 1.2).frame(width: 8, height: 8)
            }
            if entry.currentStreak > 7 {
                Text("+\(entry.currentStreak - 7)")
                    .font(G.mono(11))
                    .foregroundStyle(G.stampRed)
                    .padding(.leading, 2)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(entry.currentStreak)")
                        .font(G.serif(40, weight: .bold))
                        .foregroundStyle(G.darkRoast)
                    Text(entry.currentStreak == 1 ? "day streak" : "day streak")
                        .font(G.sans(14))
                        .foregroundStyle(G.lightRoast)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("RANK #\(rank)")
                        .font(G.mono(12))
                        .foregroundStyle(G.stampRed)
                    if !resetCountdown.isEmpty {
                        Text(resetCountdown)
                            .font(G.mono(10))
                            .foregroundStyle(G.lightRoast)
                    }
                }
            }

            streakDots

            Divider().background(G.kraftLine)

            HStack(spacing: 20) {
                LeagueMiniStat(value: entry.weeklyShopsVisited, label: "this week")
                LeagueMiniStat(value: entry.longestStreak, label: "best streak")
                LeagueMiniStat(value: entry.totalPhotos, label: "photos")
                Spacer()
            }
        }
        .padding(18)
        .background(G.kraft)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(G.kraftLine, lineWidth: 1))
    }
}

struct LeagueMiniStat: View {
    let value: Int
    let label: String
    var body: some View {
        HStack(spacing: 5) {
            Text("\(value)").font(G.mono(14)).foregroundStyle(G.darkRoast)
            Text(label).font(G.sans(11)).foregroundStyle(G.lightRoast)
        }
    }
}

// MARK: - Shared ranked row (This Week / Streak Kings / Small Biz Champion)

struct LeagueRow: View {
    let rank: Int
    let entry: CommunityLeaderboardEntry
    let isCurrentUser: Bool
    let metric: Int
    let metricLabel: String

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(G.mono(13))
                .foregroundStyle(rank <= 3 ? G.stampRed : G.lightRoast)
                .frame(width: 26, alignment: .leading)

            ZStack {
                Circle().fill(G.parchment)
                Text(String(entry.userName.prefix(1)).uppercased())
                    .font(G.serif(15, weight: .bold))
                    .foregroundStyle(G.darkRoast)
            }
            .frame(width: 36, height: 36)
            .overlay(Circle().stroke(isCurrentUser ? G.stampRed : G.kraftLine, lineWidth: isCurrentUser ? 1.5 : 1))

            HStack(spacing: 5) {
                Text(entry.userName)
                    .font(G.sans(14, weight: isCurrentUser ? .semibold : .regular))
                    .foregroundStyle(G.darkRoast)
                if isCurrentUser {
                    Text("(you)").font(G.mono(10)).foregroundStyle(G.stampRed)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text("\(metric)").font(G.mono(15)).foregroundStyle(G.darkRoast)
                Text(metricLabel).font(G.mono(10)).foregroundStyle(G.lightRoast)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isCurrentUser ? G.stampRed.opacity(0.06) : G.kraft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isCurrentUser ? G.stampRed.opacity(0.4) : G.kraftLine, lineWidth: 1))
    }
}

// MARK: - Photo Wall

struct PhotoWallSection: View {
    let checkIns: [CommunityCheckIn]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(checkIns) { checkIn in
                HStack(spacing: 12) {
                    if let url = checkIn.photoURL {
                        AsyncImage(url: url) { phase in
                            if case .success(let img) = phase {
                                img.resizable().scaledToFill()
                            } else {
                                Circle().fill(G.kraftLine)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle().fill(G.kraftLine)
                            Text(String(checkIn.userName.prefix(1)).uppercased())
                                .font(G.serif(14, weight: .bold))
                                .foregroundStyle(G.darkRoast)
                        }
                        .frame(width: 40, height: 40)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(checkIn.userName)
                                .font(G.sans(13, weight: .semibold)).foregroundStyle(G.darkRoast)
                            Text("checked in")
                                .font(G.sans(12)).foregroundStyle(G.lightRoast)
                        }
                        Text(checkIn.shopName)
                            .font(G.mono(11)).foregroundStyle(G.stampRed)
                        Text(checkIn.timestamp.formatted(.relative(presentation: .named)))
                            .font(G.mono(10)).foregroundStyle(G.lightRoast)
                    }

                    Spacer()
                }
                .padding(12)
                .background(G.kraft)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.kraftLine, lineWidth: 1))
            }
        }
    }
}
