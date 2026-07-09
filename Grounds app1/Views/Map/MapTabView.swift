import SwiftUI
import MapKit

struct MapTabView: View {
    @EnvironmentObject var auth: AuthService
    @StateObject private var vm   = MapViewModel()
    @StateObject private var loc  = LocationService()
    @State private var showDetail       = false
    @State private var showFilters      = false
    @State private var showSubscription = false
    @State private var showSearchHere   = false
    @State private var nearbySheetState: NearbySheetState = .peek

    /// Space our custom (non-system) tab bar occupies — the panel stays above it always,
    /// unlike a real .sheet() which docks flush to the screen edge and would cover it.
    private let tabBarClearance: CGFloat = 100
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
            span:   MKCoordinateSpan(latitudeDelta: 60.0, longitudeDelta: 60.0)
        )
    )

    var body: some View {
        GeometryReader { geo in
            mapContent(availableHeight: geo.size.height)
        }
    }

    /// Room the expanded panel can fill: full screen minus enough headroom to keep
    /// the search bar reachable, minus the tab bar's own space.
    private func expandedHeight(for screenHeight: CGFloat) -> CGFloat {
        max(300, screenHeight - 210 - tabBarClearance)
    }

    @ViewBuilder
    private func mapContent(availableHeight: CGFloat) -> some View {
        let panelMaxHeight = expandedHeight(for: availableHeight)
        ZStack(alignment: .top) {

            // ── Map ───────────────────────────────────────────────────────────
            // Modern MapKit SwiftUI API (not the deprecated coordinateRegion
            // initializer) so we can strip Apple's default POI clutter
            // (hotels, theaters, generic stores) and let our own coffee-shop
            // pins be the only thing on the map.
            Map(position: $cameraPosition) {
                UserAnnotation()
                ForEach(vm.filteredShops) { shop in
                    Annotation(shop.name, coordinate: shop.coordinate) {
                        ShopPin(shop: shop, isSelected: vm.selectedShop?.id == shop.id)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35)) {
                                    vm.selectShop(shop)
                                    nearbySheetState = .hidden
                                    showDetail = true
                                }
                            }
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControlVisibility(.hidden)
            // Force light map tiles regardless of the app's forced dark color scheme —
            // Apple's light-mode street colors (cream/warm grey, not navy) sit much
            // closer to the paper palette than the dark tiles did.
            .colorScheme(.light)
            .ignoresSafeArea()
            .onAppear {
                loc.requestPermission()
                loc.start()
            }
            // Snap to user's real location the first time GPS locks on
            .onChange(of: loc.location) { newLocation in
                guard let newLocation, !vm.hasCenteredOnUser else { return }
                vm.hasCenteredOnUser = true
                vm.centerOnUser(newLocation)
            }
            // Initial fetch of mock/fallback data on first load
            .task { await vm.fetchNearby() }
            // Programmatic region changes (centering on user) drive the camera
            .onChange(of: vm.cameraRevision) { _ in
                cameraPosition = .region(vm.mapRegion)
            }
            // User panning updates vm.mapRegion (used for "search this area" + distance calc)
            .onMapCameraChange(frequency: .onEnd) { context in
                vm.mapRegion = context.region
                if vm.hasCenteredOnUser {
                    withAnimation { showSearchHere = true }
                }
            }
            // Re-search when user submits a text search
            .onChange(of: vm.searchText) { query in
                guard query.count > 2 else { return }
                Task { await vm.fetchNearby(region: vm.mapRegion) }
            }

            // ── Top bar ───────────────────────────────────────────────────────
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    // Logo
                    Text("grounds")
                        .font(G.serif(21, weight: .bold))
                        .foregroundStyle(G.darkRoast)

                    Spacer()

                    // Pro badge
                    if !auth.currentUser.isPremium {
                        Button { showSubscription = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill").font(.system(size: 11))
                                Text("Go Pro").font(G.sans(12, weight: .semibold))
                            }
                            .foregroundStyle(G.parchment)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(G.stampRed)
                            .clipShape(Capsule())
                        }
                    }

                    // Filter button
                    Button { showFilters.toggle() } label: {
                        Image(systemName: vm.filterTag != nil ? "line.3.horizontal.decrease.circle.fill"
                                                              : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(vm.filterTag != nil ? G.stampRed : G.darkRoast)
                    }
                }

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(G.lightRoast)
                    TextField("Search coffee shops…", text: $vm.searchText)
                        .font(G.sans(15))
                        .foregroundStyle(G.darkRoast)
                        .submitLabel(.search)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.kraftLine, lineWidth: 1))

                // Filter chips
                if showFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(label: "Open Now",
                                       icon: "clock.fill",
                                       isActive: vm.showOnlyOpen) {
                                vm.showOnlyOpen.toggle()
                            }
                            ForEach(vm.allTags, id: \.self) { tag in
                                FilterChip(label: tag.capitalized,
                                           isActive: vm.filterTag == tag) {
                                    vm.filterTag = vm.filterTag == tag ? nil : tag
                                }
                            }
                        }
                        .padding(.trailing, 16)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [G.parchment.opacity(0.97), G.parchment.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )

            // ── "Search this area" button (mid-screen) ───────────────────────
            if showSearchHere && !vm.isSearching {
                VStack {
                    Spacer().frame(height: showFilters ? 208 : 160)
                    Button {
                        showSearchHere = false
                        vm.fetchForVisibleRegion()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Search This Area")
                                .font(G.sans(13, weight: .semibold))
                        }
                        .foregroundStyle(G.darkRoast)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(G.kraftLine, lineWidth: 1))
                        .shadow(color: .black.opacity(0.2), radius: 8)
                    }
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
            }

            // ── Loading spinner ───────────────────────────────────────────────
            if vm.isSearching {
                VStack {
                    Spacer().frame(height: showFilters ? 208 : 160)
                    HStack(spacing: 8) {
                        ProgressView().tint(G.darkRoast)
                        Text("Finding coffee nearby…")
                            .font(G.sans(12, weight: .medium))
                            .foregroundStyle(G.darkRoast)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                }
                .transition(.opacity)
            }

            // ── Notch when the nearby panel has been swiped away entirely ─────
            // Tap or drag it up to bring the panel back.
            if nearbySheetState == .hidden && !showDetail {
                VStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            nearbySheetState = .peek
                        }
                    } label: {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .frame(width: 56, height: 26)
                            .overlay(Capsule().stroke(G.kraftLine, lineWidth: 1))
                            .overlay(
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(G.darkRoast)
                            )
                            .shadow(color: .black.opacity(0.18), radius: 8)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 8)
                            .onEnded { value in
                                if value.translation.height < -8 {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        nearbySheetState = .peek
                                    }
                                }
                            }
                    )
                    .padding(.bottom, tabBarClearance + 6)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // ── Nearby shops — a custom draggable panel (not a system sheet, which
            // would dock flush to the screen edge and cover our custom tab bar).
            // Drag the handle to peek/expand/hide; tap a shop to open its detail.
            if !showDetail {
                VStack {
                    Spacer()
                    NearbyPanel(
                        shops: vm.filteredShops,
                        state: $nearbySheetState,
                        userLocation: loc.location,
                        maxHeight: panelMaxHeight
                    ) { shop in
                        vm.selectShop(shop)
                        nearbySheetState = .hidden
                        showDetail = true
                    }
                    // Fixed clip window matching the panel's own fixed maxHeight — the
                    // panel offsets itself within this; the window itself never resizes.
                    .frame(height: panelMaxHeight, alignment: .top)
                    .clipped()
                    .padding(.bottom, tabBarClearance)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .onChange(of: showDetail) { isShowing in
            if !isShowing {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { nearbySheetState = .peek }
            }
        }
        .sheet(isPresented: $showDetail) {
            if let shop = vm.selectedShop {
                ShopDetailView(initialShop: shop, vm: vm, userLocation: loc.location)
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }
}

// MARK: - Nearby Panel States
/// "expanded" has no fixed height — it fills all the way down to the tab bar (computed by
/// the caller via GeometryReader), so there's never a gap of map showing beneath the list.
enum NearbySheetState {
    case hidden, peek, expanded

    static let peekHeight: CGFloat = 130

    func targetHeight(maxHeight: CGFloat) -> CGFloat {
        switch self {
        case .hidden:   return 0
        case .peek:     return Self.peekHeight
        case .expanded: return maxHeight
        }
    }

    /// Which state to settle into after a drag ends, based on the live (pre-snap) height.
    static func settling(currentHeight: CGFloat, maxHeight: CGFloat) -> NearbySheetState {
        let candidates: [(NearbySheetState, CGFloat)] = [(.hidden, 0), (.peek, peekHeight), (.expanded, maxHeight)]
        return candidates.min(by: { abs($0.1 - currentHeight) < abs($1.1 - currentHeight) })!.0
    }
}

// MARK: - Map Pin
/// A clean circular photo marker (no pointer tail) — modern map-pin style used by
/// most photo-forward discovery apps, instead of the classic skeuomorphic pin bubble.
struct ShopPin: View {
    let shop: CoffeeShop
    let isSelected: Bool

    private var diameter: CGFloat { isSelected ? 58 : 40 }
    private var innerDiameter: CGFloat { diameter - 6 }

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.16))
                .frame(width: diameter, height: diameter)
                .blur(radius: 3)
                .offset(y: 2)

            Circle()
                .fill(G.kraft)
                .frame(width: diameter, height: diameter)

            if let urlString = shop.photos.first, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        placeholderIcon
                    }
                }
                .frame(width: innerDiameter, height: innerDiameter)
                .clipShape(Circle())
            } else {
                placeholderIcon
            }

            // Selected pin borrows the stamp's double-ring — ties the map back to
            // the same signature mark used for check-ins, not just a plain highlight.
            if isSelected {
                Circle()
                    .stroke(G.stampRed, lineWidth: 3)
                    .frame(width: diameter, height: diameter)
                Circle()
                    .stroke(G.stampRed.opacity(0.35), lineWidth: 1)
                    .frame(width: diameter - 9, height: diameter - 9)
            } else {
                Circle()
                    .stroke(G.parchment, lineWidth: 2)
                    .frame(width: diameter, height: diameter)
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private var placeholderIcon: some View {
        ZStack {
            Circle().fill(G.darkRoast)
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: isSelected ? 20 : 14, weight: .semibold))
                .foregroundStyle(G.parchment)
        }
        .frame(width: innerDiameter, height: innerDiameter)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    var icon: String? = nil
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.system(size: 10)) }
                Text(label).font(G.sans(12, weight: .medium))
            }
            .foregroundStyle(isActive ? G.parchment : G.darkRoast)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isActive ? G.stampRed : G.kraft)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isActive ? Color.clear : G.kraftLine, lineWidth: 1))
        }
    }
}

