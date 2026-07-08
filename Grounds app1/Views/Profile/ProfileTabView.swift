import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var auth: AuthService
    @State private var showSettings    = false
    @State private var showSubscription = false
    @State private var editBio         = false
    @State private var bioText         = ""

    var user: User { auth.currentUser }
    var checkIns: [CheckIn] { MockData.checkIns }

    var body: some View {
        NavigationStack {
            ZStack {
                G.espresso.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ── Profile header ────────────────────────────────────
                        VStack(spacing: 16) {
                            ZStack(alignment: .bottomTrailing) {
                                AvatarView(name: user.name, size: 90)
                                    .overlay(Circle().stroke(G.caramel, lineWidth: 2))
                                Button { } label: {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                        .padding(7)
                                        .background(G.caramelGrad)
                                        .clipShape(Circle())
                                }
                            }

                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(user.name).font(G.title(22)).foregroundStyle(G.cream)
                                    if user.isPremium { ProBadge() }
                                }
                                Text("@\(user.username)").font(G.body(14)).foregroundStyle(G.muted)

                                // Bio
                                if editBio {
                                    HStack {
                                        TextField("Bio...", text: $bioText)
                                            .textFieldStyle(GroundsFieldStyle())
                                        Button { editBio = false } label: {
                                            Text("Save").font(G.label(13)).foregroundStyle(G.caramel)
                                        }
                                    }
                                    .padding(.horizontal, 30)
                                } else {
                                    Button {
                                        bioText = user.bio
                                        editBio = true
                                    } label: {
                                        Text(user.bio.isEmpty ? "Add a bio..." : user.bio)
                                            .font(G.body(14))
                                            .foregroundStyle(user.bio.isEmpty ? G.muted : G.latte)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }

                            // Stats row
                            HStack(spacing: 0) {
                                ProfileStat(value: "\(user.checkInCount)", label: "Check-ins")
                                Divider().frame(height: 30).background(G.border)
                                ProfileStat(value: "\(user.visitedCount)", label: "Shops")
                                Divider().frame(height: 30).background(G.border)
                                ProfileStat(value: "\(user.reviewCount)", label: "Reviews")
                                Divider().frame(height: 30).background(G.border)
                                ProfileStat(value: "\(user.friendIDs.count)", label: "Friends")
                            }
                            .padding(.vertical, 8)
                            .background(G.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.border, lineWidth: 1))

                            // Score
                            HStack {
                                Image(systemName: "trophy.fill").foregroundStyle(G.gold)
                                Text("Score: ").font(G.body(14)).foregroundStyle(G.muted)
                                Text("\(user.score) pts").font(G.body(14)).fontWeight(.bold).foregroundStyle(G.gold)
                                Spacer()
                                Text("Rank #4").font(G.label(13)).foregroundStyle(G.latte)
                            }
                            .padding(12)
                            .background(G.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(G.border, lineWidth: 1))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // ── Badges ────────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Badges", subtitle: "\(user.badges.count)/\(Badge.all.count) earned")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Badge.all) { badge in
                                        BadgeView(badge: badge,
                                                  isEarned: user.badges.contains { $0.id == badge.id })
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // ── Check-in history ──────────────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader("Recent Check-ins", subtitle: "")
                                .padding(.horizontal, 20)
                            VStack(spacing: 8) {
                                ForEach(checkIns) { checkin in
                                    CheckInRow(checkin: checkin)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // ── Pro upsell ────────────────────────────────────────
                        if !user.isPremium {
                            ProUpsellBanner { showSubscription = true }
                                .padding(.horizontal, 20)
                        }

                        // ── Settings ──────────────────────────────────────────
                        VStack(spacing: 0) {
                            SettingsRow(icon: "bell.fill",      label: "Notifications", color: G.caramel)
                            SettingsRow(icon: "lock.fill",       label: "Privacy",       color: G.sage)
                            SettingsRow(icon: "questionmark.circle.fill", label: "Help & Feedback", color: G.latte)
                            Button {
                                auth.signOut()
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundStyle(.red)
                                    Text("Sign Out").font(G.body(15)).foregroundStyle(.red)
                                    Spacer()
                                }
                                .padding(16)
                                .background(G.surface)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.border, lineWidth: 1))
                        .padding(.horizontal, 20)

                        Color.clear.frame(height: 80)
                    }
                }
            }
            .sheet(isPresented: $showSubscription) { SubscriptionView() }
        }
    }
}

// MARK: - Sub-views
struct ProfileStat: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(G.title(18)).foregroundStyle(G.cream)
            Text(label).font(G.label(11)).foregroundStyle(G.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

struct BadgeView: View {
    let badge: Badge; let isEarned: Bool
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isEarned ? G.caramelGrad : LinearGradient(colors: [G.surface2], startPoint: .top, endPoint: .bottom))
                    .frame(width: 54, height: 54)
                    .overlay(Circle().stroke(isEarned ? G.caramel : G.border, lineWidth: 1.5))
                Image(systemName: badge.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isEarned ? .white : G.muted)
            }
            Text(badge.name).font(G.label(10)).foregroundStyle(isEarned ? G.latte : G.muted).lineLimit(1)
        }
        .frame(width: 70)
        .opacity(isEarned ? 1 : 0.4)
    }
}

struct CheckInRow: View {
    let checkin: CheckIn
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(G.caramel.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: "cup.and.saucer.fill").font(.system(size: 18)).foregroundStyle(G.caramel)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(checkin.shopName).font(G.body(14)).fontWeight(.semibold).foregroundStyle(G.cream)
                if let drink = checkin.drink {
                    Text(drink).font(G.label(12)).foregroundStyle(G.latte)
                }
                if let note = checkin.note {
                    Text(note).font(G.body(12)).foregroundStyle(G.muted).lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(checkin.timeAgo).font(G.label(11)).foregroundStyle(G.muted)
                Text("+\(checkin.pointsEarned)pts").font(G.label(11)).foregroundStyle(G.gold)
            }
        }
        .padding(12)
        .background(G.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(G.border, lineWidth: 1))
    }
}

struct SectionHeader: View {
    let title: String; let subtitle: String
    init(_ title: String, subtitle: String = "") { self.title = title; self.subtitle = subtitle }
    var body: some View {
        HStack {
            Text(title).font(G.body(16)).fontWeight(.semibold).foregroundStyle(G.cream)
            Spacer()
            if !subtitle.isEmpty {
                Text(subtitle).font(G.label(12)).foregroundStyle(G.muted)
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String; let label: String; let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 22)
            Text(label).font(G.body(15)).foregroundStyle(G.cream)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(G.muted)
        }
        .padding(16)
        .background(G.surface)
    }
}

struct ProUpsellBanner: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(G.gold2).frame(width: 48, height: 48)
                    Image(systemName: "crown.fill").font(.system(size: 20)).foregroundStyle(G.espresso)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Upgrade to Grounds Pro").font(G.body(14)).fontWeight(.semibold).foregroundStyle(G.cream)
                    Text("Videos, unlimited check-ins, exclusive badges").font(G.label(11)).foregroundStyle(G.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(G.muted)
            }
            .padding(14)
            .background(G.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.gold.opacity(0.4), lineWidth: 1))
        }
    }
}
