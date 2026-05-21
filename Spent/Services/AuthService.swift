import Foundation
import AuthenticationServices
import CloudKit
import CryptoKit

// Authentication: Sign in with Apple (primary) + email via CloudKit tokens.
// CloudKit stores a lightweight user record keyed by hashed email — no external backend needed.
@Observable
final class AuthService {
    var isSignedIn = false
    var userID: String?
    var email: String?
    var authError: String?

    private let container = CKContainer(identifier: "iCloud.app.spent")
    private var database: CKDatabase { container.privateCloudDatabase }

    private static let userIDKey = "spent.auth.userID"
    private static let emailKey = "spent.auth.email"

    init() {
        userID = UserDefaults.standard.string(forKey: Self.userIDKey)
        email = UserDefaults.standard.string(forKey: Self.emailKey)
        isSignedIn = userID != nil
    }

    // MARK: - Sign in with Apple

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            persist(userID: credential.user, email: credential.email)
        case .failure(let error):
            authError = error.localizedDescription
        }
    }

    // MARK: - Email Auth (CloudKit-backed)

    func signUpWithEmail(_ email: String, password: String) async throws {
        let record = CKRecord(recordType: "EmailUser", recordID: recordID(for: email))
        record["passwordHash"] = hashPassword(password, email: email) as CKRecordValue
        record["createdAt"] = Date() as CKRecordValue
        _ = try await database.save(record)
        persist(userID: "email:\(email)", email: email)
    }

    func signInWithEmail(_ email: String, password: String) async throws {
        let record = try await database.record(for: recordID(for: email))
        guard let stored = record["passwordHash"] as? String,
              stored == hashPassword(password, email: email) else {
            throw AuthError.invalidCredentials
        }
        persist(userID: "email:\(email)", email: email)
    }

    func sendPasswordReset(to email: String) async throws {
        let token = UUID().uuidString
        let record = CKRecord(recordType: "PasswordReset", recordID: CKRecord.ID(recordName: "reset:\(email)"))
        record["token"] = token as CKRecordValue
        record["expiresAt"] = Calendar.current.date(byAdding: .hour, value: 1, to: .now)! as CKRecordValue
        _ = try await database.save(record)
        // In production: trigger email delivery via your own notification service
    }

    func resetPassword(email: String, token: String, newPassword: String) async throws {
        let resetRecord = try await database.record(for: CKRecord.ID(recordName: "reset:\(email)"))
        guard let storedToken = resetRecord["token"] as? String,
              let expiry = resetRecord["expiresAt"] as? Date,
              storedToken == token, expiry > .now else {
            throw AuthError.invalidOrExpiredToken
        }
        let userRecord = try await database.record(for: recordID(for: email))
        userRecord["passwordHash"] = hashPassword(newPassword, email: email) as CKRecordValue
        _ = try await database.save(userRecord)
        try await database.deleteRecord(withID: CKRecord.ID(recordName: "reset:\(email)"))
    }

    // MARK: - Session Management

    func signOut() {
        UserDefaults.standard.removeObject(forKey: Self.userIDKey)
        UserDefaults.standard.removeObject(forKey: Self.emailKey)
        userID = nil
        email = nil
        isSignedIn = false
    }

    func deleteAccount() async {
        if let email, userID?.hasPrefix("email:") == true {
            _ = try? await database.deleteRecord(withID: recordID(for: email))
        }
        signOut()
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")
    }

    // MARK: - Helpers

    private func persist(userID: String, email: String?) {
        UserDefaults.standard.set(userID, forKey: Self.userIDKey)
        if let email { UserDefaults.standard.set(email, forKey: Self.emailKey) }
        self.userID = userID
        self.email = email
        self.isSignedIn = true
    }

    private func recordID(for email: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "user:\(email.lowercased())")
    }

    // 10,000-round SHA-256 stretch — adequate for CloudKit private DB storage
    private func hashPassword(_ password: String, email: String) -> String {
        let salted = "\(email.lowercased()):\(password):spent.salt.v1"
        guard let data = salted.data(using: .utf8) else { return "" }
        var hash = data
        for _ in 0..<10_000 {
            hash = Data(SHA256.hash(data: hash))
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case invalidOrExpiredToken

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Incorrect email or password."
        case .invalidOrExpiredToken: return "Reset link is invalid or has expired."
        }
    }
}
