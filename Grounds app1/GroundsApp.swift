import SwiftUI

@main
struct GroundsApp: App {
    @StateObject private var auth = AuthService()

    var body: some Scene {
        WindowGroup {
            if auth.isLoggedIn {
                ContentView()
                    .environmentObject(auth)
                    .preferredColorScheme(.dark)
            } else {
                OnboardingView()
                    .environmentObject(auth)
                    .preferredColorScheme(.dark)
            }
        }
    }
}
