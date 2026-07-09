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

    // ── Paper palette (Profile / League / Explore redesign) ─────────────────────
    // Additive only — the tokens above stay untouched so screens not yet migrated
    // (Battles, ShopDetail, Subscription, Onboarding) keep working unchanged.
    static let parchment  = Color(hex: "F4EAD8")   // primary background — unbleached paper
    static let kraft       = Color(hex: "E4D4B8")   // card surface — deeper bag-paper tone
    static let kraftLine   = Color(hex: "CBB690")   // borders/dividers on kraft
    static let lightRoast  = Color(hex: "B08D5F")   // secondary text, tan accents
    static let darkRoast   = Color(hex: "2B1B12")   // primary text, high-contrast surfaces
    static let stampRed    = Color(hex: "A63D2C")   // the single confident accent — ink-stamp red

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

    // ── Paper typography (Profile / League / Explore redesign) ──────────────────
    // .serif resolves to New York on iOS — a real display face with texture, no
    // font bundling needed. .default (not .rounded) is the deliberate break from
    // the "generic habit-tracker" rounded sans used everywhere else in the app.
    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
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

/// GCard and PaperCard have converged (all screens are on the paper palette now) —
/// PaperCard is kept as the canonical name; GCard forwards to it for source compat.
struct PaperCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 16
    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    var body: some View {
        content
            .padding(padding)
            .background(G.kraft)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(G.kraftLine, lineWidth: 1))
    }
}

typealias GCard = PaperCard

/// The signature element: a hand-stamped ink mark standing in for one real check-in
/// or visited shop — a rotated double ring in Stamp Red, never a locked/greyed icon.
/// `symbol` is either a single letter (shop initial) rendered in the serif display
/// face, or an SF Symbol name when `isSymbolName` is true.
struct StampMark: View {
    let symbol: String
    var isSymbolName: Bool = false
    var size: CGFloat = 54
    var rotation: Double = -8

    var body: some View {
        ZStack {
            Circle()
                .stroke(G.stampRed, lineWidth: 2.5)
                .frame(width: size, height: size)
            Circle()
                .stroke(G.stampRed.opacity(0.35), lineWidth: 1)
                .frame(width: size - 9, height: size - 9)
            if isSymbolName {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.32, weight: .semibold))
            } else {
                Text(symbol)
                    .font(G.serif(size * 0.34, weight: .bold))
            }
        }
        .foregroundStyle(G.stampRed)
        .rotationEffect(.degrees(rotation))
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
                Text(title).font(G.sans(16, weight: .semibold))
            }
            .foregroundStyle(style == .gold ? G.parchment : G.darkRoast)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background {
                switch style {
                case .gold:    RoundedRectangle(cornerRadius: 14).fill(G.stampRed)
                case .outline: RoundedRectangle(cornerRadius: 14).stroke(G.stampRed, lineWidth: 1.5)
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
                .foregroundStyle(G.stampRed)
            }
            Text(String(format: "%.1f", rating))
                .font(G.mono(size))
                .foregroundStyle(G.darkRoast)
                .padding(.leading, 2)
        }
    }
}

struct TagChip: View {
    let label: String
    var icon: String? = nil
    var body: some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon).font(.system(size: 10)) }
            Text(label).font(G.sans(11, weight: .medium))
        }
        .foregroundStyle(G.darkRoast)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(G.kraft)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(G.kraftLine, lineWidth: 1))
    }
}

struct AvatarView: View {
    let name: String
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            Circle().fill(G.parchment)
            Text(String(name.prefix(1)).uppercased())
                .font(G.serif(size * 0.4, weight: .bold))
                .foregroundStyle(G.darkRoast)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(G.kraftLine, lineWidth: 1))
    }
}
