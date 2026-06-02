import SwiftUI

struct ReceiptView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var showCalendar = false

    var body: some View {
        ZStack {
            GeometryReader { geo in
                if geo.size.width > 700 {
                    HStack(spacing: 0) {
                        receiptPane
                            .frame(maxWidth: .infinity)
                        Divider()
                        statsPanel
                            .frame(width: 300)
                    }
                } else {
                    receiptPane
                }
            }
            .background(Color(.systemBackground))
        }
        .fullScreenCover(isPresented: Bindable(appVM).isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: Bindable(appVM).isShowingPaywall) {
            PaywallView()
        }
    }

    private var receiptPane: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerBar
                periodToggle
                receiptCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Spacer()
            Button {
                appVM.isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.primary)
            }
            .padding(.trailing, 20)
        }
        .frame(height: 50)
    }

    private var periodToggle: some View {
        HStack(spacing: 0) {
            ForEach(ReceiptPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appVM.selectedPeriod = period
                    }
                } label: {
                    Text(period.rawValue.uppercased())
                        .font(.system(.caption, design: .monospaced, weight: appVM.selectedPeriod == period ? .bold : .regular))
                        .foregroundStyle(appVM.selectedPeriod == period ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var receiptCard: some View {
        VStack(spacing: 0) {
            receiptHeader
            Divider()

            if !appVM.todayReceipt.spentApps.isEmpty {
                sectionHeader("SPENT")
                ForEach(appVM.todayReceipt.spentApps.sorted { $0.minutes > $1.minutes }) { app in
                    lineItem(app: app, isInvested: false)
                }
            }

            if !appVM.todayReceipt.investedApps.isEmpty {
                sectionHeader("INVESTED")
                ForEach(appVM.todayReceipt.investedApps.sorted { $0.minutes > $1.minutes }) { app in
                    lineItem(app: app, isInvested: true)
                }
            }

            if !appVM.todayReceipt.neutralApps.isEmpty {
                sectionHeader("NEUTRAL")
                ForEach(appVM.todayReceipt.neutralApps.sorted { $0.minutes > $1.minutes }) { app in
                    neutralLineItem(app: app)
                }
            }

            Divider()
            totalsSection
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private var receiptHeader: some View {
        VStack(spacing: 4) {
            Text("SPENT")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
            Text(appVM.selectedDate.formatted(date: .complete, time: .omitted).uppercased())
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func lineItem(app: AppUsage, isInvested: Bool) -> some View {
        HStack {
            Text(app.displayName.uppercased())
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
            Spacer()
            Text(app.formattedDuration)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            if appVM.isDegraded {
                Text("$--.--")
                    .font(.system(size: 11, design: .monospaced))
                    .blur(radius: 3)
                    .overlay(Image(systemName: "lock.fill").font(.system(size: 8)))
                    .frame(width: 70, alignment: .trailing)
            } else {
                let cost = app.cost(hourlyRate: appVM.todayReceipt.hourlyRate)
                Text(isInvested ? "-\(CalculationEngine.formatCurrency(cost))" : CalculationEngine.formatCurrency(cost))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(isInvested ? .green : .primary)
                    .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func neutralLineItem(app: AppUsage) -> some View {
        HStack {
            Text(app.displayName.uppercased())
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
            Spacer()
            Text(app.formattedDuration)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var totalsSection: some View {
        VStack(spacing: 0) {
            totalRow(label: "SUBTOTAL SPENT", value: appVM.todayReceipt.spentCost, negative: false)
            totalRow(label: "INVESTED CREDIT", value: appVM.todayReceipt.investedCredit, negative: true)
            Divider().padding(.vertical, 6)
            netTotalRow
            streakRow
            trialBanner
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var trialBanner: some View {
        if !appVM.storeKit.isSubscribed, let trialStart = appVM.settings.trialStartDate {
            let daysUsed = Calendar.current.dateComponents([.day], from: trialStart, to: .now).day ?? 0
            let daysLeft = max(0, 7 - daysUsed)
            if daysLeft > 0 {
                Button { appVM.isShowingPaywall = true } label: {
                    Text("FREE TRIAL — \(daysLeft) DAY\(daysLeft == 1 ? "" : "S") LEFT")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
        }
    }

    private func totalRow(label: String, value: Double, negative: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
            Spacer()
            if appVM.isDegraded {
                Text("$--.--")
                    .font(.system(size: 11, design: .monospaced))
                    .blur(radius: 3)
            } else {
                Text(negative ? "-\(CalculationEngine.formatCurrency(value))" : CalculationEngine.formatCurrency(value))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(negative ? .green : .primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }

    private var netTotalRow: some View {
        let net = appVM.todayReceipt.netTotal
        let isProfitDay = appVM.todayReceipt.isProfitDay

        return HStack {
            Text(isProfitDay ? "YOU EARNED" : "TOTAL DUE")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
            Spacer()
            if appVM.isDegraded {
                Button { appVM.isShowingPaywall = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill").font(.system(size: 10))
                        Text("$--.--")
                    }
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                }
            } else {
                Text(isProfitDay ? "+\(CalculationEngine.formatCurrency(abs(net)))" : CalculationEngine.formatCurrency(net))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(isProfitDay ? .green : .red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var streakRow: some View {
        HStack {
            Spacer()
            Text("STREAK: \u{1F525} \(appVM.streak.currentStreak) DAYS")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 8)
    }

    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("STATS")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .padding(.top, 60)

            VStack(alignment: .leading, spacing: 8) {
                Text("CURRENT STREAK")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("\u{1F525} \(appVM.streak.currentStreak) days")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("BEST STREAK")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("\(appVM.streak.longestStreak) days")
                    .font(.system(size: 18, design: .monospaced))
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
