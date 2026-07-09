import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthService
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Tab content ──────────────────────────────────────────────────
            // Plain conditional switch (not TabView) so each tab's content can
            // truly bleed edge-to-edge — TabView's .page style adds its own
            // safe-area insets that fight full-screen content like the map.
            Group {
                switch selectedTab {
                case 0: MapTabView()
                case 1: SocialTabView()
                default: ProfileTabView()
                }
            }

            // ── Custom tab bar ───────────────────────────────────────────────
            GroundsTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Custom Tab Bar
struct GroundsTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, label: String)] = [
        ("map.fill",      "Explore"),
        ("person.2.fill", "Social"),
        ("person.fill",   "Profile"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = i
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            // Active pill background — same stamp red used everywhere
                            // else as the app's single accent
                            if selectedTab == i {
                                Capsule()
                                    .fill(G.stampRed)
                                    .frame(width: 52, height: 28)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Image(systemName: tabs[i].icon)
                                .font(.system(size: 16, weight: selectedTab == i ? .semibold : .regular))
                                .foregroundStyle(selectedTab == i ? G.parchment : G.lightRoast)
                        }
                        Text(tabs[i].label)
                            .font(G.sans(10, weight: .medium))
                            .foregroundStyle(selectedTab == i ? G.stampRed : G.lightRoast)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 28)
        .background(
            G.parchment
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(G.kraftLine),
                    alignment: .top
                )
        )
    }
}
