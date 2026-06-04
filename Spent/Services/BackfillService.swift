import SwiftUI
import DeviceActivity
import FamilyControls
import ManagedSettings

// MARK: - Shared types (mirror SpentActivityReport target)

struct BackfillDay: Codable {
    var date: TimeInterval     // start-of-day epoch
    var apps: [BackfillApp]
}

struct BackfillApp: Codable {
    var b: String // bundleID
    var n: String // displayName
    var m: Int    // minutes
    var c: String // category rawValue
}

extension DeviceActivityReport.Context {
    static let backfill = Self("backfill")
}

// MARK: - Hidden report that drives the extension to compute 30 days of history

/// Renders a daily-segmented `DeviceActivityReport` over the last 30 days, scoped
/// to the tracked app tokens. The report extension only runs while this view is
/// laid out on screen with a non-zero size, so it is shown (faintly) during import.
struct BackfillReportView: View {
    let tokens: Set<ApplicationToken>

    private var filter: DeviceActivityFilter {
        let cal = Calendar.current
        let end = cal.startOfDay(for: .now)
        let start = cal.date(byAdding: .day, value: -30, to: end) ?? end
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: end)),
            users: .all,
            devices: .all,
            applications: tokens
        )
    }

    var body: some View {
        DeviceActivityReport(.backfill, filter: filter)
    }
}

// MARK: - Reading harvested history back into receipts

enum BackfillStore {
    private static let suite = "group.app.spent"

    static var lastWriteTimestamp: Double {
        UserDefaults(suiteName: suite)?.double(forKey: "spent.backfill.ts") ?? 0
    }

    /// Loads the per-day data written by the report extension, if any.
    static func loadDays() -> [BackfillDay]? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: suite)?
            .appendingPathComponent("backfill.json"),
              let data = try? Data(contentsOf: url),
              let days = try? JSONDecoder().decode([BackfillDay].self, from: data) else {
            return nil
        }
        return days
    }
}

// MARK: - Import flow UI

/// Presented as a sheet. Mounts the report (so the extension computes history),
/// polls for completion, imports the result into history, then dismisses.
struct BackfillView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    @State private var status = "Reading the last 30 days…"
    @State private var done = false
    @State private var baseline = BackfillStore.lastWriteTimestamp
    @State private var elapsed = 0
    @State private var timer: Timer?

    private var tokens: Set<ApplicationToken> { Set(TrackedAppTokens.all()) }

    var body: some View {
        VStack(spacing: 20) {
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
            } else {
                ProgressView()
            }

            Text(status)
                .font(.system(size: 13, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            // Drives the extension. Must be laid out non-zero; kept faint + inert.
            BackfillReportView(tokens: tokens)
                .frame(height: 120)
                .opacity(0.02)
                .allowsHitTesting(false)
        }
        .padding(32)
        .fontDesign(.monospaced)
        .onAppear(perform: startPolling)
        .onDisappear { timer?.invalidate() }
    }

    private func startPolling() {
        guard !tokens.isEmpty else {
            status = "No tracked apps to import."
            done = true
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsed += 1
            if BackfillStore.lastWriteTimestamp > baseline {
                finish()
            } else if elapsed >= 15 {
                timer?.invalidate()
                status = "Couldn't read history. Screen Time may have no data for these apps, or the report extension didn't run."
            }
        }
    }

    private func finish() {
        timer?.invalidate()
        let count = appVM.importBackfill()
        status = count > 0
            ? "Imported \(count) day\(count == 1 ? "" : "s") of history."
            : "No historical usage found for these apps."
        done = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
    }
}

// MARK: - History browser

struct HistoryListView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        List {
            if appVM.receiptHistory.isEmpty {
                Text("No history yet. Import the last 30 days from Settings.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appVM.receiptHistory) { receipt in
                    HStack {
                        Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 13, design: .monospaced))
                        Spacer()
                        Text(
                            receipt.isProfitDay
                                ? "+\(CalculationEngine.formatCurrency(abs(receipt.netTotal)))"
                                : CalculationEngine.formatCurrency(receipt.netTotal)
                        )
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(receipt.isProfitDay ? .green : .red)
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(.monospaced)
    }
}
