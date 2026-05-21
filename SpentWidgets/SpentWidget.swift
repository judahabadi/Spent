import WidgetKit
import SwiftUI

// Timeline entry
struct SpentEntry: TimelineEntry {
    let date: Date
    let spentCost: Double
    let investedCredit: Double
    let netTotal: Double
    let topOffender: String
    let streak: Int
    let isDegraded: Bool
    let weeklyData: [DailyTotal] // for large widget

    struct DailyTotal: Identifiable {
        let id = UUID()
        let date: Date
        let net: Double
    }

    static let placeholder = SpentEntry(
        date: .now,
        spentCost: 14.20,
        investedCredit: 3.80,
        netTotal: 10.40,
        topOffender: "Instagram",
        streak: 5,
        isDegraded: false,
        weeklyData: []
    )
}

// Timeline provider — reads from shared App Group
struct SpentProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpentEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (SpentEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpentEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 15 minutes
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> SpentEntry {
        let defaults = UserDefaults(suiteName: "group.app.spent")
        guard let data = defaults?.data(forKey: "today.receipt"),
              let receipt = try? JSONDecoder().decode(DailyReceipt.self, from: data) else {
            return .placeholder
        }

        let subscribed = defaults?.bool(forKey: "isSubscribed") ?? false
        let streak = defaults?.integer(forKey: "currentStreak") ?? 0

        let topOffender = receipt.spentApps
            .sorted { $0.minutes > $1.minutes }
            .first?.displayName ?? "—"

        return SpentEntry(
            date: .now,
            spentCost: receipt.spentCost,
            investedCredit: receipt.investedCredit,
            netTotal: receipt.netTotal,
            topOffender: topOffender,
            streak: streak,
            isDegraded: !subscribed,
            weeklyData: []
        )
    }
}

// MARK: - Widget

struct SpentWidget: Widget {
    let kind = "SpentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpentProvider()) { entry in
            SpentWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Spent")
        .description("Track your screen time cost.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Views

struct SpentWidgetEntryView: View {
    let entry: SpentEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        case .systemLarge: largeView
        default: smallView
        }
    }

    // Small: Invested vs Spent split
    private var smallView: some View {
        ZStack {
            Color(.systemBackground)
            if entry.isDegraded {
                paywallPrompt
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SPENT")
                        .font(.system(size: 9, design: .monospaced, weight: .bold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Circle().fill(.red).frame(width: 5, height: 5)
                            Text(formatted(entry.spentCost))
                                .font(.system(size: 14, design: .monospaced, weight: .bold))
                        }
                        Text("spent")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Circle().fill(.green).frame(width: 5, height: 5)
                            Text(formatted(entry.investedCredit))
                                .font(.system(size: 14, design: .monospaced, weight: .bold))
                                .foregroundStyle(.green)
                        }
                        Text("invested")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    Text("🔥 \(entry.streak)d")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
        }
    }

    // Medium: split + top offender
    private var mediumView: some View {
        ZStack {
            Color(.systemBackground)
            if entry.isDegraded {
                paywallPrompt
            } else {
                HStack(spacing: 0) {
                    // Left: split
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TODAY")
                            .font(.system(size: 9, design: .monospaced, weight: .bold))
                            .foregroundStyle(.secondary)
                        amountRow(label: "SPENT", amount: entry.spentCost, color: .red)
                        amountRow(label: "INVESTED", amount: entry.investedCredit, color: .green)
                        Divider()
                        HStack {
                            Text(entry.netTotal > 0 ? "DUE" : "EARNED")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatted(abs(entry.netTotal)))
                                .font(.system(size: 13, design: .monospaced, weight: .bold))
                                .foregroundStyle(entry.netTotal > 0 ? .red : .green)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)

                    Divider()

                    // Right: top offender + streak
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TOP OFFENDER")
                            .font(.system(size: 9, design: .monospaced, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(entry.topOffender)
                            .font(.system(size: 13, design: .monospaced, weight: .semibold))
                            .lineLimit(2)
                        Spacer()
                        Text("🔥 \(entry.streak) day streak")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // Large: 7-day trend chart
    private var largeView: some View {
        ZStack {
            Color(.systemBackground)
            if entry.isDegraded {
                paywallPrompt
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("7-DAY SPENDING")
                        .font(.system(size: 10, design: .monospaced, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Simple bar chart
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(entry.weeklyData) { day in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(day.net > 0 ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                                    .frame(height: max(8, CGFloat(abs(day.net)) * 2))
                                Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 80)
                    .padding(.horizontal, 16)

                    Divider()

                    // Today summary
                    HStack {
                        amountRow(label: "TODAY SPENT", amount: entry.spentCost, color: .red)
                        Spacer()
                        amountRow(label: "INVESTED", amount: entry.investedCredit, color: .green)
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                    Text("🔥 \(entry.streak) day streak")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
        }
    }

    private var paywallPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            Text("Unlock the full receipt.\n$1/mo")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func amountRow(label: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(formatted(amount))
                .font(.system(size: 13, design: .monospaced, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private func formatted(_ amount: Double) -> String {
        String(format: "$%.2f", amount)
    }
}

// Shared model stubs needed by widget extension
struct DailyReceipt: Codable {
    var id: UUID
    var date: Date
    var apps: [AppUsage]
    var hourlyRate: Double

    var spentApps: [AppUsage] { apps.filter { $0.category == .spent } }
    var investedApps: [AppUsage] { apps.filter { $0.category == .invested } }

    var spentCost: Double { spentApps.reduce(0) { $0 + $1.cost(hourlyRate: hourlyRate) } }
    var investedCredit: Double { investedApps.reduce(0) { $0 + $1.cost(hourlyRate: hourlyRate) } }
    var netTotal: Double { spentCost - investedCredit }
}

struct AppUsage: Codable {
    var id: UUID
    var bundleID: String
    var displayName: String
    var minutes: Int
    var category: AppCategory

    func cost(hourlyRate: Double) -> Double { (Double(minutes) / 60.0) * hourlyRate }
}

enum AppCategory: String, Codable { case spent, invested, neutral }
