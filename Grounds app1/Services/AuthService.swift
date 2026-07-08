import SwiftUI
import Combine

class AuthService: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User = User.placeholder

    // MARK: - Auth Actions
    func signIn(email: String, password: String) {
        // In production: call your backend auth endpoint
        // For now we use the mock user
        withAnimation(.easeInOut(duration: 0.3)) {
            currentUser = User.placeholder
            isLoggedIn  = true
        }
    }

    func signUp(name: String, username: String, email: String, password: String) {
        // In production: create account via backend
        let user = User(
            id:             UUID().uuidString,
            name:           name,
            username:       username,
            bio:            "",
            avatarURL:      nil,
            visitedShopIDs: [],
            checkInCount:   0,
            reviewCount:    0,
            friendIDs:      [],
            badges:         [],
            isPremium:      false,
            joinDate:       Date(),
            favoriteShopIDs:[],
            homeCity:       ""
        )
        withAnimation(.easeInOut(duration: 0.3)) {
            currentUser = user
            isLoggedIn  = true
        }
    }

    func signOut() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isLoggedIn = false
        }
    }

    // MARK: - Pro Upgrade
    func upgradeToPro() {
        var updated = currentUser
        updated.isPremium = true
        currentUser = updated
    }

    // MARK: - Profile Updates
    func updateBio(_ bio: String) {
        var updated = currentUser
        updated.bio = bio
        currentUser = updated
    }
}
