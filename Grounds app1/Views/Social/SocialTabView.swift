import SwiftUI

struct SocialTabView: View {
    @EnvironmentObject var auth: AuthService
    @State private var tab = 0
    @State private var showAddFriend = false

    var body: some View {
        ZStack {
            G.espresso.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────────
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Brew League")
                            .font(G.title(26))
                            .foregroundStyle(G.cream)
                        Text("Compete. Explore. Discover.")
                            .font(G.label(11))
                            .foregroundStyle(G.muted)
                    }
                    Spacer()
                    Button { showAddFriend = true } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20))
                            .foregroundStyle(G.latte)
                            .padding(10)
                            .background(G.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(G.border, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 14)

                // ── Tab Switcher ──────────────────────────────────────────────
                HStack(spacing: 6) {
                    SocialTabButton(title: "League",   icon: "trophy.fill",   isSelected: tab == 0) { tab = 0 }
                    SocialTabButton(title: "Battles",  icon: "bolt.fill",     isSelected: tab == 1) { tab = 1 }
                    SocialTabButton(title: "Friends",  icon: "person.2.fill", isSelected: tab == 2) { tab = 2 }
                    SocialTabButton(title: "Activity", icon: "bell.fill",     isSelected: tab == 3) { tab = 3 }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                // ── Tab Content ───────────────────────────────────────────────
                ZStack {
                    switch tab {
                    case 0: BrewLeagueView()
                    case 1: BattlesView()
                    case 2: FriendsSection(friends: MockData.friends)
                    default: ActivitySection()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showAddFriend) { AddFriendView() }
    }
}

// MARK: - Tab Button

struct SocialTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? G.espresso : G.muted)
                Text(title)
                    .font(G.label(10))
                    .foregroundStyle(isSelected ? G.espresso : G.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isSelected ? G.caramelGrad : LinearGradient(colors: [G.surface], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.clear : G.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Friends Tab

struct FriendsSection: View {
    let friends: [User]
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(friends) { friend in FriendRow(user: friend) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

struct FriendRow: View {
    let user: User
    @State private var followed = true
    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: user.name, size: 48)
                if user.currentStreak >= 3 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                        .background(Circle().fill(G.espresso).frame(width: 18, height: 18))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.name).font(G.body(15)).fontWeight(.semibold).foregroundStyle(G.cream)
                    if user.isPremium { ProBadge() }
                }
                Text("@\(user.username)").font(G.label(12)).foregroundStyle(G.muted)
                HStack(spacing: 10) {
                    Label("\(user.weeklyShopsVisited) this week", systemImage: "map.fill")
                    if user.currentStreak > 0 {
                        Label("\(user.currentStreak)d streak", systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(G.label(10))
                .foregroundStyle(G.latte)
            }
            Spacer()
            Button { followed.toggle() } label: {
                Text(followed ? "Following" : "Follow")
                    .font(G.label(12))
                    .foregroundStyle(followed ? G.muted : G.espresso)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(followed ? AnyShapeStyle(G.surface2) : AnyShapeStyle(G.caramelGrad))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(G.border, lineWidth: followed ? 1 : 0))
            }
        }
        .padding(12)
        .background(G.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.border, lineWidth: 1))
    }
}

// MARK: - Activity Tab

struct ActivitySection: View {
    var activities: [(icon: String, color: Color, text: String, time: String, extra: String)] = [
        ("flame.fill",         .orange,   "Sofia is on a 22-day streak! 🔥",           "Just now",  ""),
        ("bolt.fill",          G.caramel, "Emma accepted your Battle challenge",        "5m ago",    "Most Shops · 1 Week"),
        ("mappin.circle.fill", G.caramel, "Emma checked in at Onyx Coffee Lab",         "12m ago",   "+1 weekly shop"),
        ("camera.fill",        G.latte,   "Jake posted 2 photos at La Colombe",         "28m ago",   "+2 photos"),
        ("trophy.fill",        G.gold,    "You moved up to #2 in this week's race!",    "1h ago",    "↑1 position"),
        ("storefront.fill",    G.sage,    "Sofia visited her 89th indie coffee shop",   "3h ago",    "Small Biz Champion"),
        ("star.fill",          G.gold,    "Marcus left a review at Intelligentsia",     "5h ago",    ""),
        ("person.badge.plus",  G.caramel, "Jake is now following you",                  "Yesterday", ""),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(activities.indices, id: \.self) { i in
                    let a = activities[i]
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(a.color.opacity(0.18)).frame(width: 42, height: 42)
                            Image(systemName: a.icon).font(.system(size: 16)).foregroundStyle(a.color)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(a.text)
                                .font(G.body(13)).foregroundStyle(G.latte).lineLimit(2)
                            if !a.extra.isEmpty {
                                Text(a.extra)
                                    .font(G.label(10)).foregroundStyle(G.muted)
                            }
                        }
                        Spacer()
                        Text(a.time).font(G.label(10)).foregroundStyle(G.muted)
                    }
                    .padding(12)
                    .background(G.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(G.border, lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Helpers

struct AddFriendView: View {
    @Environment(\.dismiss) var dismiss
    @State private var search = ""
    var body: some View {
        ZStack {
            G.espresso.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Find Friends").font(G.title(22)).foregroundStyle(G.cream).padding(.top, 20)
                TextField("Search by name or @username", text: $search)
                    .textFieldStyle(GroundsFieldStyle())
                    .padding(.horizontal, 20)
                Text("Invite friends via link coming soon")
                    .font(G.body(13)).foregroundStyle(G.muted)
                Spacer()
                GButton("Done") { dismiss() }.padding(.horizontal, 40).padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium])
    }
}
