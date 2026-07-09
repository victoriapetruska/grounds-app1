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

    let features: [(icon: String, title: String, subtitle: String)] = [
        ("crown.fill",         "Unlimited Check-ins",     "Check in as many times as you want"),
        ("photo.on.rectangle", "Photos & Video Reviews",  "Upload rich media with your reviews"),
        ("trophy.fill",        "Full Leaderboard Access", "See your global & friend rankings"),
        ("bell.badge.fill",    "Priority Notifications",  "Never miss a friend's check-in"),
        ("map.fill",           "Advanced Map Filters",    "Filter by brew method, vibe & more"),
    ]

    var body: some View {
        ZStack {
            G.parchment.ignoresSafeArea()

            if showSuccess {
                SuccessView { dismiss() }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Header ─────────────────────────────────────────────
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 16) {
                                StampMark(symbol: "crown.fill", isSymbolName: true, size: 72, rotation: -6)

                                VStack(spacing: 8) {
                                    Text("Grounds Pro")
                                        .font(G.serif(26, weight: .bold))
                                        .foregroundStyle(G.darkRoast)
                                    Text("Elevate your coffee journey")
                                        .font(G.sans(15))
                                        .foregroundStyle(G.lightRoast)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 36)
                            .padding(.bottom, 28)

                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(G.lightRoast)
                                    .padding(8)
                                    .background(G.kraft)
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
                                            .fill(G.stampRed.opacity(0.12))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: f.icon)
                                            .font(.system(size: 16))
                                            .foregroundStyle(G.stampRed)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(f.title)
                                            .font(G.sans(14, weight: .semibold))
                                            .foregroundStyle(G.darkRoast)
                                        Text(f.subtitle)
                                            .font(G.sans(12))
                                            .foregroundStyle(G.lightRoast)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(G.sage)
                                        .font(.system(size: 18))
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)

                                if i < features.count - 1 {
                                    Divider().background(G.kraftLine).padding(.leading, 70)
                                }
                            }
                        }
                        .background(G.kraft)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(G.kraftLine, lineWidth: 1))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        // ── CTA ────────────────────────────────────────────────
                        VStack(spacing: 12) {
                            Button {
                                purchase()
                            } label: {
                                HStack(spacing: 8) {
                                    if isPurchasing {
                                        ProgressView().tint(G.parchment)
                                    } else {
                                        Image(systemName: "crown.fill")
                                        Text("Start \(selectedPlan.rawValue) Plan")
                                            .fontWeight(.bold)
                                    }
                                }
                                .font(G.sans(16))
                                .foregroundStyle(G.parchment)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(G.stampRed)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(isPurchasing || store.products.isEmpty)

                            Text("\(selectedPlan.price(in: store)) billed \(selectedPlan == .annual ? "annually" : "monthly"). Cancel anytime.")
                                .font(G.sans(11))
                                .foregroundStyle(G.lightRoast)
                                .multilineTextAlignment(.center)

                            if let error = store.errorMessage {
                                Text(error)
                                    .font(G.sans(11))
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                            }

                            HStack(spacing: 16) {
                                Button("Restore Purchases") { Task { await store.restorePurchases() } }
                                    .font(G.sans(12, weight: .medium))
                                    .foregroundStyle(G.darkRoast.opacity(0.75))
                                Text("·").foregroundStyle(G.lightRoast)
                                Button("Privacy Policy") {
                                    if let url = URL(string: "https://victoriapetruska.github.io/grounds-app1/privacy-policy.html") {
                                        openURL(url)
                                    }
                                }
                                    .font(G.sans(12, weight: .medium))
                                    .foregroundStyle(G.darkRoast.opacity(0.75))
                                Text("·").foregroundStyle(G.lightRoast)
                                Button("Terms") {
                                    if let url = URL(string: "https://victoriapetruska.github.io/grounds-app1/terms.html") {
                                        openURL(url)
                                    }
                                }
                                    .font(G.sans(12, weight: .medium))
                                    .foregroundStyle(G.darkRoast.opacity(0.75))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
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
                    .font(G.mono(10)).fontWeight(.bold)
                    .foregroundStyle(G.parchment)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(G.stampRed)
                    .clipShape(Capsule())
            } else {
                Color.clear.frame(height: 22)
            }

            Text(plan.rawValue)
                .font(G.sans(15, weight: .semibold))
                .foregroundStyle(isSelected ? G.darkRoast : G.lightRoast)

            Text(plan.price(in: store))
                .font(G.serif(20, weight: .bold))
                .foregroundStyle(isSelected ? G.stampRed : G.lightRoast)

            Text(plan.perMonth(in: store))
                .font(G.mono(11))
                .foregroundStyle(isSelected ? G.darkRoast.opacity(0.7) : G.lightRoast.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(isSelected ? G.stampRed.opacity(0.08) : G.kraft)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? G.stampRed : G.kraftLine, lineWidth: isSelected ? 2 : 1)
        )
    }
}

// MARK: - Success View
struct SuccessView: View {
    let onDone: () -> Void
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            StampMark(symbol: "crown.fill", isSymbolName: true, size: 90, rotation: -6)

            VStack(spacing: 10) {
                Text("Welcome to Pro")
                    .font(G.serif(26, weight: .bold))
                    .foregroundStyle(G.darkRoast)
                Text("You now have access to all Grounds Pro features. Enjoy the journey.")
                    .font(G.sans(15))
                    .foregroundStyle(G.lightRoast)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                ForEach(["Unlimited check-ins unlocked", "Photo & video reviews unlocked", "Full leaderboard access unlocked"], id: \.self) { perk in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(G.sage)
                        Text(perk).font(G.sans(14)).foregroundStyle(G.darkRoast.opacity(0.8))
                    }
                }
            }

            Spacer()
            GButton("Let's Go", icon: "arrow.right") { onDone() }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
        }
        .padding(24)
    }
}
