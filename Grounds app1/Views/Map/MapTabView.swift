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

    var body: some View {
        ZStack(alignment: .top) {

            // ── Map ───────────────────────────────────────────────────────────
            Map(coordinateRegion: $vm.mapRegion,
                showsUserLocation: true,
                annotationItems: vm.filteredShops) { shop in
                MapAnnotation(coordinate: shop.coordinate) {
                    ShopPin(shop: shop, isSelected: vm.selectedShop?.id == shop.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35)) {
                                vm.selectShop(shop)
                                showDetail = true
                            }
                        }
                }
            }
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
            // Show "Search this area" when user pans the map
            .onChange(of: vm.mapRegion.center.latitude) { _ in
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
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(G.cream)

                    Spacer()

                    // Pro badge
                    if !auth.currentUser.isPremium {
                        Button { showSubscription = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill").font(.system(size: 11))
                                Text("Go Pro").font(G.label(12))
                            }
                            .foregroundStyle(G.espresso)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(G.gold2)
                            .clipShape(Capsule())
                        }
                    }

                    // Filter button
                    Button { showFilters.toggle() } label: {
                        Image(systemName: vm.filterTag != nil ? "line.3.horizontal.decrease.circle.fill"
                                                              : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(vm.filterTag != nil ? G.caramel : G.cream)
                    }
                }

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(G.muted)
                    TextField("Search coffee shops...", text: $vm.searchText)
                        .font(G.body(15))
                        .foregroundStyle(G.cream)
                        .submitLabel(.search)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.border, lineWidth: 1))

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
                        .padding(.horizontal, 2)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [G.espresso.opacity(0.95), G.espresso.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )

            // ── "Search this area" button (mid-screen) ───────────────────────
            if showSearchHere && !vm.isSearching {
                VStack {
                    Spacer().frame(height: 160)
                    Button {
                        showSearchHere = false
                        vm.fetchForVisibleRegion()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Search This Area")
                                .font(G.label(13))
                        }
                        .foregroundStyle(G.cream)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(G.border, lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 8)
                    }
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
            }

            // ── Loading spinner ───────────────────────────────────────────────
            if vm.isSearching {
                VStack {
                    Spacer().frame(height: 160)
                    HStack(spacing: 8) {
                        ProgressView().tint(G.cream)
                        Text("Finding coffee nearby…")
                            .font(G.label(12))
                            .foregroundStyle(G.cream)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                }
                .transition(.opacity)
            }

            // ── Nearby list (bottom) ──────────────────────────────────────────
            VStack {
                Spacer()
                if !showDetail {
                    NearbyStrip(shops: vm.filteredShops) { shop in
                        withAnimation { vm.selectShop(shop) }
                        showDetail = true
                    }
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            if let shop = vm.selectedShop {
                ShopDetailView(shop: shop, vm: vm)
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }
}

// MARK: - Map Pin
struct ShopPin: View {
    let shop: CoffeeShop
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isSelected ? G.caramelGrad : LinearGradient(colors: [G.surface, G.surface2], startPoint: .top, endPoint: .bottom))
                    .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                    .shadow(color: isSelected ? G.caramel.opacity(0.6) : .black.opacity(0.3),
                            radius: isSelected ? 10 : 4)
                    .overlay(Circle().stroke(isSelected ? G.gold : G.border, lineWidth: isSelected ? 2 : 1))

                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: isSelected ? 18 : 14))
                    .foregroundStyle(isSelected ? .white : G.latte)
            }

            // Pointer
            Triangle()
                .fill(isSelected ? G.caramel : G.surface)
                .frame(width: 10, height: 6)
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
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
                Text(label).font(G.label(12))
            }
            .foregroundStyle(isActive ? G.espresso : G.cream)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isActive ? G.caramelGrad : LinearGradient(colors: [G.surface], startPoint: .top, endPoint: .bottom))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isActive ? Color.clear : G.border, lineWidth: 1))
        }
    }
}

// MARK: - Nearby Strip
struct NearbyStrip: View {
    let shops: [CoffeeShop]
    let onSelect: (CoffeeShop) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEARBY")
                .font(G.label(11))
                .foregroundStyle(G.muted)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(shops.prefix(8)) { shop in
                        NearbyCard(shop: shop)
                            .onTapGesture { onSelect(shop) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 24)
        .padding(.top, 12)
        .background(
            LinearGradient(
                colors: [G.espresso.opacity(0), G.espresso.opacity(0.97)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}

struct NearbyCard: View {
    let shop: CoffeeShop
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(shop.name)
                    .font(G.body(13)).fontWeight(.semibold)
                    .foregroundStyle(G.cream)
                    .lineLimit(1)
                Spacer()
                if shop.isFavorited {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(G.caramel)
                }
            }
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(G.gold)
                Text(String(format: "%.1f", shop.rating)).font(G.label(11)).foregroundStyle(G.latte)
                Text("·").foregroundStyle(G.muted)
                Text(shop.priceString).font(G.label(11)).foregroundStyle(G.muted)
                if shop.isOpenNow {
                    Text("·").foregroundStyle(G.muted)
                    Text("Open").font(G.label(11)).foregroundStyle(G.sage)
                }
            }
            Text(shop.address)
                .font(G.body(11))
                .foregroundStyle(G.muted)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 200)
        .background(G.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(G.border, lineWidth: 1))
    }
}
