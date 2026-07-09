import SwiftUI
import PhotosUI

struct ProfileTabView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var community: CommunityService
    @EnvironmentObject var social: SocialService
    @State private var showSubscription = false
    @State private var editBio         = false
    @State private var bioText         = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var myCheckIns: [CommunityCheckIn] = []
    @State private var isLoadingActivity = false

    var user: User { auth.currentUser }

    /// Distinct visited shops, most-recent-first, deduped by shopID — this is what
    /// becomes the stamp card. Real data only: no shop appears here without an
    /// actual CheckIn record behind it.
    private var visitedShops: [(shopID: String, shopName: String)] {
        var seen = Set<String>()
        var result: [(String, String)] = []
        for checkIn in myCheckIns where !checkIn.shopID.isEmpty {
            if seen.insert(checkIn.shopID).inserted {
                result.append((checkIn.shopID, checkIn.shopName))
            }
        }
        return result
    }

    private func loadAvatarFromDisk() {
        guard let path = user.avatarURL, avatarImage == nil,
              let image = UIImage(contentsOfFile: path) else { return }
        avatarImage = image
    }

    private func saveAvatar(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("avatar_\(user.id).jpg")
        do {
            try data.write(to: url)
            avatarImage = image
            auth.updateAvatarURL(url.path)
        } catch {
            print("[Grounds] Failed to save avatar: \(error.localizedDescription)")
        }
    }

    private func loadActivity() async {
        isLoadingActivity = true
        myCheckIns = await community.fetchCheckIns(forUserID: user.id)
        isLoadingActivity = false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                G.parchment.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {

                        // ── Identity ────────────────────────────────────────────
                        VStack(spacing: 14) {
                            ZStack(alignment: .bottomTrailing) {
                                if let avatarImage {
                                    Image(uiImage: avatarImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 84, height: 84)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(G.stampRed, lineWidth: 2))
                                } else {
                                    ZStack {
                                        Circle().fill(G.kraft)
                                        Text(String(user.name.prefix(1)).uppercased())
                                            .font(G.serif(30, weight: .bold))
                                            .foregroundStyle(G.darkRoast)
                                    }
                                    .frame(width: 84, height: 84)
                                    .overlay(Circle().stroke(G.stampRed, lineWidth: 2))
                                }
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(G.parchment)
                                        .padding(6)
                                        .background(G.darkRoast)
                                        .clipShape(Circle())
                                }
                            }

                            VStack(spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(user.name)
                                        .font(G.serif(22, weight: .bold))
                                        .foregroundStyle(G.darkRoast)
                                    if user.isPremium { PaperProBadge() }
                                }
                                Text("@\(user.username)")
                                    .font(G.mono(13))
                                    .foregroundStyle(G.lightRoast)

                                if editBio {
                                    HStack(spacing: 8) {
                                        TextField("Add a bio…", text: $bioText)
                                            .font(G.sans(14))
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(G.kraft)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        Button {
                                            auth.updateBio(bioText)
                                            editBio = false
                                            Task {
                                                await social.upsertProfile(
                                                    userID: user.id, username: user.username,
                                                    name: user.name, bio: bioText
                                                )
                                            }
                                        } label: {
                                            Text("Save").font(G.sans(13, weight: .semibold)).foregroundStyle(G.stampRed)
                                        }
                                    }
                                    .padding(.horizontal, 30)
                                    .padding(.top, 4)
                                } else {
                                    Button {
                                        bioText = user.bio
                                        editBio = true
                                    } label: {
                                        Text(user.bio.isEmpty ? "Add a bio…" : user.bio)
                                            .font(G.sans(14))
                                            .foregroundStyle(user.bio.isEmpty ? G.lightRoast : G.darkRoast.opacity(0.8))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 30)
                                    }
                                }
                            }
                        }
                        .padding(.top, 16)

                        // ── Recent activity ──────────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            PaperSectionHeader("RECENT ACTIVITY")

                            if isLoadingActivity && myCheckIns.isEmpty {
                                ProgressView().tint(G.lightRoast).frame(maxWidth: .infinity).padding(.vertical, 24)
                            } else if myCheckIns.isEmpty {
                                PaperEmptyRow(text: "No check-ins yet — visit a shop and check in to start your activity feed.")
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(myCheckIns.prefix(6)) { checkIn in
                                        ActivityRow(checkIn: checkIn)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // ── Stamp card ────────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            PaperSectionHeader("STAMP CARD", subtitle: "\(visitedShops.count) shops")

                            if visitedShops.isEmpty {
                                PaperEmptyRow(text: "Your first check-in earns your first stamp.")
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 14)], spacing: 16) {
                                    ForEach(visitedShops, id: \.shopID) { shop in
                                        VStack(spacing: 6) {
                                            StampMark(
                                                symbol: String(shop.shopName.prefix(1)).uppercased(),
                                                rotation: Double.random(in: -12...12)
                                            )
                                            Text(shop.shopName)
                                                .font(G.mono(9))
                                                .foregroundStyle(G.lightRoast)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // ── Pro upsell ────────────────────────────────────────────
                        if !user.isPremium {
                            PaperProUpsellBanner { showSubscription = true }
                                .padding(.horizontal, 20)
                        }

                        // ── Settings ──────────────────────────────────────────────
                        VStack(spacing: 0) {
                            PaperSettingsRow(icon: "bell.fill", label: "Notifications")
                            PaperSettingsRow(icon: "lock.fill", label: "Privacy")
                            PaperSettingsRow(icon: "questionmark.circle.fill", label: "Help & Feedback")
                            Button {
                                auth.signOut()
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .foregroundStyle(G.stampRed)
                                    Text("Sign Out").font(G.sans(15)).foregroundStyle(G.stampRed)
                                    Spacer()
                                }
                                .padding(16)
                                .background(G.kraft)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.kraftLine, lineWidth: 1))
                        .padding(.horizontal, 20)

                        Color.clear.frame(height: 80)
                    }
                }
            }
            .sheet(isPresented: $showSubscription) { SubscriptionView() }
        }
        .onAppear { loadAvatarFromDisk() }
        .task { await loadActivity() }
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    saveAvatar(image)
                }
            }
        }
    }
}

