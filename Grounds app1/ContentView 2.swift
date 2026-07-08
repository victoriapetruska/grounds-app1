import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthService
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Tab content ──────────────────────────────────────────────────
            TabView(selection: $selectedTab) {
                MapTabView()
                    .tag(0)
                SocialTabView()
                    .tag(1)
                ProfileTabView()
                    .tag(2)
            }
            // Hide the native tab bar — we draw our own below
            .tabViewStyle(.page(indexDisplayMode: .never))

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
                            // Active pill background
                            if selectedTab == i {
                                Capsule()
                                    .fill(G.caramelGrad)
                                    .frame(width: 52, height: 28)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Image(systemName: tabs[i].icon)
                                .font(.system(size: 16, weight: selectedTab == i ? .semibold : .regular))
                                .foregroundStyle(selectedTab == i ? .white : G.muted)
                        }
                        Text(tabs[i].label)
                            .font(G.label(10))
                            .foregroundStyle(selectedTab == i ? G.caramel : G.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 28)
        .background(
            G.espresso
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(G.border),
                    alignment: .top
                )
        )
    }
}
