import SwiftUI

struct SocialTabView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var social: SocialService
    @State private var tab = 0
    @State private var showAddFriend = false

    var body: some View {
        ZStack {
            G.parchment.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────────
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Brew League")
                            .font(G.serif(24, weight: .bold))
                            .foregroundStyle(G.darkRoast)
                        Text("Compete. Explore. Discover.")
                            .font(G.sans(11))
                            .foregroundStyle(G.lightRoast)
                    }
                    Spacer()
                    Button { showAddFriend = true } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 20))
                            .foregroundStyle(G.stampRed)
                            .padding(10)
                            .background(G.kraft)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(G.kraftLine, lineWidth: 1))
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
                .background(G.parchment)

                // ── Tab Content ───────────────────────────────────────────────
                ZStack {
                    switch tab {
                    case 0: BrewLeagueView()
                    case 1: BattlesView()
                    case 2: FriendsSection()
                    default: ActivitySection()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showAddFriend) { AddFriendView() }
        .task { await social.fetchFriendsAndRequests(myID: auth.currentUser.id) }
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
                    .foregroundStyle(isSelected ? G.parchment : G.lightRoast)
                Text(title)
                    .font(G.sans(10, weight: .medium))
                    .foregroundStyle(isSelected ? G.parchment : G.lightRoast)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(isSelected ? G.stampRed : G.kraft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.clear : G.kraftLine, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Friends Tab

struct FriendsSection: View {
    @EnvironmentObject var social: SocialService
    @EnvironmentObject var community: CommunityService

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                if !social.incomingRequests.isEmpty {
                    Text("FRIEND REQUESTS")
                        .font(G.mono(11)).foregroundStyle(G.lightRoast)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(social.incomingRequests) { request in
                        FriendRequestRow(request: request)
                    }
                    Text("FRIENDS")
                        .font(G.mono(11)).foregroundStyle(G.lightRoast)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                }

                if social.friends.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2").font(.system(size: 30)).foregroundStyle(G.lightRoast)
                        Text("No friends yet").font(G.sans(14)).foregroundStyle(G.lightRoast)
                        Text("Tap the + above to find people on Grounds").font(G.sans(11)).foregroundStyle(G.lightRoast.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    ForEach(social.friends) { friend in
                        FriendRow(profile: friend, entry: community.leaderboard.first(where: { $0.id == friend.id }))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .task { await community.fetchLeaderboard() }
    }
}

struct FriendRequestRow: View {
    @EnvironmentObject var social: SocialService
    let request: FriendRequestRecord
    @State private var responded = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(G.parchment)
                Text(String(request.fromUserName.prefix(1)).uppercased())
                    .font(G.serif(15, weight: .bold)).foregroundStyle(G.darkRoast)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromUserName).font(G.sans(14, weight: .semibold)).foregroundStyle(G.darkRoast)
                Text("@\(request.fromUsername)").font(G.mono(11)).foregroundStyle(G.lightRoast)
            }
            Spacer()
            if responded {
                Text("Done").font(G.sans(12, weight: .medium)).foregroundStyle(G.sage)
            } else {
                Button {
                    responded = true
                    Task { await social.respondToFriendRequest(request, accept: false) }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(G.lightRoast).padding(8).background(G.parchment).clipShape(Circle())
                }
                Button {
                    responded = true
                    Task { await social.respondToFriendRequest(request, accept: true) }
                } label: {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(G.parchment).padding(8).background(G.stampRed).clipShape(Circle())
                }
            }
        }
        .padding(12)
        .background(G.kraft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.stampRed.opacity(0.35), lineWidth: 1))
    }
}

struct FriendRow: View {
    let profile: GroundsUserProfile
    let entry: CommunityLeaderboardEntry?

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle().fill(G.parchment)
                    Text(String(profile.name.prefix(1)).uppercased())
                        .font(G.serif(18, weight: .bold)).foregroundStyle(G.darkRoast)
                }
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(G.kraftLine, lineWidth: 1))

                if let streak = entry?.currentStreak, streak >= 3 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(G.stampRed)
                        .background(Circle().fill(G.kraft).frame(width: 18, height: 18))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name).font(G.sans(15, weight: .semibold)).foregroundStyle(G.darkRoast)
                Text("@\(profile.username)").font(G.mono(12)).foregroundStyle(G.lightRoast)
                HStack(spacing: 10) {
                    Label("\(entry?.weeklyShopsVisited ?? 0) this week", systemImage: "map.fill")
                    if let streak = entry?.currentStreak, streak > 0 {
                        Label("\(streak)d streak", systemImage: "flame.fill")
                            .foregroundStyle(G.stampRed)
                    }
                }
                .font(G.sans(10, weight: .medium))
                .foregroundStyle(G.lightRoast)
            }
            Spacer()
        }
        .padding(12)
        .background(G.kraft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.kraftLine, lineWidth: 1))
    }
}

