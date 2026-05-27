import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("Unlock the full receipt.")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)

                Text("Full receipts, history, widgets.\n$1/mo.")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                if let error {
                    Text(error)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await purchase() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(Color(.systemBackground))
                    } else if appVM.storeKit.products.isEmpty {
                        Text("Loading...")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    } else {
                        Text("Subscribe for $1/mo")
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    }
                }
                .disabled(appVM.storeKit.products.isEmpty || isLoading)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.primary)
                .foregroundStyle(.background)
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Button {
                    Task { try? await appVM.storeKit.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Button { dismiss() } label: {
                    Text("Not now")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .task {
            if appVM.storeKit.products.isEmpty {
                await appVM.storeKit.loadProducts()
            }
        }
    }

    // MARK: - Actions

    private func purchase() async {
        guard let product = appVM.storeKit.products.first else {
            self.error = "Products unavailable. Please try again."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let purchased = try await appVM.storeKit.purchase(product)
            if purchased { dismiss() }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
