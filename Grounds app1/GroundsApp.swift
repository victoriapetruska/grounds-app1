import SwiftUI

@main
struct GroundsApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var store = SubscriptionManager()
    @StateObject private var community = CommunityService()
    @StateObject private var social = SocialService()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoggedIn {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(auth)
            .environmentObject(store)
            .environmentObject(community)
            .environmentObject(social)
            .preferredColorScheme(.dark)
            .onAppear {
                store.attach(auth: auth)
                if auth.isLoggedIn { syncProfile() }
            }
            .onChange(of: auth.isLoggedIn) { isLoggedIn in
                guard isLoggedIn else { return }
                syncProfile()
            }
        }
    }

    private func syncProfile() {
        Task {
            await social.upsertProfile(
                userID: auth.currentUser.id, username: auth.currentUser.username,
                name: auth.currentUser.name, bio: auth.currentUser.bio
            )
        }
    }
}
