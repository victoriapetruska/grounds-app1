import SwiftUI
import Combine

struct BrewLeagueView: View {
    @EnvironmentObject var auth: AuthService
    @State private var resetCountdown = ""
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var me: User { auth.currentUser }
    var allUsers: [User] { [me] + MockData.friends }

    // Sort by weekly shops visited for the weekly race
    var weeklyRanked: [User] {
        allUsers.sorted { $0.weeklyShopsVisited > $1.weeklyShopsVisited }
    }

    // Sort by small biz visits all-time
    var smallBizRanked: [User] {
        allUsers.sorted { $0.smallBizVisits > $1.smallBizVisits }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                // ── Your Stats Card ───────────────────────────────────────────
                YourStreakCard(user: me)
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

                    // Top 3 compact podium
                    if weeklyRanked.count >= 3 {
                        WeeklyPodium(users: Array(weeklyRanked.prefix(3)), currentUserID: me.id)
                            .padding(.horizontal, 16)
                    }

                    // Rest of list
                    VStack(spacing: 8) {
                        ForEach(Array(weeklyRanked.enumerated()), id: \.offset) { i, user in
                            WeeklyRaceRow(rank: i + 1, user: user, isCurrentUser: user.id == me.id)
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

                    let streakRanked = allUsers.sorted { $0.currentStreak > $1.currentStreak }
                    VStack(spacing: 8) {
                        ForEach(Array(streakRanked.enumerated()), id: \.offset) { i, user in
                            StreakRow(rank: i + 1, user: user, isCurrentUser: user.id == me.id)
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
                        topUsers: Array(smallBizRanked.prefix(3)),
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

                    PhotoWallSection(users: Array(allUsers.sorted { $0.weeklyPhotos > $1.weeklyPhotos }.prefix(4)))
                        .padding(.horizontal, 16)
                }

                Spacer(minLength: 100)
            }
            .padding(.top, 12)
        }
        .onAppear { updateCountdown() }
        .onReceive(timer) { _ in updateCountdown() }
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
    let user: User

    var flameColor: LinearGradient {
        switch user.streakFlameLevel {
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
                            if user.currentStreak > 0 {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(flameColor)
                            } else {
                                Image(systemName: "flame")
                                    .font(.system(size: 28))
                                    .foregroundStyle(G.muted)
                            }
                            Text("\(user.currentStreak)")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(user.currentStreak > 0 ? G.cream : G.muted)
                            Text("days")
                                .font(G.body(16))
                                .foregroundStyle(G.muted)
                                .padding(.bottom, 4)
                        }

                        Text(user.isStreakActive ? "🟢 Active today" : "⚠️ Check in to keep your streak!")
                            .font(G.label(11))
                            .foregroundStyle(user.isStreakActive ? G.sage : G.gold)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        StatBubble(value: "\(user.longestStreak)", label: "Best")
                        StatBubble(value: "\(user.totalPhotos)", label: "Photos")
                    }
                }

                Divider().background(G.border)

                // Bottom row: weekly stats
                HStack(spacing: 0) {
                    WeeklyStat(value: user.weeklyShopsVisited, label: "Shops\nThis Week",  icon: "map.fill",       color: G.caramel)
                    dividerLine
                    WeeklyStat(value: user.weeklyPhotos,       label: "Photos\nThis Week", icon: "camera.fill",    color: G.latte)
                    dividerLine
                    WeeklyStat(value: user.smallBizVisits,     label: "Small Biz\nVisits", icon: "storefront.fill",color: G.sage)
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
    let users: [User]   // expects 3 users: [0] = 1st, [1] = 2nd, [2] = 3rd
    let currentUserID: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // 2nd place
            if users.count > 1 { PodiumSlot(user: users[1], position: 2, isCurrentUser: users[1].id == currentUserID) }
            // 1st place (tallest)
            if users.count > 0 { PodiumSlot(user: users[0], position: 1, isCurrentUser: users[0].id == currentUserID) }
            // 3rd place
            if users.count > 2 { PodiumSlot(user: users[2], position: 3, isCurrentUser: users[2].id == currentUserID) }
        }
    }
}

struct PodiumSlot: View {
    let user: User
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
                Text(String(user.name.prefix(1)))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(user.name.components(separatedBy: " ").first ?? user.name)
                .font(G.label(11))
                .foregroundStyle(isCurrentUser ? G.caramel : G.cream)
                .lineLimit(1)

