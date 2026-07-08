import SwiftUI

@main
struct GroundsApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var store = SubscriptionManager()

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
            .preferredColorScheme(.dark)
            .onAppear { store.attach(auth: auth) }
        }
    }
}