// MARK: - Sort / Range
enum NearbySortOption: String, CaseIterable {
    case rating   = "Top Rated"
    case distance = "Nearest"
    var icon: String { self == .rating ? "star.fill" : "location.fill" }
}

enum NearbyRange: Double, CaseIterable {
    case half   = 0.5
    case one    = 1
    case three  = 3
    case five   = 5
    case ten    = 10
    case any    = 100000
    var label: String { self == .any ? "Any distance" : "< \(rawValue == 0.5 ? "½" : String(format: "%.0f", rawValue)) mi" }
}

// MARK: - Nearby Panel
/// Custom draggable bottom panel — not a system .sheet(), which docks flush to the
/// screen edge and would cover our custom tab bar. Only the handle/header carries the
/// drag gesture, so the list underneath scrolls normally without fighting the pan.
/// "expanded" fills all the way down to the tab bar (maxHeight, computed by the
/// caller) so there's never a gap of map visible below the list.
struct NearbyPanel: View {
    let shops: [CoffeeShop]
    @Binding var state: NearbySheetState
    let userLocation: CLLocation?
    let maxHeight: CGFloat
    let onSelect: (CoffeeShop) -> Void

    // Plain @State (not @GestureState) — we need to reset this in the exact same
    // withAnimation transaction as `state` on release, so the two never race each
    // other and cause the panel to visibly snap before easing to its final height.
    @State private var dragTranslation: CGFloat = 0