// MARK: - Sub-views (paper palette)

struct PaperProBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill").font(.system(size: 8))
            Text("PRO").font(G.mono(9))
        }
        .foregroundStyle(G.parchment)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(G.stampRed)
        .clipShape(Capsule())
    }
}

struct PaperSectionHeader: View {
    let title: String
    var subtitle: String = ""
    init(_ title: String, subtitle: String = "") { self.title = title; self.subtitle = subtitle }
    var body: some View {
        HStack {
            Text(title)
                .font(G.mono(11))
                .tracking(0.5)
                .foregroundStyle(G.lightRoast)
            Spacer()
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(G.mono(11))
                    .foregroundStyle(G.lightRoast)
            }
        }
    }
}

struct PaperEmptyRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(G.sans(13))
            .foregroundStyle(G.lightRoast)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(G.kraft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(G.kraftLine, lineWidth: 1))
    }
}

struct ActivityRow: View {
    let checkIn: CommunityCheckIn
    var body: some View {
        HStack(spacing: 12) {
            if let url = checkIn.photoURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        Color(G.kraftLine)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(G.kraft)
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(G.lightRoast)
                }
                .frame(width: 44, height: 44)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(checkIn.shopName)
                    .font(G.sans(14, weight: .semibold))
                    .foregroundStyle(G.darkRoast)
                if let caption = checkIn.caption, !caption.isEmpty {
                    Text(caption)
                        .font(G.sans(12))
                        .foregroundStyle(G.lightRoast)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(checkIn.timestamp.formatted(.relative(presentation: .named)))
                .font(G.mono(10))
                .foregroundStyle(G.lightRoast)
        }
        .padding(12)
        .background(G.kraft)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(G.kraftLine, lineWidth: 1))
    }
}

struct PaperSettingsRow: View {
    let icon: String
    let label: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(G.stampRed).frame(width: 22)
            Text(label).font(G.sans(15)).foregroundStyle(G.darkRoast)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(G.lightRoast)
        }
        .padding(16)
        .background(G.kraft)
    }
}

struct PaperProUpsellBanner: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(G.darkRoast).frame(width: 46, height: 46)
                    Image(systemName: "crown.fill").font(.system(size: 18)).foregroundStyle(G.parchment)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Upgrade to Grounds Pro")
                        .font(G.sans(14, weight: .semibold))
                        .foregroundStyle(G.darkRoast)
                    Text("Unlimited check-ins, photo & video reviews")
                        .font(G.sans(11))
                        .foregroundStyle(G.lightRoast)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(G.lightRoast)
            }
            .padding(14)
            .background(G.kraft)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.stampRed.opacity(0.35), lineWidth: 1))
        }
    }
}
