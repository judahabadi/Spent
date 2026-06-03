import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                rateSection
                notificationsSection
                securitySection
                accountSection
                subscriptionSection
                dataSection
                diagnosticSection
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

    private var dataSection: some View {
        let receipt = appVM.todayReceipt
        let appCount = receipt.apps.count
        let lastUpdate = appCount > 0
            ? receipt.date.formatted(.dateTime.hour().minute().second())
            : "not yet received"
        return Section("Screen Time Data") {
            HStack {
                Text("Last received")
                Spacer()
                Text(lastUpdate)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Apps today")
                Spacer()
                Text(appCount > 0 ? "\(appCount)" : "—")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var diagnosticSection: some View {
        let ud = UserDefaults(suiteName: "group.app.spent")
        let calls = ud?.integer(forKey: "spent.diag.calls") ?? 0
        let ts = ud?.double(forKey: "spent.diag.ts") ?? 0
        let lastCall = ts > 0
            ? Date(timeIntervalSince1970: ts).formatted(.dateTime.hour().minute().second())
            : "never"

        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.spent")
        let fileURL = containerURL?.appendingPathComponent("apps-simple.json")
        let attrs = fileURL.flatMap { try? FileManager.default.attributesOfItem(atPath: $0.path) }
        let fileSize = attrs?[.size] as? Int ?? -1
        let fileStatus = fileSize >= 0 ? "\(fileSize) bytes" : "missing"

        // Check where the extension binary actually landed in the app bundle.
        let fm = FileManager.default
        let bundlePath = Bundle.main.bundlePath
        let inPlugIns = fm.fileExists(atPath: bundlePath + "/PlugIns/SpentActivityReport.appex")
        let inExtensions = fm.fileExists(atPath: bundlePath + "/Extensions/SpentActivityReport.appex")
        let extLocation = inExtensions ? "Extensions/ ✓" : (inPlugIns ? "PlugIns/ ✗" : "NOT FOUND ✗")

        return Section("Diagnostics") {
            HStack {
                Text("Extension location")
                Spacer()
                Text(extLocation).foregroundStyle(inExtensions ? .green : .red)
            }
            HStack {
                Text("makeConfig calls")
                Spacer()
                Text("\(calls)").foregroundStyle(calls > 0 ? .green : .red)
            }
            HStack {
                Text("Last call")
                Spacer()
                Text(lastCall).foregroundStyle(.secondary)
            }
            HStack {
                Text("apps-simple.json")
                Spacer()
                Text(fileStatus).foregroundStyle(fileSize > 2 ? .green : .orange)
            }
            HStack {
                Text("Apps in receipt")
                Spacer()
                Text("\(appVM.todayReceipt.apps.count)").foregroundStyle(appVM.todayReceipt.apps.count > 0 ? .green : .red)
            }
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
