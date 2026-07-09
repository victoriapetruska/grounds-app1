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

    var recentPhotos: [CommunityCheckIn] {
        community.recentCheckIns.filter { $0.photoURL != nil }.prefix(4).map { $0 }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                // ── Your Stats Card ───────────────────────────────────────────
                YourStreakCard(entry: me, isPremium: auth.currentUser.isPremium)
                    .padding(.horizontal, 16)

                // ── Weekly Race ───────────────────────────────────────────────
                VStack(spacing: 12) {
                    LeagueSectionHeader(
                        title: "WEEKLY RACE",
                        subtitle: resetCountdown,
                        icon: "trophy.fill",
                        color: G.gold
                    )
                    .padding(.horizontal, 16)

                    if weeklyRanked.count >= 3 {
                        WeeklyPodium(entries: Array(weeklyRanked.prefix(3)), currentUserID: me.id)
                            .padding(.horizontal, 16)
                    }

                    VStack(spacing: 8) {
                        ForEach(Array(weeklyRanked.enumerated()), id: \.offset) { i, entry in
                            WeeklyRaceRow(rank: i + 1, entry: entry, isCurrentUser: entry.id == me.id,
                                          isPremium: entry.id == me.id && auth.currentUser.isPremium)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // ── Streak Leaderboard ────────────────────────────────────────
                VStack(spacing: 12) {
                    LeagueSectionHeader(
                        title: "STREAK KINGS",
                        subtitle: "Consecutive daily visits",
                        icon: "flame.fill",
                        color: Color.orange
                    )
                    .padding(.horizontal, 16)

                    VStack(spacing: 8) {
                        ForEach(Array(streakRanked.enumerated()), id: \.offset) { i, entry in
                            StreakRow(rank: i + 1, entry: entry, isCurrentUser: entry.id == me.id)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // ── Small Business Champion ───────────────────────────────────
                VStack(spacing: 12) {
                    LeagueSectionHeader(
                        title: "SMALL BIZ CHAMPION",
                        subtitle: "Supporting independent roasters",
                        icon: "storefront.fill",
                        color: G.sage
                    )
                    .padding(.horizontal, 16)

                    SmallBizChampionCard(
                        topEntries: Array(mostVisitsRanked.prefix(3)),
                        currentUserID: me.id
                    )
                    .padding(.horizontal, 16)
                }

                // ── Photo Wall ────────────────────────────────────────────────
                VStack(spacing: 12) {
                    LeagueSectionHeader(
                        title: "PHOTO WALL",
                        subtitle: "Recent check-in photos",
                        icon: "camera.fill",
                        color: G.caramel
                    )
                    .padding(.horizontal, 16)

                    if recentPhotos.isEmpty {
                        Text("No check-in photos yet — be the first to share one!")
                            .font(G.body(13))
                            .foregroundStyle(G.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        PhotoWallSection(checkIns: recentPhotos)
                            .padding(.horizontal, 16)
                    }
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 12)
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

// MARK: - Your Streak Card

struct YourStreakCard: View {
    let entry: CommunityLeaderboardEntry
    let isPremium: Bool

    var streakFlameLevel: Int {
        switch entry.currentStreak {
        case 0:     return 0
        case 1...3: return 1
        case 4...6: return 2
        case 7...13: return 3
        default:    return 4
        }
    }

    var flameColor: LinearGradient {
        switch streakFlameLevel {
        case 1: return LinearGradient(colors: [Color.orange, Color.red.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        case 2: return LinearGradient(colors: [Color.orange, Color.red],              startPoint: .top, endPoint: .bottom)
        case 3: return LinearGradient(colors: [Color.yellow, Color.orange, Color.red],startPoint: .top, endPoint: .bottom)
        default: return LinearGradient(colors: [Color.orange, Color.red],             startPoint: .top, endPoint: .bottom)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [G.roast, G.surface2],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 20).stroke(G.border, lineWidth: 1)

            VStack(spacing: 16) {
                // Top row: streak
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your Streak")
                            .font(G.label(11))
                            .foregroundStyle(G.muted)
                            .textCase(.uppercase)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if entry.currentStreak > 0 {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(flameColor)
                            } else {
                                Image(systemName: "flame")
                                    .font(.system(size: 28))
                                    .foregroundStyle(G.muted)
                            }
                            Text("\(entry.currentStreak)")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(entry.currentStreak > 0 ? G.cream : G.muted)
                            Text("days")
                                .font(G.body(16))
                                .foregroundStyle(G.muted)
                                .padding(.bottom, 4)
                        }

                        Text(entry.currentStreak > 0 ? "🟢 Active today" : "⚠️ Check in to start a streak!")
                            .font(G.label(11))
                            .foregroundStyle(entry.currentStreak > 0 ? G.sage : G.gold)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        StatBubble(value: "\(entry.longestStreak)", label: "Best")
                        StatBubble(value: "\(entry.totalPhotos)", label: "Photos")
                    }
                }

                Divider().background(G.border)

                // Bottom row: weekly stats
                HStack(spacing: 0) {
                    WeeklyStat(value: entry.weeklyShopsVisited, label: "Shops\nThis Week",  icon: "map.fill",       color: G.caramel)
                    dividerLine
                    WeeklyStat(value: entry.weeklyPhotos,       label: "Photos\nThis Week", icon: "camera.fill",    color: G.latte)
                    dividerLine
                    WeeklyStat(value: entry.weeklyCheckIns,     label: "Check-ins\nThis Week",icon: "mappin.circle.fill",color: G.sage)
                }
            }
            .padding(20)
        }
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(G.border)
            .frame(width: 1, height: 40)
    }
}

struct StatBubble: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(G.mono(15)).fontWeight(.bold).foregroundStyle(G.cream)
            Text(label).font(G.label(9)).foregroundStyle(G.muted)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(G.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(G.border, lineWidth: 1))
    }
}

struct WeeklyStat: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(G.cream)
            Text(label)
                .font(G.label(9))
                .foregroundStyle(G.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Section Header

struct LeagueSectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(G.label(13))
                    .foregroundStyle(G.cream)
                    .textCase(.uppercase)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(G.label(10))
                        .foregroundStyle(G.muted)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Weekly Podium (compact)

struct WeeklyPodium: View {
    let entries: [CommunityLeaderboardEntry]   // expects 3: [0] = 1st, [1] = 2nd, [2] = 3rd
    let currentUserID: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if entries.count > 1 { PodiumSlot(entry: entries[1], position: 2, isCurrentUser: entries[1].id == currentUserID) }
            if entries.count > 0 { PodiumSlot(entry: entries[0], position: 1, isCurrentUser: entries[0].id == currentUserID) }
            if entries.count > 2 { PodiumSlot(entry: entries[2], position: 3, isCurrentUser: entries[2].id == currentUserID) }
        }
    }
}

struct PodiumSlot: View {
    let entry: CommunityLeaderboardEntry
    let position: Int
    let isCurrentUser: Bool

    var medal: String  { ["🥇","🥈","🥉"][position - 1] }
    var height: CGFloat { position == 1 ? 110 : 80 }
    var borderColor: Color {
        switch position {
        case 1: return G.gold
        case 2: return Color(hex: "C0C0C0")
        default: return Color(hex: "CD7F32")
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(medal).font(.system(size: 22))

            ZStack {
                Circle()
                    .fill(isCurrentUser ? G.caramelGrad : LinearGradient(colors: [G.surface2], startPoint: .top, endPoint: .bottom))
                    .frame(width: 48, height: 48)
                    .overlay(Circle().stroke(borderColor, lineWidth: 2))
                Text(String(entry.userName.prefix(1)))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(entry.userName.components(separatedBy: " ").first ?? entry.userName)
                .font(G.label(11))
                .foregroundStyle(isCurrentUser ? G.caramel : G.cream)
                .lineLimit(1)

            HStack(spacing: 3) {
                Image(systemName: "map.fill").font(.system(size: 9)).foregroundStyle(G.muted)
                Text("\(entry.weeklyShopsVisited)").font(G.mono(13)).fontWeight(.bold).foregroundStyle(G.latte)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(.vertical, 12)
        .background(isCurrentUser ? G.caramel.opacity(0.12) : G.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isCurrentUser ? G.caramel : G.border, lineWidth: 1))
    }
}

// MARK: - Weekly Race Row

struct WeeklyRaceRow: View {
    let rank: Int
    let entry: CommunityLeaderboardEntry
    let isCurrentUser: Bool
    let isPremium: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(G.mono(13))
                .foregroundStyle(rank <= 3 ? G.gold : G.muted)
                .frame(width: 28)

            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: entry.userName, size: 40)
                if entry.currentStreak >= 3 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .background(Circle().fill(G.espresso).frame(width: 16, height: 16))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(entry.userName)
                        .font(G.body(14)).fontWeight(isCurrentUser ? .bold : .semibold)
                        .foregroundStyle(isCurrentUser ? G.caramel : G.cream)
                    if isCurrentUser { Text("(you)").font(G.label(10)).foregroundStyle(G.caramel) }
                    if isPremium { ProBadge() }
                }
                HStack(spacing: 8) {
                    Label("\(entry.currentStreak)d", systemImage: "flame.fill")
                        .font(G.label(10))
                        .foregroundStyle(entry.currentStreak > 0 ? .orange : G.muted)
                    Label("\(entry.weeklyPhotos) photos", systemImage: "camera.fill")
                        .font(G.label(10))
                        .foregroundStyle(G.muted)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.weeklyShopsVisited)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(isCurrentUser ? G.caramel : G.cream)
                Text("shops").font(G.label(9)).foregroundStyle(G.muted)
            }
        }
        .padding(12)
        .background(isCurrentUser ? G.caramel.opacity(0.1) : G.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isCurrentUser ? G.caramel.opacity(0.5) : G.border, lineWidth: 1))
    }
}

