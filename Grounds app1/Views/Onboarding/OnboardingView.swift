import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var auth: AuthService
    @State private var page = 0

    let pages: [(icon: String, title: String, body: String)] = [
        ("map.fill",          "Your Coffee Map",   "Discover every specialty shop, hidden gem, and local roaster near you — all in one place."),
        ("star.fill",         "Real Reviews",      "See honest reviews and photos from real coffee lovers. Write your own and help the community."),
        ("person.3.fill",     "Find Your Crew",    "Add friends, compete on the leaderboard, and share your favorite finds."),
        ("crown.fill",        "Go Pro",            "Unlock video reviews and unlimited check-ins with Grounds Pro."),
    ]

    var body: some View {
        ZStack {
            G.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                // Slides
                TabView(selection: $page) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        OnboardSlide(data: pages[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 420)

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? G.stampRed : G.kraftLine)
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.bottom, 32)

                // Sign in with Apple
                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        auth.handleSignInWithApple(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(G.sans(12))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }
}

struct OnboardSlide: View {
    let data: (icon: String, title: String, body: String)
    var body: some View {
        VStack(spacing: 24) {
            StampMark(symbol: data.icon, isSymbolName: true, size: 100, rotation: -6)

            VStack(spacing: 10) {
                Text("Grounds")
                    .font(G.serif(32, weight: .bold))
                    .foregroundStyle(G.darkRoast)
                Text(data.title)
                    .font(G.sans(20, weight: .semibold))
                    .foregroundStyle(G.stampRed)
                Text(data.body)
                    .font(G.sans(15))
                    .foregroundStyle(G.lightRoast)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
        .padding(.top, 60)
    }
}

struct GroundsFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(G.sans(15))
            .foregroundStyle(G.darkRoast)
            .padding(14)
            .background(G.kraft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(G.kraftLine, lineWidth: 1))
    }
}
