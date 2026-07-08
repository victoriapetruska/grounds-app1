import SwiftUI
import MapKit

struct ShopDetailView: View {
    let shop: CoffeeShop
    @ObservedObject var vm: MapViewModel
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var showCheckIn = false
    @State private var showWriteReview = false
    @State private var showSubscription = false
    @State private var didCheckIn = false

    var reviews: [Review] { MockData.reviews(for: shop.id) }
    var hasVisited: Bool { auth.currentUser.visitedShopIDs.contains(shop.id) }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Hero photo ────────────────────────────────────────────
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(G.brown.opacity(0.4))
                            .frame(height: 240)
                            .overlay(
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(G.caramel.opacity(0.3))
                            )

                        // Close + favorite
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(G.cream)
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            Spacer()
                            Button {
                                vm.toggleFavorite(shop.id)
                            } label: {
                                Image(systemName: shop.isFavorited ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundStyle(shop.isFavorited ? .red : G.cream)
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }
                        .padding(16)
                        .padding(.top, 44)
                    }

                    // ── Info ──────────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 16) {

                        // Name + rating
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(shop.name)
                                    .font(G.title(24))
                                    .foregroundStyle(G.cream)
                                HStack(spacing: 6) {
                                    StarRow(rating: shop.rating)
                                    Text("(\(shop.reviewCount))")
                                        .font(G.body(12))
                                        .foregroundStyle(G.muted)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(shop.priceString)
                                    .font(G.title(18))
                                    .foregroundStyle(G.latte)
                                Text(shop.isOpenNow ? "Open Now" : "Closed")
                                    .font(G.label(12))
                                    .foregroundStyle(shop.isOpenNow ? G.sage : .red)
                            }
                        }

                        // Tags
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(shop.tags, id: \.self) { tag in
                                    TagChip(label: tag.capitalized,
                                            icon: iconFor(tag: tag))
                                }
                            }
                        }

                        // Quick stats
                        HStack(spacing: 0) {
                            StatPill(value: "\(shop.checkInCount)", label: "Check-ins", icon: "mappin.circle.fill")
                            Divider().frame(height: 32).background(G.border)
                            StatPill(value: "\(shop.reviewCount)", label: "Reviews", icon: "star.fill")
                            Divider().frame(height: 32).background(G.border)
                            StatPill(value: shop.todayHours, label: "Today", icon: "clock.fill")
                        }
                        .background(G.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.border, lineWidth: 1))

                        // Address
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.fill")
                                .foregroundStyle(G.caramel)
                            Text(shop.address)
                                .font(G.body(14))
                                .foregroundStyle(G.latte)
                        }

                        // Action buttons
                        HStack(spacing: 10) {
                            GButton("Directions", icon: "arrow.triangle.turn.up.right.diamond.fill",
                                    style: .outline) {
                                openDirections()
                            }
                            GButton(didCheckIn ? "Checked In ✓" : "Check In",
                                    icon: didCheckIn ? nil : "mappin.and.ellipse",
                                    style: didCheckIn ? .ghost : .gold) {
                                if !didCheckIn {
                                    vm.checkIn(to: shop)
                                    didCheckIn = true
                                    showCheckIn = true
                                }
                            }
                        }

                        // ── Tabs ──────────────────────────────────────────────
                        Picker("", selection: $selectedTab) {
                            Text("Reviews").tag(0)
                            Text("Photos").tag(1)
                            Text("Info").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)

                        // Tab content
                        Group {
                            switch selectedTab {
                            case 0: ReviewsTab(reviews: reviews, onWrite: { showWriteReview = true })
                            case 1: PhotosTab(shop: shop, onPro: { showSubscription = true }, isPremium: auth.currentUser.isPremium)
                            default: InfoTab(shop: shop)
                            }
                        }
                    }
                    .padding(20)
                    .background(G.espresso)
                }
            }
            .background(G.espresso)
            .ignoresSafeArea(edges: .top)

            // ── Write review button ───────────────────────────────────────────
            if selectedTab == 0 {
                Button {
                    hasVisited ? (showWriteReview = true) : (showSubscription = !auth.currentUser.isPremium)
                } label: {
                    Label("Write a Review", systemImage: "pencil")
                        .font(G.body(15)).fontWeight(.semibold)
                        .foregroundStyle(G.espresso)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(G.gold2)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 34)
                        .background(G.espresso.opacity(0.95))
                }
            }
        }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewView(shop: shop)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showCheckIn) {
            CheckInConfirmView(shop: shop)
        }
        .preferredColorScheme(.dark)
    }

    func openDirections() {
        let mapItem = shop.mapItem
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    func iconFor(tag: String) -> String? {
        let map = ["wifi":"wifi","dog-friendly":"pawprint.fill","outdoor":"leaf.fill",
                   "specialty":"flask.fill","pour-over":"drop.fill","cold-brew":"snowflake",
                   "espresso":"bolt.fill","cozy":"house.fill"]
        return map[tag]
    }
}

// MARK: - Sub-views
struct StatPill: View {
    let value: String; let label: String; let icon: String
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(G.caramel)
            Text(value).font(G.body(12)).fontWeight(.semibold).foregroundStyle(G.cream).lineLimit(1)
            Text(label).font(G.label(10)).foregroundStyle(G.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

struct ReviewsTab: View {
    let reviews: [Review]
    let onWrite: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            if reviews.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "star").font(.system(size: 32)).foregroundStyle(G.muted)
                    Text("No reviews yet").font(G.body(14)).foregroundStyle(G.muted)
                    Text("Be the first to leave one!").font(G.body(12)).foregroundStyle(G.muted.opacity(0.7))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                ForEach(reviews) { review in ReviewCard(review: review) }
            }
        }
    }
}