// MARK: - Streak Row

struct StreakRow: View {
    let rank: Int
    let entry: CommunityLeaderboardEntry
    let isCurrentUser: Bool

    var flameColor: Color {
        switch entry.currentStreak {
        case 0:     return G.muted
        case 1...3: return .orange
        case 4...9: return .red
        default:    return .yellow
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)").font(G.mono(13)).foregroundStyle(rank == 1 ? G.gold : G.muted).frame(width: 28)
            AvatarView(name: entry.userName, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(entry.userName)
                        .font(G.body(14)).fontWeight(.semibold)
                        .foregroundStyle(isCurrentUser ? G.caramel : G.cream)
                    if isCurrentUser { Text("(you)").font(G.label(10)).foregroundStyle(G.caramel) }
                }
                Text("Best: \(entry.longestStreak) days")
                    .font(G.label(10)).foregroundStyle(G.muted)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: entry.currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 18))
                    .foregroundStyle(flameColor)
                Text("\(entry.currentStreak)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(entry.currentStreak > 0 ? G.cream : G.muted)
            }
        }
        .padding(12)
        .background(isCurrentUser ? G.caramel.opacity(0.1) : G.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isCurrentUser ? G.caramel.opacity(0.5) : G.border, lineWidth: 1))
    }
}