    @State private var sortOption: NearbySortOption = .rating
    @State private var range: NearbyRange = .any

    // Sorted/filtered once when its inputs actually change, not on every drag frame —
    // this used to be a computed property re-evaluated (with per-shop distance calcs
    // and a full sort) on every single onChanged callback during a drag, which is what
    // was actually causing the stutter, worse the longer/slower the drag lasted.
    @State private var displayedShops: [(shop: CoffeeShop, miles: Double?)] = []

    private var visibleHeight: CGFloat {
        min(max(0, state.targetHeight(maxHeight: maxHeight) - dragTranslation), maxHeight)
    }

    /// The panel is always laid out at a fixed `maxHeight` and pushed down by this
    /// amount instead of having its frame resized — offset is a pure GPU compositing
    /// transform with no layout pass, while resizing the frame forces the ScrollView
    /// and every row inside it to redo layout on every single drag frame. That relayout
    /// churn (not the animation timing) was the actual source of the stutter.
    private var panelOffsetY: CGFloat {
        maxHeight - visibleHeight
    }

    private func distanceMiles(to shop: CoffeeShop) -> Double? {
        guard let userLocation else { return nil }
        let shopLocation = CLLocation(latitude: shop.latitude, longitude: shop.longitude)
        return userLocation.distance(from: shopLocation) / 1609.34
    }

