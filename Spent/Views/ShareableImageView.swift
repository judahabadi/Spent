import SwiftUI
import UIKit
import FamilyControls
import ManagedSettings

struct ShareableImageView: View {
    let receipt: DailyReceipt
    let streak: StreakRecord

    var topThreeApps: [AppUsage] {
        Array(receipt.spentApps.sorted { $0.minutes > $1.minutes }.prefix(3))
    }

    var body: some View {
        ZStack {
            Color.black

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("SPENT")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(receipt.date.formatted(date: .complete, time: .omitted).uppercased())
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.gray)
                }
                .padding(.top, 32)
                .padding(.bottom, 24)

                Divider().background(Color.white.opacity(0.3))

                // Top apps
                VStack(spacing: 0) {
                    ForEach(topThreeApps) { app in
                        HStack {
                            AppLabel(app: app)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer()
                            Text(app.formattedDuration)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.gray)
                            Text(CalculationEngine.formatCurrency(app.cost(hourlyRate: receipt.hourlyRate)))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(width: 65, alignment: .trailing)
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                    }
                }

                Divider().background(Color.white.opacity(0.3))

                // Net total
                HStack {
                    Text(receipt.isProfitDay ? "YOU EARNED" : "TOTAL DUE")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(
                        receipt.isProfitDay
                            ? "+\(CalculationEngine.formatCurrency(abs(receipt.netTotal)))"
                            : CalculationEngine.formatCurrency(receipt.netTotal)
                    )
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(receipt.isProfitDay ? .green : .red)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)

                // Streak
                Text("\u{1F525} \(streak.currentStreak) day streak")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.gray)
                    .padding(.bottom, 24)

                Divider().background(Color.white.opacity(0.3))

                Text("spent app")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.gray.opacity(0.6))
                    .padding(.vertical, 12)
            }
        }
        .frame(width: 400, height: 400)
    }
}

// MARK: - UIImage Rendering

extension ShareableImageView {
    /// Renders the receipt card to a UIImage at 3× scale for sharing.
    ///
    /// Uses a UIKit hierarchy snapshot rather than `ImageRenderer` because the
    /// app name/icon drawn by `Label(ApplicationToken)` is rendered out-of-process
    /// by the system. `ImageRenderer` captures those labels blank; capturing the
    /// composited pixels of an on-screen view with `drawHierarchy(afterScreenUpdates:)`
    /// preserves them.
    @MainActor
    func render() -> UIImage {
        let size = CGSize(width: 400, height: 400)
        let controller = UIHostingController(rootView: self)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .black

        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ??
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        guard let window = scene?.keyWindow ?? scene?.windows.first else {
            // No window available — fall back to ImageRenderer (token labels may be blank).
            let renderer = ImageRenderer(content: self)
            renderer.scale = 3.0
            return renderer.uiImage ?? UIImage()
        }

        // Place the view inside the window but below the visible area so the system
        // renders the token labels, then snapshot the real pixels.
        controller.view.frame = CGRect(x: 0, y: window.bounds.height, width: size.width, height: size.height)
        window.addSubview(controller.view)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        controller.view.removeFromSuperview()
        return image
    }
}

// MARK: - Shared App Label

/// Displays a tracked app's real name and icon via `Label(ApplicationToken)` when
/// the token is available, falling back to the stored display name otherwise.
struct AppLabel: View {
    let app: AppUsage
    var uppercasedFallback: Bool = true

    var body: some View {
        if let token = TrackedAppTokens.token(for: app) {
            Label(token)
                .labelStyle(.titleAndIcon)
        } else {
            Text(uppercasedFallback ? app.displayName.uppercased() : app.displayName)
        }
    }
}

/// Resolves the persisted `ApplicationToken`s for tracked apps.
enum TrackedAppTokens {
    private static let suite = "group.app.spent"

    static func all() -> [ApplicationToken] {
        guard let data = UserDefaults(suiteName: suite)?.data(forKey: "spent.apps.tokens"),
              let tokens = try? JSONDecoder().decode([ApplicationToken].self, from: data) else {
            return []
        }
        return tokens
    }

    /// Tracked apps store their index in `bundleID` as "tracked.<i>".
    static func token(for app: AppUsage) -> ApplicationToken? {
        let prefix = "tracked."
        guard app.bundleID.hasPrefix(prefix),
              let index = Int(app.bundleID.dropFirst(prefix.count)) else { return nil }
        let tokens = all()
        return index < tokens.count ? tokens[index] : nil
    }
}