// MARK: - Small Biz Champion Card

struct SmallBizChampionCard: View {
    let topEntries: [CommunityLeaderboardEntry]
    let currentUserID: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(
                    colors: [G.sage.opacity(0.2), G.espresso],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
            RoundedRectangle(cornerRadius: 18).stroke(G.sage.opacity(0.4), lineWidth: 1)

            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 16)).foregroundStyle(G.sage)
                    Text("Every shop on Grounds is independent — chains aren't shown")
                        .font(G.label(11)).foregroundStyle(G.sage)
                    Spacer()
                }

                if topEntries.isEmpty {
                    Text("No check-ins yet")
                        .font(G.body(13)).foregroundStyle(G.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                } else {
                    ForEach(Array(topEntries.enumerated()), id: \.offset) { i, entry in
                        HStack(spacing: 12) {
                            Text(["🥇","🥈","🥉"][i]).font(.system(size: 20))
                            AvatarView(name: entry.userName, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.userName)
                                    .font(G.body(13)).fontWeight(.semibold)
                                    .foregroundStyle(entry.id == currentUserID ? G.caramel : G.cream)
                                Text("\(entry.totalCheckIns) indie check-ins")
                                    .font(G.label(10)).foregroundStyle(G.muted)
                            }
                            Spacer()
                        }
                        if i < topEntries.count - 1 {
                            Divider().background(G.sage.opacity(0.2))
                        }
                    }
                }
            }
            .padding(16)
        }
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
                                AvatarView(name: checkIn.userName, size: 40)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    } else {
                        AvatarView(name: checkIn.userName, size: 40)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(checkIn.userName)
                                .font(G.body(13)).fontWeight(.semibold).foregroundStyle(G.cream)
                            Text("checked in")
                                .font(G.body(12)).foregroundStyle(G.muted)
                        }
                        Text(checkIn.shopName)
                            .font(G.label(11)).foregroundStyle(G.caramel)
                        Text(checkIn.timestamp.formatted(.relative(presentation: .named)))
                            .font(G.label(10)).foregroundStyle(G.muted)
                    }

                    Spacer()
                }
                .padding(12)
                .background(G.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.border, lineWidth: 1))
            }
        }
    }
}
