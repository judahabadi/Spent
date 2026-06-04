import SwiftUI
import LocalAuthentication
import FamilyControls

struct SettingsView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showAppSelection = false
    @State private var showBackfill = false

    var body: some View {
        NavigationStack {
            List {
                rateSection
                trackedAppsSection
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

    private var trackedAppsSection: some View {
        let count = appVM.trackedAppCount
        return Section("Tracked Apps") {
            HStack {
                Text("Apps tracked")
                Spacer()
                Text(count > 0 ? "\(count)" : "None")
                    .foregroundStyle(.secondary)
            }
            Button {
                showAppSelection = true
            } label: {
                Text(count > 0 ? "Change apps" : "Select apps to track")
                    .foregroundStyle(.primary)
            }
            .sheet(isPresented: $showAppSelection) {
                AppSelectionView()
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
            NavigationLink {
                HistoryListView()
            } label: {
                HStack {
                    Text("History")
                    Spacer()
                    Text(appVM.receiptHistory.isEmpty ? "—" : "\(appVM.receiptHistory.count) days")
                        .foregroundStyle(.secondary)
                }
            }
            Button {
                showBackfill = true
            } label: {
                Text("Import last 30 days")
                    .foregroundStyle(.primary)
            }
            .disabled(appVM.trackedAppCount == 0)
            .sheet(isPresented: $showBackfill) {
                BackfillView()
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

        // ext-alive.txt is written at the TOP of makeConfiguration (before data iteration)
        // so its presence proves the extension process launched even if the app group fails.
        let aliveURL = containerURL?.appendingPathComponent("ext-alive.txt")
        let aliveContent = aliveURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        let aliveStatus: String = {
            guard let s = aliveContent, let pipe = s.firstIndex(of: "|") else { return "never" }
            let tsVal = Double(s[s.startIndex..<pipe]) ?? 0
            guard tsVal > 0 else { return "never" }
            return Date(timeIntervalSince1970: tsVal).formatted(.dateTime.hour().minute().second())
        }()

        // Check where the extension binary actually landed in the app bundle.
        let fm = FileManager.default
        let bundlePath = Bundle.main.bundlePath
        let inPlugIns = fm.fileExists(atPath: bundlePath + "/PlugIns/SpentActivityReport.appex")
        let inExtensions = fm.fileExists(atPath: bundlePath + "/Extensions/SpentActivityReport.appex")
        let extLocation = inExtensions ? "Extensions/ ✓" : (inPlugIns ? "PlugIns/ ✗" : "NOT FOUND ✗")

        // FamilyControls authorization status
        let authStatus: String = {
            switch appVM.screenTime.authorizationStatus {
            case .approved: return "approved ✓"
            case .denied: return "denied ✗"
            case .notDetermined: return "not determined"
            @unknown default: return "unknown"
            }
        }()
        let authOK = appVM.screenTime.authorizationStatus == .approved

        // Monitoring schedule diagnostic written by setupAppTracking()
        let monDiag = ud?.string(forKey: "spent.monitoring.diagnostics") ?? "not started"
        let monOK = monDiag.contains("started=1") || monDiag.contains("started=20") || monDiag.contains("tracking")

        // THE KEY PROBE: written by SpentActivityMonitor.intervalDidEnd.
        // If this is "never", DeviceActivityMonitor callbacks don't fire in individual
        // mode on this device — and the threshold pivot also won't work.
        let intervalEndDate = ud?.object(forKey: "lastIntervalEnd") as? Date
        let monitorFired = intervalEndDate.map {
            $0.formatted(.dateTime.hour().minute().second())
        } ?? "never"
        let monitorOK = intervalEndDate != nil

        // Written by SpentActivityMonitor.eventDidReachThreshold.
        // If monitorFired is non-never but this is "never", auth is working but
        // no tracked apps have reached a threshold yet (normal early in the day).
        let thresholdTs = ud?.double(forKey: "spent.threshold.ts") ?? 0
        let thresholdFired = thresholdTs > 0
            ? Date(timeIntervalSince1970: thresholdTs).formatted(.dateTime.hour().minute().second())
            : "never"
        let thresholdOK = thresholdTs > 0

        // Tracked apps count
        let trackedCount = ud?.integer(forKey: "spent.apps.count") ?? 0

        // Extension process init timestamp — written in SpentActivityReportExtension.init()
        // BEFORE makeConfiguration. Shows "never" if extension process never launches.
        let extInitTs = ud?.double(forKey: "spent.diag.ext.init") ?? 0
        let extInitStatus = extInitTs > 0
            ? Date(timeIntervalSince1970: extInitTs).formatted(.dateTime.hour().minute().second())
            : "never"

        // Read the extension's embedded provisioning profile to check what entitlements
        // are actually granted in the signed binary (family-controls + app group required).
        let extBundlePath = Bundle.main.bundlePath + "/Extensions/SpentActivityReport.appex"
        let provPath = extBundlePath + "/embedded.mobileprovision"
        let provData = FileManager.default.contents(atPath: provPath)
        let provStr = provData.flatMap { String(bytes: $0, encoding: .ascii) } ?? ""
        let provHasFC = provStr.contains("family-controls")
        let provHasAG = provStr.contains("group.app.spent")
        let provExists = provData != nil
        let provStatus: String = {
            if !provExists { return "no profile (dev build?)" }
            return "FC:\(provHasFC ? "✓" : "✗") AG:\(provHasAG ? "✓" : "✗")"
        }()
        let provOK = provHasFC && provHasAG

        // LAUNCH-FAILURE PROBES — these target WHY the extension process never
        // starts (init never fires). A report extension is launched by the OS
        // only if (a) the shipped bundle is structurally valid, (b) it is signed,
        // and (c) the DeviceActivityReport view is laid out with a non-zero size.
        let fmp = FileManager.default

        // (a) Shipped bundle structure: read the Info.plist the OS actually sees
        // (not our source plist) plus confirm the executable is present.
        let extBundle = Bundle(path: extBundlePath)
        let shippedPointID = (extBundle?.infoDictionary?["EXAppExtensionAttributes"] as? [String: Any])?["EXExtensionPointIdentifier"] as? String
        let pointIDStatus: String = {
            guard let id = shippedPointID else { return "MISSING ✗" }
            return id == "com.apple.deviceactivityui.report-extension" ? "report ✓" : id
        }()
        let pointIDOK = shippedPointID == "com.apple.deviceactivityui.report-extension"

        let exePresent = fmp.fileExists(atPath: extBundlePath + "/SpentActivityReport")

        // (b) Code signature directory must exist for the OS to launch the appex.
        let sigPresent = fmp.fileExists(atPath: extBundlePath + "/_CodeSignature")
        let bundleStatus = "exe:\(exePresent ? "✓" : "✗") sig:\(sigPresent ? "✓" : "✗")"
        let bundleOK = exePresent && sigPresent

        // (c) Rendered size of the DeviceActivityReport view, captured live in
        // ReceiptView. "0x0" or "—" means the view never got a real layout, which
        // silently prevents the OS from launching the extension.
        let reportSize = ud?.string(forKey: "spent.diag.report.size") ?? "—"
        let sizeOK = !(reportSize == "—" || reportSize.hasPrefix("0x") || reportSize.hasSuffix("x0"))

        return Section("Diagnostics") {
            HStack {
                Text("Auth status")
                Spacer()
                Text(authStatus).foregroundStyle(authOK ? .green : .red)
            }
            HStack {
                Text("Monitoring")
                Spacer()
                Text(monDiag).foregroundStyle(monOK ? .green : .orange)
            }
            HStack {
                Text("Tracked apps")
                Spacer()
                Text("\(trackedCount)").foregroundStyle(trackedCount > 0 ? .green : .red)
            }
            HStack {
                Text("Monitor last fired")
                Spacer()
                Text(monitorFired).foregroundStyle(monitorOK ? .green : .red)
            }
            HStack {
                Text("Last threshold")
                Spacer()
                Text(thresholdFired).foregroundStyle(thresholdOK ? .green : .secondary)
            }
            HStack {
                Text("Extension location")
                Spacer()
                Text(extLocation).foregroundStyle(inExtensions ? .green : .red)
            }
            HStack {
                Text("Ext provisioning")
                Spacer()
                Text(provStatus).foregroundStyle(provOK ? .green : .red)
            }
            HStack {
                Text("Ext point id")
                Spacer()
                Text(pointIDStatus).foregroundStyle(pointIDOK ? .green : .red)
            }
            HStack {
                Text("Ext bundle")
                Spacer()
                Text(bundleStatus).foregroundStyle(bundleOK ? .green : .red)
            }
            HStack {
                Text("Report view size")
                Spacer()
                Text(reportSize).foregroundStyle(sizeOK ? .green : .red)
            }
            HStack {
                Text("Ext process init")
                Spacer()
                Text(extInitStatus).foregroundStyle(extInitStatus == "never" ? .red : .green)
            }
            HStack {
                Text("Ext process alive")
                Spacer()
                Text(aliveStatus).foregroundStyle(aliveStatus == "never" ? .red : .green)
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
