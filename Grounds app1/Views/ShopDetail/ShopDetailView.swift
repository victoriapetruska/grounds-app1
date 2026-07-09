import SwiftUI
import MapKit
import CoreLocation
import PhotosUI

struct ShopDetailView: View {
    let initialShop: CoffeeShop
    @ObservedObject var vm: MapViewModel
    let userLocation: CLLocation?

    /// Tracks vm.selectedShop live so async enrichment (fuller photo set, hours, phone)
    /// reaches the already-presented sheet instead of being stuck on the initial snapshot.
    private var shop: CoffeeShop {
        vm.selectedShop?.id == initialShop.id ? (vm.selectedShop ?? initialShop) : initialShop
    }
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var community: CommunityService
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @State private var showCheckIn = false
    @State private var showWriteReview = false
    @State private var showSubscription = false
    @State private var didCheckIn = false
    @State private var checkInBlockedMessage: String?
    @State private var realCheckInCount = 0

    /// Must be within this distance of the shop to check in — prevents faking a visit for leaderboard points.
    static let maxCheckInDistanceMeters: CLLocationDistance = 150

    var reviews: [Review] { shop.placeID != nil ? vm.currentShopReviews : MockData.reviews(for: shop.id) }
    var hasVisited: Bool { auth.currentUser.visitedShopIDs.contains(shop.id) }

    private func loadRealData() async {
        realCheckInCount = await community.checkInCount(forShopID: shop.id)
    }

    private func attemptCheckIn() {
        guard let userLocation else {
            checkInBlockedMessage = "Turn on Location Services to check in here."
            return
        }
        let shopLocation = CLLocation(latitude: shop.latitude, longitude: shop.longitude)
        let distance = userLocation.distance(from: shopLocation)
        guard distance <= Self.maxCheckInDistanceMeters else {
            checkInBlockedMessage = "You need to be at \(shop.name) to check in. Get closer and try again."
            return
        }
        vm.checkIn(to: shop)
        didCheckIn = true
        showCheckIn = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Hero photo ────────────────────────────────────────────
                    ZStack(alignment: .topLeading) {
                        heroPhoto

                        // Close + favorite
                        HStack {
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(G.darkRoast)
                                    .padding(10)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                            Spacer()
                            Button {
                                vm.toggleFavorite(shop.id)
                            } label: {
                                Image(systemName: shop.isFavorited ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundStyle(shop.isFavorited ? G.stampRed : G.darkRoast)
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
                                    .font(G.serif(23, weight: .bold))
                                    .foregroundStyle(G.darkRoast)
                                HStack(spacing: 6) {
                                    StarRow(rating: shop.rating)
                                    Text("(\(shop.reviewCount))")
                                        .font(G.mono(12))
                                        .foregroundStyle(G.lightRoast)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(shop.priceString)
                                    .font(G.serif(17, weight: .bold))
                                    .foregroundStyle(G.darkRoast)
                                Text(shop.isOpenNow ? "Open Now" : "Closed")
                                    .font(G.sans(12, weight: .medium))
                                    .foregroundStyle(shop.isOpenNow ? G.sage : G.stampRed)
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
                            StatPill(value: "\(realCheckInCount)", label: "Check-ins", icon: "mappin.circle.fill")
                            Divider().frame(height: 32).background(G.kraftLine)
                            StatPill(value: "\(shop.reviewCount)", label: "Reviews", icon: "star.fill")
                            Divider().frame(height: 32).background(G.kraftLine)
                            StatPill(value: shop.todayHours, label: "Today", icon: "clock.fill")
                        }
                        .background(G.kraft)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.kraftLine, lineWidth: 1))

                        // Address
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.fill")
                                .foregroundStyle(G.stampRed)
                            Text(shop.address)
                                .font(G.sans(14))
                                .foregroundStyle(G.darkRoast.opacity(0.8))
                        }

                        // Action buttons
                        HStack(spacing: 10) {
                            GButton("Directions", icon: "arrow.triangle.turn.up.right.diamond.fill",
                                    style: .outline) {
                                openDirections()
                            }
                            GButton(didCheckIn ? "Checked In" : "Check In",
                                    icon: didCheckIn ? "checkmark" : "mappin.and.ellipse",
                                    style: didCheckIn ? .ghost : .gold) {
                                if !didCheckIn { attemptCheckIn() }
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
                    .background(G.parchment)
                }
            }
            .background(G.parchment)
            .ignoresSafeArea(edges: .top)

            // ── Write review button ───────────────────────────────────────────
            if selectedTab == 0 {
                Button {
                    hasVisited ? (showWriteReview = true) : (showSubscription = !auth.currentUser.isPremium)
                } label: {
                    Label("Write a Review", systemImage: "pencil")
                        .font(G.sans(15, weight: .semibold))
                        .foregroundStyle(G.parchment)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(G.stampRed)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 34)
                        .background(G.parchment.opacity(0.95))
                }
            }
        }
        .task(id: shop.id) { await loadRealData() }
        .sheet(isPresented: $showWriteReview) {
            WriteReviewView(shop: shop)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showCheckIn) {
            CheckInConfirmView(shop: shop)
        }
        .alert("Can't Check In", isPresented: Binding(
            get: { checkInBlockedMessage != nil },
            set: { if !$0 { checkInBlockedMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(checkInBlockedMessage ?? "")
        }
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

    @ViewBuilder
    private var heroPhoto: some View {
        if let urlString = shop.photos.first, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                        .frame(height: 240)
                        .clipped()
                default:
                    heroPlaceholder
                }
            }
            .frame(height: 240)
        } else {
            heroPlaceholder
        }
    }