struct ReviewCard: View {
    let review: Review
    @State private var liked = false
    var body: some View {
        GCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    AvatarView(name: review.userName, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(review.userName).font(G.body(14)).fontWeight(.semibold).foregroundStyle(G.cream)
                            if review.isVerifiedVisit {
                                Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(G.sage)
                            }
                        }
                        Text(review.timeAgo).font(G.label(11)).foregroundStyle(G.muted)
                    }
                    Spacer()
                    StarRow(rating: review.rating, size: 11)
                }
                if !review.title.isEmpty {
                    Text(review.title).font(G.body(14)).fontWeight(.semibold).foregroundStyle(G.cream)
                }
                Text(review.body).font(G.body(13)).foregroundStyle(G.latte).lineLimit(4)
                HStack {
                    Spacer()
                    Button {
                        liked.toggle()
                    } label: {
                        Label("\(review.likes + (liked ? 1 : 0))", systemImage: liked ? "heart.fill" : "heart")
                            .font(G.label(12))
                            .foregroundStyle(liked ? .red : G.muted)
                    }
                }
            }
        }
    }
}

struct PhotosTab: View {
    let shop: CoffeeShop
    let onPro: () -> Void
    let isPremium: Bool
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<max(6, shop.photos.count), id: \.self) { i in
                    ZStack {
                        if i < shop.photos.count, let url = URL(string: shop.photos[i]) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable()
                                       .scaledToFill()
                                       .frame(height: 100)
                                       .clipShape(RoundedRectangle(cornerRadius: 10))
                                case .failure:
                                    photoPlaceholder
                                default:
                                    photoPlaceholder
                                        .overlay(ProgressView().tint(G.muted))
                                }
                            }
                        } else {
                            photoPlaceholder
                        }

                        // Pro lock overlay for photos 4+
                        if i >= 3 && !isPremium {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.black.opacity(0.72))
                            Image(systemName: "lock.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(G.gold)
                        }
                    }
                    .frame(height: 100)
                    .onTapGesture { if i >= 3 && !isPremium { onPro() } }
                }
            }

            if shop.photos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32)).foregroundStyle(G.muted)
                    Text("No photos yet")
                        .font(G.body(14)).foregroundStyle(G.muted)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 32)
            }

            if !isPremium {
                Text("Unlock all photos & video reviews with Grounds Pro")
                    .font(G.body(13)).foregroundStyle(G.muted)
                    .multilineTextAlignment(.center).padding(.top, 4)
                GButton("Unlock Pro", icon: "crown.fill", style: .gold, action: onPro)
            }
        }
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(G.brown.opacity(0.3))
            .overlay(Image(systemName: "photo").foregroundStyle(G.muted))
    }
}

struct InfoTab: View {
    let shop: CoffeeShop

    var body: some View {
        VStack(spacing: 16) {

            // ── Contact ────────────────────────────────────────────────────────
            if shop.phoneNumber != nil || shop.website != nil {
                GCard(padding: 14) {
                    VStack(spacing: 0) {
                        if let phone = shop.phoneNumber {
                            InfoRow(icon: "phone.fill", color: G.sage, label: phone) {
                                if let url = URL(string: "tel:\(phone.filter { $0.isNumber })") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        if shop.phoneNumber != nil && shop.website != nil {
                            Divider().background(G.border)
                        }
                        if let web = shop.website {
                            let display = web.replacingOccurrences(of: "https://", with: "")
                                            .replacingOccurrences(of: "http://", with: "")
                                            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                            InfoRow(icon: "globe", color: G.caramel, label: display) {
                                if let url = URL(string: web) { UIApplication.shared.open(url) }
                            }
                        }
                    }
                }
            }

            // ── Hours ──────────────────────────────────────────────────────────
            GCard(padding: 14) {
                VStack(spacing: 0) {
                    let days = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
                    let today = days[max(0, Calendar.current.component(.weekday, from: Date()) - 2)]

                    ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                        let isToday  = day == today
                        let hoursStr = shop.hours[day] ?? "Hours unavailable"

                        HStack {
                            Text(day)
                                .font(G.body(13))
                                .fontWeight(isToday ? .semibold : .regular)
                                .foregroundStyle(isToday ? G.cream : G.latte)
                            Spacer()
                            Text(hoursStr)
                                .font(G.body(13))
                                .foregroundStyle(isToday ? G.caramel : G.muted)
                        }
                        .padding(.vertical, 9)

                        if i < days.count - 1 {
                            Divider().background(G.border)
                        }
                    }
                }
            }
        }
    }
}

struct InfoRow: View {
    let icon: String
    let color: Color
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
                }
                Text(label)
                    .font(G.body(13))
                    .foregroundStyle(G.latte)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(G.muted)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

struct CheckInConfirmView: View {
    let shop: CoffeeShop
    @Environment(\.dismiss) var dismiss
    var body: some View {
        ZStack {
            G.espresso.ignoresSafeArea()
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(G.caramelGrad).frame(width: 90, height: 90)
                    Image(systemName: "checkmark").font(.system(size: 36, weight: .bold)).foregroundStyle(.white)
                }
                Text("Checked In!").font(G.title(28)).foregroundStyle(G.cream)
                Text(shop.name).font(G.body(18)).foregroundStyle(G.latte)
                Text("+10 points earned").font(G.label(14)).foregroundStyle(G.gold)
                GButton("Done") { dismiss() }
                    .padding(.horizontal, 40)
            }
        }
        .presentationDetents([.height(320)])
    }
}