            HStack(spacing: 3) {
                Image(systemName: "map.fill").font(.system(size: 9)).foregroundStyle(G.muted)
                Text("\(user.weeklyShopsVisited)").font(G.mono(13)).fontWeight(.bold).foregroundStyle(G.latte)
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
    let user: User
    let isCurrentUser: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            Text("#\(rank)")
                .font(G.mono(13))
                .foregroundStyle(rank <= 3 ? G.gold : G.muted)
                .frame(width: 28)

            // Avatar + streak flame
            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: user.name, size: 40)
                if user.currentStreak >= 3 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .background(Circle().fill(G.espresso).frame(width: 16, height: 16))
                }
            }

            // Name + username
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(user.name)
                        .font(G.body(14)).fontWeight(isCurrentUser ? .bold : .semibold)
                        .foregroundStyle(isCurrentUser ? G.caramel : G.cream)
                    if isCurrentUser { Text("(you)").font(G.label(10)).foregroundStyle(G.caramel) }
                    if user.isPremium { ProBadge() }
                }
                HStack(spacing: 8) {
                    Label("\(user.currentStreak)d", systemImage: "flame.fill")
                        .font(G.label(10))
                        .foregroundStyle(user.currentStreak > 0 ? .orange : G.muted)
                    Label("\(user.weeklyPhotos) photos", systemImage: "camera.fill")
                        .font(G.label(10))
                        .foregroundStyle(G.muted)
                }
            }

            Spacer()

            // Weekly shops count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(user.weeklyShopsVisited)")
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
    let user: User
    let isCurrentUser: Bool

    var flameColor: Color {
        switch user.currentStreak {
        case 0:     return G.muted
        case 1...3: return .orange
        case 4...9: return .red
        default:    return .yellow
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)").font(G.mono(13)).foregroundStyle(rank == 1 ? G.gold : G.muted).frame(width: 28)
            AvatarView(name: user.name, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(user.name)
                        .font(G.body(14)).fontWeight(.semibold)
                        .foregroundStyle(isCurrentUser ? G.caramel : G.cream)
                    if isCurrentUser { Text("(you)").font(G.label(10)).foregroundStyle(G.caramel) }
                }
                Text("Best: \(user.longestStreak) days")
                    .font(G.label(10)).foregroundStyle(G.muted)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: user.currentStreak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 18))
                    .foregroundStyle(flameColor)
                Text("\(user.currentStreak)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(user.currentStreak > 0 ? G.cream : G.muted)
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
    let topUsers: [User]
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
                    Text("Supporting local, independent coffee shops")
                        .font(G.label(11)).foregroundStyle(G.sage)
                    Spacer()
                }

                ForEach(Array(topUsers.enumerated()), id: \.offset) { i, user in
                    HStack(spacing: 12) {
                        Text(["🥇","🥈","🥉"][i]).font(.system(size: 20))
                        AvatarView(name: user.name, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.name)
                                .font(G.body(13)).fontWeight(.semibold)
                                .foregroundStyle(user.id == currentUserID ? G.caramel : G.cream)
                            Text("\(user.smallBizVisits) indie shops visited")
                                .font(G.label(10)).foregroundStyle(G.muted)
                        }
                        Spacer()
                        // Small biz ratio bar
                        let ratio = user.visitedCount > 0
                            ? min(1.0, Double(user.smallBizVisits) / Double(user.visitedCount))
                            : 0
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(ratio * 100))%")
                                .font(G.mono(12)).fontWeight(.bold).foregroundStyle(G.sage)
                            Text("indie").font(G.label(9)).foregroundStyle(G.muted)
                        }
                    }
                    if i < topUsers.count - 1 {
                        Divider().background(G.sage.opacity(0.2))
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Photo Wall

struct PhotoWallSection: View {
    let users: [User]

    var activities: [(name: String, shop: String, time: String, photos: Int)] {
        [
            ("Sofia Lee",     "Devoción, Brooklyn",        "Just now",  8),
            ("Emma Wilson",   "Onyx Coffee Lab",           "14m ago",   5),
            ("Victoria",      "Sightglass, SF",            "2h ago",    3),
            ("Jake Rivera",   "Intelligentsia, Chicago",   "Yesterday", 2),
        ]
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(activities.prefix(users.count).enumerated()), id: \.offset) { i, item in
                let user = i < users.count ? users[i] : users[0]
                HStack(spacing: 12) {
                    AvatarView(name: user.name, size: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(user.name)
                                .font(G.body(13)).fontWeight(.semibold).foregroundStyle(G.cream)
                            Text("checked in")
                                .font(G.body(12)).foregroundStyle(G.muted)
                        }
                        Text(item.shop)
                            .font(G.label(11)).foregroundStyle(G.caramel)
                        Text(item.time)
                            .font(G.label(10)).foregroundStyle(G.muted)
                    }

                    Spacer()

                    // Photo count badge
                    HStack(spacing: 4) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(G.latte)
                        Text("\(item.photos)")
                            .font(G.mono(12)).fontWeight(.bold).foregroundStyle(G.cream)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(G.surface2)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(G.border, lineWidth: 1))
                }
                .padding(12)
                .background(G.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.border, lineWidth: 1))
            }
        }
    }
}