    private func recomputeDisplayedShops() {
        var withDistance = shops.map { (shop: $0, miles: distanceMiles(to: $0)) }
        if range != .any {
            withDistance = withDistance.filter { ($0.miles ?? 0) <= range.rawValue }
        }
        switch sortOption {
        case .rating:
            withDistance.sort { $0.shop.rating > $1.shop.rating }
        case .distance:
            withDistance.sort { ($0.miles ?? .greatestFiniteMagnitude) < ($1.miles ?? .greatestFiniteMagnitude) }
        }
        displayedShops = withDistance
    }

    /// One gesture handles both drag-to-resize (tracking the finger 1:1 from the very
    /// first point of contact) and tap-to-toggle (a release with near-zero movement) —
    /// combining a separate DragGesture + onTapGesture caused the system to briefly
    /// hesitate deciding which one a slow, deliberate pull-up was.
    private var handleGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if abs(value.translation.height) < 6 {
                        state = state == .expanded ? .peek : .expanded
                    } else {
                        let liveHeight = state.targetHeight(maxHeight: maxHeight) - value.translation.height
                        state = NearbySheetState.settling(currentHeight: liveHeight, maxHeight: maxHeight)
                    }
                    // Reset in the SAME transaction as `state`, so there's one smooth
                    // animation from wherever the finger let go to the settled height,
                    // instead of an instant snap followed by a separate spring.
                    dragTranslation = 0
                }
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle — the only part that carries the pan gesture, so the filter
            // menus below and the list's own scrolling never fight it for touches.
            VStack(spacing: 8) {
                Capsule().fill(G.kraftLine).frame(width: 40, height: 5)
                HStack {
                    Text("\(displayedShops.count) SHOPS NEARBY")
                        .font(G.mono(11))
                        .foregroundStyle(G.lightRoast)
                    Spacer()
                    Image(systemName: state == .expanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(G.lightRoast)
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .contentShape(Rectangle())
            .gesture(handleGesture)

            // Sort + range filters — outside the drag handle's hit area so the menus
            // always open reliably instead of competing with the pan gesture.
            HStack(spacing: 8) {
                Menu {
                    ForEach(NearbySortOption.allCases, id: \.self) { option in
                        Button {
                            sortOption = option
                        } label: {
                            Label(option.rawValue, systemImage: option.icon)
                        }
                    }
                } label: {
                    FilterPill(icon: sortOption.icon, label: sortOption.rawValue)
                }

                Menu {
                    ForEach(NearbyRange.allCases, id: \.self) { r in
                        Button { range = r } label: { Text(r.label) }
                    }
                } label: {
                    FilterPill(icon: "map", label: range.label)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    ForEach(displayedShops, id: \.shop.id) { entry in
                        NearbyListRow(shop: entry.shop, distanceMiles: entry.miles)
                            .onTapGesture { onSelect(entry.shop) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .frame(maxHeight: .infinity)
        }
        // Always laid out at full height — never reflows mid-drag. Visibility is
        // controlled purely by the .offset() below; the caller clips the fixed
        // maxHeight window this sits inside.
        .frame(height: maxHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(G.parchment)
        .clipShape(.rect(topLeadingRadius: 22, topTrailingRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(G.kraftLine, lineWidth: 1)
                .opacity(state == .hidden ? 0 : 1)
        )
        .shadow(color: .black.opacity(state == .hidden ? 0 : 0.18), radius: 16, y: -4)
        .offset(y: panelOffsetY)
        .onAppear { recomputeDisplayedShops() }
        .onChange(of: shops) { _ in recomputeDisplayedShops() }
        .onChange(of: sortOption) { _ in recomputeDisplayedShops() }
        .onChange(of: range) { _ in recomputeDisplayedShops() }
    }
}

struct FilterPill: View {
    let icon: String
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 10))
            Text(label).font(G.sans(11, weight: .medium))
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(G.darkRoast)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(G.kraft)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(G.kraftLine, lineWidth: 1))
    }
}

struct NearbyListRow: View {
    let shop: CoffeeShop
    var distanceMiles: Double? = nil

    var body: some View {
        HStack(spacing: 12) {
            ShopThumbnail(urlString: shop.photos.first, size: 60)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(shop.name)
                        .font(G.sans(15, weight: .semibold))
                        .foregroundStyle(G.darkRoast)
                        .lineLimit(1)
                    Spacer()
                    if shop.isFavorited {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(G.stampRed)
                    }
                }
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(G.stampRed)
                    Text(String(format: "%.1f", shop.rating)).font(G.mono(12)).foregroundStyle(G.darkRoast)
                    Text("·").foregroundStyle(G.lightRoast)
                    Text(shop.priceString).font(G.mono(12)).foregroundStyle(G.lightRoast)
                    if shop.isOpenNow {
                        Text("·").foregroundStyle(G.lightRoast)
                        Text("Open").font(G.sans(12, weight: .medium)).foregroundStyle(G.sage)
                    }
                    if let distanceMiles {
                        Text("·").foregroundStyle(G.lightRoast)
                        Text(distanceMiles < 0.1 ? "< 0.1 mi" : String(format: "%.1f mi", distanceMiles))
                            .font(G.mono(12)).foregroundStyle(G.stampRed)
                    }
                }
                Text(shop.address)
                    .font(G.sans(12))
                    .foregroundStyle(G.lightRoast)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(G.lightRoast)
        }
        .padding(12)
        .background(G.kraft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.kraftLine, lineWidth: 1))
    }
}

// MARK: - Shop Thumbnail
struct ShopThumbnail: View {
    let urlString: String?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(G.kraft)
            .overlay(
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(G.lightRoast)
            )
    }
}
