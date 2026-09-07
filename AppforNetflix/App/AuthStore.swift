import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var isAuthenticated: Bool = false
    @Published var lastErrorMessage: String?
    @Published var lastNoticeMessage: String?
    @Published private(set) var isProcessing: Bool = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
            }
        }
        isAuthenticated = Auth.auth().currentUser != nil
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Sign Up

    @discardableResult
    func signUp(name: String, email: String, password: String, settings: SettingsStore) async -> Bool {
        let cleanEmail = AuthValidator.cleanEmail(email)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            lastErrorMessage = L10n.string("Please enter your name.")
            return false
        }
        guard AuthValidator.isValidEmail(cleanEmail) else {
            lastErrorMessage = L10n.string("Please enter a valid email address.")
            return false
        }
        guard AuthValidator.isValidPassword(password) else {
            lastErrorMessage = L10n.string("Password must be at least 6 characters long.")
            return false
        }

        isProcessing = true
        lastErrorMessage = nil
        lastNoticeMessage = nil
        defer { isProcessing = false }

        let user: User
        do {
            user = try await Auth.auth()
                .createUser(withEmail: cleanEmail, password: password)
                .user
        } catch let error as NSError {
            Self.logFirebaseError(error, operation: "Sign Up")
            lastErrorMessage = Self.firebaseErrorMessage(error)
            return false
        }

        // Account creation also signs the Firebase user in. Record that success
        // before attempting the separate display-name update so a profile-sync
        // failure can never turn a created account into a failed sign-up in the UI.
        settings.userName = cleanName
        settings.userEmail = user.email ?? cleanEmail
        isAuthenticated = true
        lastErrorMessage = nil

        do {
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = cleanName
            try await changeRequest.commitChanges()
        } catch let error as NSError {
            // The authenticated account is valid even if this optional profile
            // field could not be synchronized. Keep the supplied name locally
            // and allow a later profile edit to retry the remote update.
            Self.logFirebaseError(error, operation: "Profile Sync")
        }

        return true
    }

    // MARK: - Sign In

    @discardableResult
    func signIn(email: String, password: String, settings: SettingsStore) async -> Bool {
        let cleanEmail = AuthValidator.cleanEmail(email)

        guard AuthValidator.isValidEmail(cleanEmail) else {
            lastErrorMessage = L10n.string("Please enter a valid email address.")
            return false
        }
        guard !password.isEmpty else {
            lastErrorMessage = L10n.string("Please enter your password.")
            return false
        }

        isProcessing = true
        lastErrorMessage = nil
        lastNoticeMessage = nil
        defer { isProcessing = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: cleanEmail, password: password)

            settings.userEmail = cleanEmail
            settings.userName = result.user.displayName
                ?? cleanEmail.components(separatedBy: "@").first
                ?? "User"
            isAuthenticated = true
            lastErrorMessage = nil
            return true

        } catch let error as NSError {
            Self.logFirebaseError(error, operation: "Sign In")
            lastErrorMessage = Self.firebaseErrorMessage(error)
            return false
        }
    }

    // MARK: - Password Reset

    func sendPasswordReset(email: String) async {
        let cleanEmail = AuthValidator.cleanEmail(email)

        guard AuthValidator.isValidEmail(cleanEmail) else {
            lastErrorMessage = L10n.string("Please enter a valid email address.")
            return
        }

        isProcessing = true
        lastErrorMessage = nil
        lastNoticeMessage = nil
        defer { isProcessing = false }

        do {
            try await Auth.auth().sendPasswordReset(withEmail: cleanEmail)
            lastNoticeMessage = L10n.string("Password reset email sent.")
        } catch let error as NSError {
            Self.logFirebaseError(error, operation: "Password Reset")
            lastErrorMessage = Self.firebaseErrorMessage(error)
        }
    }

    // MARK: - Profile

    @discardableResult
    func updateProfile(name: String, email: String, settings: SettingsStore) async -> Bool {
        guard let user = Auth.auth().currentUser else {
            lastErrorMessage = L10n.string("Please sign in again to update your profile.")
            return false
        }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = AuthValidator.cleanEmail(email)
        guard !cleanName.isEmpty else {
            lastErrorMessage = L10n.string("Please enter your name.")
            return false
        }
        guard AuthValidator.isValidEmail(cleanEmail) else {
            lastErrorMessage = L10n.string("Please enter a valid email address.")
            return false
        }

        isProcessing = true
        lastErrorMessage = nil
        lastNoticeMessage = nil
        defer { isProcessing = false }

        do {
            if user.displayName != cleanName {
                let request = user.createProfileChangeRequest()
                request.displayName = cleanName
                try await request.commitChanges()
            }

            settings.userName = cleanName

            if cleanEmail.caseInsensitiveCompare(user.email ?? "") != .orderedSame {
                try await user.sendEmailVerification(beforeUpdatingEmail: cleanEmail)
                lastNoticeMessage = L10n.string("Check your new email address to confirm the change.")
            } else {
                settings.userEmail = cleanEmail
                lastNoticeMessage = L10n.string("Profile updated.")
            }
            return true
        } catch let error as NSError {
            Self.logFirebaseError(error, operation: "Profile Update")
            lastErrorMessage = Self.firebaseErrorMessage(error)
            return false
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            lastErrorMessage = nil
        } catch let error as NSError {
            Self.logFirebaseError(error, operation: "Sign Out")
            lastErrorMessage = L10n.string("Failed to sign out.")
        }
    }

    // MARK: - Delete Account
    @discardableResult
    func deleteAccount(settings: SettingsStore) async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }

        isProcessing = true
        lastErrorMessage = nil
        defer { isProcessing = false }

        do {
            try await user.delete()
            isAuthenticated = false
            lastErrorMessage = nil
            settings.clearAccountData()
            return true
        } catch let error as NSError {
            Self.logFirebaseError(error, operation: "Delete Account")
            if let code = AuthErrorCode(rawValue: error.code), code == .requiresRecentLogin {
                lastErrorMessage = L10n.string("For your security, please sign out and sign in again before deleting your account.")
            } else {
                lastErrorMessage = Self.firebaseErrorMessage(error)
            }
            return false
        }
    }

    // MARK: - Session Restore

    func restoreSession(settings: SettingsStore) {
        guard let user = Auth.auth().currentUser else { return }
        // Firebase is the source of truth. Always refresh the cached profile so
        // verified email changes are reflected after the next app launch.
        let cachedName = settings.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.userEmail = user.email ?? settings.userEmail
        settings.userName = user.displayName
            ?? (!cachedName.isEmpty ? cachedName : nil)
            ?? user.email?.components(separatedBy: "@").first
            ?? "User"
    }

    // MARK: - Error Mapping

    private static func firebaseErrorMessage(_ error: NSError) -> String {
        guard let code = AuthErrorCode(rawValue: error.code) else {
            return userFacingDescription(for: error)
        }
        switch code {
        case .emailAlreadyInUse:
            return L10n.string("An account already exists with this email.")
        case .invalidEmail:
            return L10n.string("The email address is badly formatted.")
        case .weakPassword:
            return L10n.string("Password is too weak. Use at least 6 characters.")
        case .userNotFound:
            return L10n.string("No account found. Please check your email or Sign Up.")
        case .wrongPassword, .invalidCredential:
            return L10n.string("Incorrect email or password.")
        case .networkError:
            return L10n.string("Network error. Check your internet connection.")
        case .tooManyRequests:
            return L10n.string("Too many failed attempts. Please try again later.")
        case .operationNotAllowed, .internalError:
            return L10n.string("Server error. Make sure Email/Password Auth is enabled in your Firebase Console.")
        case .userDisabled:
            return userFacingDescription(for: error)
        case .requiresRecentLogin:
            return userFacingDescription(for: error)
        case .keychainError:
            return userFacingDescription(for: error)
        default:
            return userFacingDescription(for: error)
        }
    }

    private static func userFacingDescription(for error: NSError) -> String {
        let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty
            ? L10n.string("Something went wrong. Please try again.")
            : description
    }

    private static func logFirebaseError(_ error: NSError, operation: String) {
#if DEBUG
        print(
            "🔥 Firebase \(operation) Error "
            + "[Domain: \(error.domain), Code: \(error.code)]: "
            + "\(error.localizedDescription) | UserInfo: \(error.userInfo)"
        )
#endif
    }
}
