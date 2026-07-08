import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @EnvironmentObject var store: SubscriptionManager
    @State private var selectedPlan: Plan = .annual
    @State private var isPurchasing = false
    @State private var showSuccess  = false

    enum Plan: String, CaseIterable {
        case monthly = "Monthly"
        case annual  = "Annual"

        var productID: String {
            switch self {
            case .monthly: return SubscriptionManager.monthlyID
            case .annual:  return SubscriptionManager.annualID
            }
        }
        var badge: String? {
            self == .annual ? "Save 42%" : nil
        }

        func price(in store: SubscriptionManager) -> String {
            store.products.first { $0.id == productID }?.displayPrice ?? "—"
        }
        func perMonth(in store: SubscriptionManager) -> String {
            guard let product = store.products.first(where: { $0.id == productID }) else { return "—" }
            switch self {
            case .monthly: return "\(product.displayPrice)/mo"
            case .annual:
                let monthly = product.price / 12
                return monthly.formatted(product.priceFormatStyle) + "/mo"
            }
        }
    }

    let features: [(icon: String, color: Color, title: String, subtitle: String)] = [
        ("crown.fill",          G.gold,    "Unlimited Check-ins",     "Check in as many times as you want"),
        ("photo.on.rectangle",  G.caramel, "Photos & Video Reviews",  "Upload rich media with your reviews"),
        ("trophy.fill",         G.gold,    "Full Leaderboard Access", "See your global & friend rankings"),
        ("star.fill",           G.latte,   "Exclusive Pro Badges",    "Show off your coffee expertise"),
        ("bell.badge.fill",     G.sage,    "Priority Notifications",  "Never miss a friend's check-in"),
        ("map.fill",            G.caramel, "Advanced Map Filters",    "Filter by brew method, vibe & more"),
    ]

    var body: some View {
        ZStack {
            G.espresso.ignoresSafeArea()

            if showSuccess {
                SuccessView { dismiss() }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Header ─────────────────────────────────────────────
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(G.gold2.opacity(0.25))
                                        .frame(width: 100, height: 100)
                                    Circle()
                                        .fill(G.gold2)
                                        .frame(width: 72, height: 72)
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(G.espresso)
                                }

                                VStack(spacing: 8) {
                                    Text("Grounds Pro")
                                        .font(G.title(28))
                                        .foregroundStyle(G.cream)
                                    Text("Elevate your coffee journey")
                                        .font(G.body(15))
                                        .foregroundStyle(G.latte)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 36)
                            .padding(.bottom, 28)

                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(G.muted)
                                    .padding(8)
                                    .background(G.surface2)
                                    .clipShape(Circle())
                            }
                            .padding([.top, .trailing], 20)
                        }

                        // ── Plan picker ────────────────────────────────────────
                        HStack(spacing: 12) {
                            ForEach(Plan.allCases, id: \.self) { plan in
                                PlanCard(plan: plan, isSelected: selectedPlan == plan)
                                    .environmentObject(store)
                                    .onTapGesture { withAnimation(.spring(response: 0.3)) { selectedPlan = plan } }
                            }
                        }
                        .padding(.horizontal, 20)

                        // ── Features ───────────────────────────────────────────
                        VStack(spacing: 0) {
                            ForEach(features.indices, id: \.self) { i in
                                let f = features[i]
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(f.color.opacity(0.15))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: f.icon)
                                            .font(.system(size: 16))
                                            .foregroundStyle(f.color)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(f.title)
                                            .font(G.body(14)).fontWeight(.semibold)
                                            .foregroundStyle(G.cream)
                                        Text(f.subtitle)
                                            .font(G.label(12))
                                            .foregroundStyle(G.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(G.sage)
                                        .font(.system(size: 18))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)

                                if i < features.count - 1 {
                                    Divider().background(G.border).padding(.leading, 70)
                                }
                            }
                        }
                        .background(G.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(G.border, lineWidth: 1))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        // ── CTA ────────────────────────────────────────────────
                        VStack(spacing: 12) {
                            Button {
                                purchase()
                            } label: {
                                HStack(spacing: 8) {
                                    if isPurchasing {
                                        ProgressView().tint(G.espresso)
                                    } else {
                                        Image(systemName: "crown.fill")
                                        Text("Start \(selectedPlan.rawValue) Plan")
                                            .fontWeight(.bold)
                                    }
                                }
                                .font(G.body(16))
                                .foregroundStyle(G.espresso)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(G.gold2)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(isPurchasing || store.products.isEmpty)

                            Text("\(selectedPlan.price(in: store)) billed \(selectedPlan == .annual ? "annually" : "monthly"). Cancel anytime.")
                                .font(G.label(11))
                                .foregroundStyle(G.muted)
                                .multilineTextAlignment(.center)

                            if let error = store.errorMessage {
                                Text(error)
                                    .font(G.label(11))
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                            }

                            HStack(spacing: 16) {
                                Button("Restore Purchases") { Task { await store.restorePurchases() } }
                                    .font(G.label(12))
                                    .foregroundStyle(G.latte)
                                Text("·").foregroundStyle(G.muted)
                                Button("Privacy Policy") {
                                    if let url = URL(string: "https://victoriapetruska.github.io/grounds-app1/privacy-policy.html") {
                                        openURL(url)
                                    }
                                }
                                    .font(G.label(12))
                                    .foregroundStyle(G.latte)
                                Text("·").foregroundStyle(G.muted)
                                Button("Terms") {
                                    if let url = URL(string: "https://victoriapetruska.github.io/grounds-app1/terms.html") {
                                        openURL(url)
                                    }
                                }
                                    .font(G.label(12))
                                    .foregroundStyle(G.latte)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { if store.products.isEmpty { await store.loadProducts() } }
    }

    func purchase() {
        guard let product = store.products.first(where: { $0.id == selectedPlan.productID }) else { return }
        isPurchasing = true
        Task {
            let success = await store.purchase(product)
            isPurchasing = false
            if success {
                withAnimation { showSuccess = true }
            }
        }
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    @EnvironmentObject var store: SubscriptionManager
    let plan: SubscriptionView.Plan
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 10) {
            if let badge = plan.badge {
                Text(badge)
                    .font(G.label(10)).fontWeight(.bold)
                    .foregroundStyle(G.espresso)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(G.gold2)
                    .clipShape(Capsule())
            } else {
                Color.clear.frame(height: 22)
            }

            Text(plan.rawValue)
                .font(G.body(15)).fontWeight(.semibold)
                .foregroundStyle(isSelected ? G.cream : G.muted)

            Text(plan.price(in: store))
                .font(G.title(22))
                .foregroundStyle(isSelected ? G.gold : G.muted)

            Text(plan.perMonth(in: store))
                .font(G.label(11))
                .foregroundStyle(isSelected ? G.latte : G.muted.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(isSelected ? G.caramel.opacity(0.12) : G.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? G.caramel : G.border, lineWidth: isSelected ? 2 : 1)
        )
    }
}

// MARK: - Success View
struct SuccessView: View {
    let onDone: () -> Void
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(G.gold2.opacity(0.2))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(G.gold2)
                    .frame(width: 90, height: 90)
                Image(systemName: "crown.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(G.espresso)
            }

            VStack(spacing: 10) {
                Text("Welcome to Pro!")
                    .font(G.title(28))
                    .foregroundStyle(G.cream)
                Text("You now have access to all Grounds\nPro features. Enjoy the journey ☕")
                    .font(G.body(15))
                    .foregroundStyle(G.latte)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                ForEach(["Unlimited check-ins unlocked", "Photo & video reviews unlocked", "Exclusive Pro badges unlocked"], id: \.self) { perk in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(G.sage)
                        Text(perk).font(G.body(14)).foregroundStyle(G.latte)
                    }
                }
            }

            Spacer()
            GButton("Let's Go!", icon: "arrow.right") { onDone() }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
        .padding(24)
    }
}
