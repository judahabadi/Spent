import SwiftUI
import LocalAuthentication
import DeviceActivity

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private var todayFilter: DeviceActivityFilter {
        let start = Calendar.current.startOfDay(for: .now)
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: .now))
        )
    }

    var body: some View {
        NavigationStack {
            List {
                rateSection
                notificationsSection
                securitySection
                accountSection
                subscriptionSection
                diagnosticsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, design: .monospaced))
                }
            }
            .confirmationDialog("Delete Account", isPresented: $showDeleteConfirm) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        await appVM.auth.deleteAccount()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and all data. This cannot be undone.")
            }
        }
        .fontDesign(.monospaced)
    }

    // MARK: - Sections

    private var rateSection: some View {
        Section("Rate") {
            Picker("Mode", selection: Binding(
                get: { appVM.settings.userMode.isStudent },
                set: { isStudent in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        appVM.updateSettings { s in
                            s.userMode = isStudent
                                ? .student(currentGPA: 3.5, scale: .deviceDefault)
                                : .standard(hourlyRate: s.wage)
                        }
                    }
                }
            )) {
                Text("Standard").tag(false)
                Text("Student").tag(true)
            }
            .pickerStyle(.segmented)

            if appVM.settings.userMode.isStudent {
                HStack {
                    Text("Current GPA")
                    Spacer()
                    TextField("3.5", value: Binding(
                        get: { appVM.settings.currentGPA },
                        set: { v in appVM.updateSettings { $0.currentGPA = v } }
                    ), format: .number)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)
                }

                Picker("Scale", selection: Binding(
                    get: { appVM.settings.gpaScale },
                    set: { v in appVM.updateSettings { $0.gpaScale = v } }
                )) {
                    ForEach(GPAScale.allCases, id: \.self) { s in
                        Text(s.label).tag(s)
                    }
                }

                Stepper(
                    "Session: \(appVM.settings.studentSessionMinutes) min",
                    value: Binding(
                        get: { appVM.settings.studentSessionMinutes },
                        set: { v in appVM.updateSettings { $0.studentSessionMinutes = v } }
                    ),
                    in: 15...120,
                    step: 5
                )
            } else {
                HStack {
                    Text("Wage")
                    Spacer()
                    TextField("$20", value: Binding(
                        get: { appVM.settings.wage },
                        set: { v in appVM.updateSettings { $0.wage = v } }
                    ), format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                }

                Picker("Per", selection: Binding(
                    get: { appVM.settings.ratePeriod },
                    set: { v in appVM.updateSettings { $0.ratePeriod = v } }
                )) {
                    ForEach(SpentSettings.RatePeriod.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            DatePicker(
                "Daily receipt at",
                selection: Binding(
                    get: {
                        Calendar.current.date(
                            bySettingHour: appVM.settings.notificationHour,
                            minute: appVM.settings.notificationMinute,
                            second: 0,
                            of: .now
                        ) ?? .now
                    },
                    set: { date in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                        appVM.updateSettings {
                            $0.notificationHour = components.hour ?? 20
                            $0.notificationMinute = components.minute ?? 0
                        }
                    }
                ),
                displayedComponents: .hourAndMinute
            )
        }
    }

    private var securitySection: some View {
        Section("Security") {
            Toggle("App Lock (Face ID / Touch ID)", isOn: Binding(
                get: { appVM.settings.appLockEnabled },
                set: { v in appVM.updateSettings { $0.appLockEnabled = v } }
            ))
        }
    }

    private var accountSection: some View {
        Section("Account") {
            Button(role: .destructive) {
                appVM.auth.signOut()
                dismiss()
            } label: {
                Text("Sign Out")
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Text("Delete Account")
            }
        }
    }

    private var diagnosticsSection: some View {
        let defaults = UserDefaults(suiteName: "group.app.spent")
        let diag = defaults?.string(forKey: "spent.diagnostics") ?? "not yet run"
        let ts = defaults?.double(forKey: "spent.diagnostics.ts") ?? 0
        let timeStr = ts > 0 ? Date(timeIntervalSince1970: ts).formatted(.dateTime.hour().minute().second()) : "—"
        let monDiag = defaults?.string(forKey: "spent.monitoring.diagnostics") ?? "not started"
        let monTs = defaults?.double(forKey: "spent.monitoring.diagnostics.ts") ?? 0
        let monTimeStr = monTs > 0 ? Date(timeIntervalSince1970: monTs).formatted(.dateTime.hour().minute().second()) : "—"
        let launchTs = defaults?.double(forKey: "spent.extension.launch.ts") ?? 0
        let launchStr = launchTs > 0 ? Date(timeIntervalSince1970: launchTs).formatted(.dateTime.hour().minute().second()) : "never"
        return Section(header: Text("Screen Time Debug")) {
            VStack(alignment: .leading, spacing: 4) {
                Text("monitoring: \(monDiag)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("at: \(monTimeStr)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text("ext process launch: \(launchStr)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("makeConfig: \(diag)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("last run: \(timeStr)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            // Visible report. If "EXT OK · N apps · M min" appears here, the
            // extension launched and read data (independent of the App Group).
            // If this stays blank, the extension never launches at all.
            VStack(alignment: .leading, spacing: 4) {
                Text("live report (should show EXT OK):")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                DeviceActivityReport(.init("totalActivity"), filter: todayFilter)
                    .frame(height: 60)
                    .border(Color.secondary.opacity(0.3))
            }
            .padding(.vertical, 4)
        }
    }

    private var subscriptionSection: some View {
        Section("Subscription") {
            if appVM.storeKit.isSubscribed {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(appVM.storeKit.isTrialing ? "Free Trial" : "Active")
                        .foregroundStyle(.green)
                }
                if let expiry = appVM.storeKit.subscriptionExpiry {
                    HStack {
                        Text("Renews")
                        Spacer()
                        Text(expiry.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Restore Purchases") {
                    Task { try? await appVM.storeKit.restorePurchases() }
                }
            } else {
                Button { appVM.isShowingPaywall = true } label: {
                    Text("Unlock Full Receipt — $1/mo")
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}