    private var heroPlaceholder: some View {
        Rectangle()
            .fill(G.kraft)
            .frame(height: 240)
            .overlay(
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(G.lightRoast)
            )
    }
}

// MARK: - Sub-views
struct StatPill: View {
    let value: String; let label: String; let icon: String
    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(G.stampRed)
            Text(value).font(G.mono(12)).foregroundStyle(G.darkRoast).lineLimit(1)
            Text(label).font(G.sans(10, weight: .medium)).foregroundStyle(G.lightRoast)
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
                    Image(systemName: "star").font(.system(size: 30)).foregroundStyle(G.lightRoast)
                    Text("No reviews yet").font(G.sans(14)).foregroundStyle(G.lightRoast)
                    Text("Be the first to leave one").font(G.sans(12)).foregroundStyle(G.lightRoast.opacity(0.75))
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
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    AvatarView(name: review.userName, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(review.userName).font(G.sans(14, weight: .semibold)).foregroundStyle(G.darkRoast)
                            if review.isVerifiedVisit {
                                Image(systemName: "checkmark.seal.fill").font(.system(size: 11)).foregroundStyle(G.sage)
                            }
                        }
                        Text(review.timeAgo).font(G.mono(11)).foregroundStyle(G.lightRoast)
                    }
                    Spacer()
                    StarRow(rating: review.rating, size: 11)
                }
                if !review.title.isEmpty {
                    Text(review.title).font(G.sans(14, weight: .semibold)).foregroundStyle(G.darkRoast)
                }
                Text(review.body).font(G.sans(13)).foregroundStyle(G.darkRoast.opacity(0.8)).lineLimit(4)
                HStack {
                    Spacer()
                    Button {
                        liked.toggle()
                    } label: {
                        Label("\(review.likes + (liked ? 1 : 0))", systemImage: liked ? "heart.fill" : "heart")
                            .font(G.sans(12, weight: .medium))
                            .foregroundStyle(liked ? G.stampRed : G.lightRoast)
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
                                        .overlay(ProgressView().tint(G.lightRoast))
                                }
                            }
                        } else {
                            photoPlaceholder
                        }

                        // Pro lock overlay for photos 4+
                        if i >= 3 && !isPremium {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.black.opacity(0.6))
                            Image(systemName: "lock.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(height: 100)
                    .onTapGesture { if i >= 3 && !isPremium { onPro() } }
                }
            }

            if shop.photos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 30)).foregroundStyle(G.lightRoast)
                    Text("No photos yet")
                        .font(G.sans(14)).foregroundStyle(G.lightRoast)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 32)
            }

            if !isPremium {
                Text("Unlock all photos & video reviews with Grounds Pro")
                    .font(G.sans(13)).foregroundStyle(G.lightRoast)
                    .multilineTextAlignment(.center).padding(.top, 4)
                GButton("Unlock Pro", icon: "crown.fill", style: .gold, action: onPro)
            }
        }
    }

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(G.kraft)
            .overlay(Image(systemName: "photo").foregroundStyle(G.lightRoast))
    }
}

