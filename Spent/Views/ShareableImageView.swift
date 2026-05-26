import SwiftUI

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
                            Text(app.displayName.uppercased())
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
    @MainActor
    func render() -> UIImage {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 3.0
        return renderer.uiImage ?? UIImage()
    }
}
