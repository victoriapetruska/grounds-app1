import SwiftUI

@main
struct GroundsApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var store = SubscriptionManager()
    @StateObject private var community = CommunityService()

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
            .preferredColorScheme(.dark)
            .onAppear { store.attach(auth: auth) }
        }
    }
}