struct InfoTab: View {
    let shop: CoffeeShop

    var body: some View {
        VStack(spacing: 16) {

            // ── Contact ────────────────────────────────────────────────────────
            if shop.phoneNumber != nil || shop.website != nil {
                PaperCard(padding: 14) {
                    VStack(spacing: 0) {
                        if let phone = shop.phoneNumber {
                            InfoRow(icon: "phone.fill", color: G.sage, label: phone) {
                                if let url = URL(string: "tel:\(phone.filter { $0.isNumber })") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        if shop.phoneNumber != nil && shop.website != nil {
                            Divider().background(G.kraftLine)
                        }
                        if let web = shop.website {
                            let display = web.replacingOccurrences(of: "https://", with: "")
                                            .replacingOccurrences(of: "http://", with: "")
                                            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                            InfoRow(icon: "globe", color: G.stampRed, label: display) {
                                if let url = URL(string: web) { UIApplication.shared.open(url) }
                            }
                        }
                    }
                }
            }

            // ── Hours ──────────────────────────────────────────────────────────
            PaperCard(padding: 14) {
                VStack(spacing: 0) {
                    let days = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
                    let today = days[max(0, Calendar.current.component(.weekday, from: Date()) - 2)]

                    ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                        let isToday  = day == today
                        let hoursStr = shop.hours[day] ?? "Hours unavailable"

                        HStack {
                            Text(day)
                                .font(G.sans(13, weight: isToday ? .semibold : .regular))
                                .foregroundStyle(G.darkRoast)
                            Spacer()
                            Text(hoursStr)
                                .font(G.mono(13))
                                .foregroundStyle(isToday ? G.stampRed : G.lightRoast)
                        }
                        .padding(.vertical, 9)

                        if i < days.count - 1 {
                            Divider().background(G.kraftLine)
                        }
                    }
                }
            }

            if shop.placeID != nil {
                Text("Data provided by Google")
                    .font(G.mono(10))
                    .foregroundStyle(G.lightRoast)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
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
                    Circle().fill(color.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
                }
                Text(label)
                    .font(G.sans(13))
                    .foregroundStyle(G.darkRoast.opacity(0.85))
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(G.lightRoast)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

struct CheckInConfirmView: View {
    let shop: CoffeeShop
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var community: CommunityService
    @Environment(\.dismiss) var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isSharing = false

    var body: some View {
        ZStack {
            G.parchment.ignoresSafeArea()
            VStack(spacing: 20) {
                // The stamp landing — the signature check-in moment
                StampMark(symbol: String(shop.name.prefix(1)).uppercased(), size: 90, rotation: -6)

                Text("Checked In").font(G.serif(26, weight: .bold)).foregroundStyle(G.darkRoast)
                Text(shop.name).font(G.sans(17)).foregroundStyle(G.darkRoast.opacity(0.8))

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable().scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.kraftLine, lineWidth: 1))
                } else {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        VStack(spacing: 6) {
                            Image(systemName: "camera.fill").font(.system(size: 22))
                            Text("Add a Photo").font(G.sans(12, weight: .medium))
                        }
                        .foregroundStyle(G.lightRoast)
                        .frame(width: 90, height: 90)
                        .background(G.kraft)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.kraftLine, lineWidth: 1))
                    }
                }

                if let error = community.errorMessage {
                    Text(error)
                        .font(G.sans(11))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                GButton(isSharing ? "Sharing…" : "Done") {
                    share()
                }
                .disabled(isSharing)
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 24)
        }
        .presentationDetents([.height(selectedImage == nil ? 340 : 440)])
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
    }

    private func share() {
        isSharing = true
        Task {
            await community.postCheckIn(
                shopID:   shop.id,
                shopName: shop.name,
                userID:   auth.currentUser.id,
                userName: auth.currentUser.name,
                photo:    selectedImage,
                caption:  nil
            )
            isSharing = false
            dismiss()
        }
    }
}
