import SwiftUI

// MARK: - Grounds Design System

struct G {

    // ── Colors ────────────────────────────────────────────────────────────────
    static let espresso  = Color(hex: "140800")
    static let roast     = Color(hex: "2A1208")
    static let brown     = Color(hex: "5C2E0E")
    static let caramel   = Color(hex: "C4793A")
    static let latte     = Color(hex: "C9956A")
    static let cream     = Color(hex: "F5E6D3")
    static let foam      = Color(hex: "FFF9F4")
    static let gold      = Color(hex: "D4A853")
    static let sage      = Color(hex: "4A7C59")
    static let surface   = Color(hex: "1E0D05")
    static let surface2  = Color(hex: "271508")
    static let border    = Color(hex: "3D2010")
    static let muted     = Color(hex: "8B6050")

    // ── Gradients ─────────────────────────────────────────────────────────────
    static let bg = LinearGradient(
        colors: [espresso, roast],
        startPoint: .top, endPoint: .bottom
    )
    static let card = LinearGradient(
        colors: [surface, surface2],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let gold2 = LinearGradient(
        colors: [Color(hex: "C49030"), Color(hex: "F0C96B"), Color(hex: "C49030")],
        startPoint: .leading, endPoint: .trailing
    )
    static let caramelGrad = LinearGradient(
        colors: [caramel, Color(hex: "E8945A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // ── Typography ────────────────────────────────────────────────────────────
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func label(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func mono(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

// MARK: - Reusable UI Components

struct GCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    var body: some View {
        content
            .padding(padding)
            .background(G.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(G.border, lineWidth: 1))
    }
}

struct GButton: View {
    let title: String
    var icon: String? = nil
    var style: ButtonStyle = .gold
    let action: () -> Void

    enum ButtonStyle { case gold, outline, ghost }

    init(_ title: String, icon: String? = nil, style: ButtonStyle = .gold, action: @escaping () -> Void) {
        self.title  = title
        self.icon   = icon
        self.style  = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 16, weight: .semibold)) }
                Text(title).font(G.body(16)).fontWeight(.semibold)
            }
            .foregroundStyle(style == .gold ? G.espresso : G.cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                switch style {
                case .gold:    RoundedRectangle(cornerRadius: 14).fill(G.gold2)
                case .outline: RoundedRectangle(cornerRadius: 14).stroke(G.caramel, lineWidth: 1.5)
                case .ghost:   Color.clear
                }
            }
        }
    }
}

struct StarRow: View {
    let rating: Double
    var size: CGFloat = 13
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: Double(i) <= rating ? "star.fill"
                      : Double(i) - 0.5 <= rating ? "star.leadinghalf.filled" : "star")
                .font(.system(size: size))
                .foregroundStyle(G.gold)
            }
            Text(String(format: "%.1f", rating))
                .font(G.label(size))
                .foregroundStyle(G.latte)
                .padding(.leading, 2)
        }
    }
}

struct ProBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill").font(.system(size: 9))
            Text("PRO").font(G.label(9))
        }
        .foregroundStyle(G.espresso)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(G.gold2)
        .clipShape(Capsule())
    }
}

struct TagChip: View {
    let label: String
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 10)) }
            Text(label).font(G.label(11))
        }
        .foregroundStyle(G.latte)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(G.border.opacity(0.6))
        .clipShape(Capsule())
    }
}

struct AvatarView: View {
    let name: String
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            Circle().fill(G.caramelGrad)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