// MARK: - Activity Tab

struct ActivitySection: View {
    @EnvironmentObject var community: CommunityService

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                if community.isLoading && community.recentCheckIns.isEmpty {
                    ProgressView()
                        .tint(G.lightRoast)
                        .padding(.top, 60)
                } else if community.recentCheckIns.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 30)).foregroundStyle(G.lightRoast)
                        Text("No check-ins yet")
                            .font(G.sans(14)).foregroundStyle(G.lightRoast)
                        Text("Be the first to check in and share a photo")
                            .font(G.sans(11)).foregroundStyle(G.lightRoast.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    ForEach(community.recentCheckIns) { checkIn in
                        HStack(spacing: 12) {
                            if let url = checkIn.photoURL {
                                AsyncImage(url: url) { phase in
                                    if case .success(let img) = phase {
                                        img.resizable().scaledToFill()
                                    } else {
                                        Circle().fill(G.kraftLine)
                                    }
                                }
                                .frame(width: 42, height: 42)
                                .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle().fill(G.kraftLine).frame(width: 42, height: 42)
                                    Image(systemName: "mappin.circle.fill").font(.system(size: 16)).foregroundStyle(G.stampRed)
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(checkIn.userName) checked in at \(checkIn.shopName)")
                                    .font(G.sans(13)).foregroundStyle(G.darkRoast).lineLimit(2)
                                if let caption = checkIn.caption, !caption.isEmpty {
                                    Text(caption)
                                        .font(G.sans(10)).foregroundStyle(G.lightRoast)
                                }
                            }
                            Spacer()
                            Text(checkIn.timestamp.formatted(.relative(presentation: .named)))
                                .font(G.mono(10)).foregroundStyle(G.lightRoast)
                        }
                        .padding(12)
                        .background(G.kraft)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(G.kraftLine, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .task { await community.fetchRecentCheckIns() }
    }
}

// MARK: - Helpers

struct AddFriendView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var social: SocialService
    @State private var search = ""
    @State private var sentTo: Set<String> = []

    var body: some View {
        ZStack {
            G.parchment.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Find Friends").font(G.serif(22, weight: .bold)).foregroundStyle(G.darkRoast).padding(.top, 20)
                TextField("Search by @username", text: $search)
                    .font(G.sans(15))
                    .foregroundStyle(G.darkRoast)
                    .padding(14)
                    .background(G.kraft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(G.kraftLine, lineWidth: 1))
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal, 20)
                    .onChange(of: search) { query in
                        Task { await social.searchUsers(query: query, excludingUserID: auth.currentUser.id) }
                    }

                if let error = social.errorMessage {
                    Text(error).font(G.sans(11)).foregroundStyle(.red).padding(.horizontal, 20)
                }

                if search.count >= 2 && social.searchResults.isEmpty {
                    Text("No users found").font(G.sans(13)).foregroundStyle(G.lightRoast)
                }

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(social.searchResults) { result in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(G.parchment)
                                    Text(String(result.name.prefix(1)).uppercased())
                                        .font(G.serif(15, weight: .bold)).foregroundStyle(G.darkRoast)
                                }
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(G.kraftLine, lineWidth: 1))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name).font(G.sans(14, weight: .semibold)).foregroundStyle(G.darkRoast)
                                    Text("@\(result.username)").font(G.mono(11)).foregroundStyle(G.lightRoast)
                                }
                                Spacer()
                                if sentTo.contains(result.id) {
                                    Text("Sent").font(G.sans(12, weight: .medium)).foregroundStyle(G.sage)
                                } else {
                                    Button {
                                        sentTo.insert(result.id)
                                        let me = GroundsUserProfile(
                                            id: auth.currentUser.id, username: auth.currentUser.username,
                                            name: auth.currentUser.name, bio: auth.currentUser.bio
                                        )
                                        Task { await social.sendFriendRequest(from: me, to: result) }
                                    } label: {
                                        Text("Add").font(G.sans(12, weight: .bold))
                                            .foregroundStyle(G.parchment)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(G.stampRed)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(12)
                            .background(G.kraft)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
                Button { dismiss() } label: {
                    Text("Done")
                        .font(G.sans(16, weight: .semibold))
                        .foregroundStyle(G.parchment)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(G.stampRed)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
    }
}
