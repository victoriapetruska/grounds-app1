import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var auth: AuthService
    @State private var page = 0
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = true

    let pages: [(icon: String, title: String, body: String)] = [
        ("map.fill",          "Your Coffee Map",   "Discover every specialty shop, hidden gem, and local roaster near you — all in one place."),
        ("star.fill",         "Real Reviews",      "See honest reviews and photos from real coffee lovers. Write your own and help the community."),
        ("person.3.fill",     "Find Your Crew",    "Add friends, compete on the leaderboard, and share your favorite finds."),
        ("crown.fill",        "Go Pro",            "Unlock video reviews, exclusive badges, and unlimited check-ins with Grounds Pro."),
    ]

    var body: some View {
        ZStack {
            G.espresso.ignoresSafeArea()

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
                            .fill(i == page ? G.caramel : G.border)
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.bottom, 32)

                // Auth form
                VStack(spacing: 12) {
                    if isSignUp {
                        TextField("Your name", text: $name)
                            .textFieldStyle(GroundsFieldStyle())
                    }
                    TextField("Email", text: $email)
                        .textFieldStyle(GroundsFieldStyle())
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("Password", text: $password)
                        .textFieldStyle(GroundsFieldStyle())

                    GButton(isSignUp ? "Create Account" : "Sign In", icon: "cup.and.saucer.fill") {
                        if isSignUp {
                            let uname = name.lowercased().replacingOccurrences(of: " ", with: ".")
                            auth.signUp(name: name, username: uname, email: email, password: password)
                        } else {
                            auth.signIn(email: email, password: password)
                        }
                    }
                    .padding(.top, 4)

                    Button {
                        withAnimation { isSignUp.toggle() }
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign in" : "New here? Create account")
                            .font(G.body(13))
                            .foregroundStyle(G.latte)
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
            ZStack {
                Circle().fill(G.caramelGrad).frame(width: 110, height: 110)
                Image(systemName: data.icon)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: G.caramel.opacity(0.4), radius: 20)

            VStack(spacing: 10) {
                Text("Grounds")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(G.cream)
                Text(data.title)
                    .font(G.title(22))
                    .foregroundStyle(G.latte)
                Text(data.body)
                    .font(G.body(15))
                    .foregroundStyle(G.muted)
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
            .font(G.body(15))
            .foregroundStyle(G.cream)
            .padding(14)
            .background(G.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(G.border, lineWidth: 1))
    }
}
