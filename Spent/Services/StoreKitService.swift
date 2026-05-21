import Foundation
import StoreKit

@Observable
final class StoreKitService {
    var isSubscribed = false
    var isTrialing = false
    var subscriptionExpiry: Date?
    var products: [Product] = []
    var purchaseError: Error?

    private var updateListenerTask: Task<Void, Error>?

    static let standardProductID = "com.spent.standard.monthly"
    static let studentProductID = "com.spent.student.monthly"

    init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await updateSubscriptionStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.standardProductID, Self.studentProductID])
        } catch {
            purchaseError = error
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func updateSubscriptionStatus() async {
        var hasActive = false
        var hasTrialing = false
        var expiry: Date?

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productType == .autoRenewable {
                if let revocation = transaction.revocationDate, revocation < .now { continue }
                hasActive = true
                expiry = transaction.expirationDate
                // Check if in trial (StoreKit 2 doesn't expose trial directly in transaction)
                // Use offerType to detect introductory offer
                if transaction.offerType == .introductoryOffer {
                    hasTrialing = true
                }
            }
        }

        await MainActor.run {
            isSubscribed = hasActive
            isTrialing = hasTrialing
            subscriptionExpiry = expiry
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateSubscriptionStatus()
    }

    // In degraded mode (day 8+ without subscription)
    var isDegraded: Bool {
        !isSubscribed && !isTrialing
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                guard let transaction = try? self.checkVerified(result) else { continue }
                await self.updateSubscriptionStatus()
                await transaction.finish()
            }
        }
    }
}
