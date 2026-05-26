import Foundation
import FamilyControls

@MainActor
class SpentStore: ObservableObject {
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            print("Authorization error: \(error)")
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }
}
