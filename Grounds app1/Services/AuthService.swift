import SwiftUI
import Combine
import AuthenticationServices

class AuthService: NSObject, ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User = User.placeholder
    @Published var errorMessage: String?

    private let defaults = UserDefaults.standard
    private let appleUserIDKey = "appleUserIdentifier"
    private let storedUserKey  = "storedUser"

    override init() {
        super.init()
        restoreSessionIfPossible()
    }

    // MARK: - Session restore
    private func restoreSessionIfPossible() {
        guard let appleUserID = defaults.string(forKey: appleUserIDKey) else { return }

        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserID) { [weak self] state, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                switch state {
                case .authorized:
                    if let data = self.defaults.data(forKey: self.storedUserKey),
                       let user = try? JSONDecoder().decode(User.self, from: data) {
                        self.currentUser = user
                    }
                    self.isLoggedIn = true
                case .revoked, .notFound:
                    self.clearStoredSession()
                default:
                    break
                }
            }
        }
    }

    // MARK: - Sign in with Apple
    func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            let nsError = error as NSError
            // User cancelled the sheet — not a real error, don't surface it.
            if nsError.domain == ASAuthorizationError.errorDomain,
               nsError.code == ASAuthorizationError.canceled.rawValue { return }
            errorMessage = error.localizedDescription

        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Unable to sign in with Apple."
                return
            }

            let appleUserID = credential.user
            defaults.set(appleUserID, forKey: appleUserIDKey)

            var user: User
            if let data = defaults.data(forKey: storedUserKey),
               let existing = try? JSONDecoder().decode(User.self, from: data) {
                user = existing
            } else {
                // First-time sign-in: name/email are only ever provided this once.
                let fullName = credential.fullName
                let displayName = [fullName?.givenName, fullName?.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                let name = displayName.isEmpty ? "Coffee Lover" : displayName
                let username = name.lowercased().replacingOccurrences(of: " ", with: ".")

                user = User(
                    id:             appleUserID,
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
            }

            errorMessage = nil
            withAnimation(.easeInOut(duration: 0.3)) {
                currentUser = user
                isLoggedIn  = true
            }
            persistUser()
        }
    }

    func signOut() {
        clearStoredSession()
        withAnimation(.easeInOut(duration: 0.3)) {
            isLoggedIn = false
        }
    }

    private func clearStoredSession() {
        defaults.removeObject(forKey: appleUserIDKey)
        defaults.removeObject(forKey: storedUserKey)
    }

    private func persistUser() {
        if let data = try? JSONEncoder().encode(currentUser) {
            defaults.set(data, forKey: storedUserKey)
        }
    }

    // MARK: - Pro Upgrade
    func upgradeToPro() {
        currentUser.isPremium = true
        persistUser()
    }

    func setPremium(_ isPremium: Bool) {
        guard currentUser.isPremium != isPremium else { return }
        currentUser.isPremium = isPremium
        persistUser()
    }

    // MARK: - Profile Updates
    func updateBio(_ bio: String) {
        currentUser.bio = bio
        persistUser()
    }

    func updateAvatarURL(_ path: String) {
        currentUser.avatarURL = path
        persistUser()
    }
}
