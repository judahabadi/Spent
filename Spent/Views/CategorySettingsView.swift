import SwiftUI

// Lets users override the default Spent/Invested/Neutral category for each app.
struct CategorySettingsView: View {
    @Environment(AppViewModel.self) private var appVM
    @State private var classifier = CategoryClassifier.load()
    @State private var apps: [AppUsage] = []

    var body: some View {
        List {
            Section {
                Text("Social/Entertainment defaults to Spent. Productivity/Education defaults to Invested. Everything else is Neutral.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            ForEach(apps) { app in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.displayName)
                            .font(.system(size: 13, design: .monospaced))
                        Text(app.bundleID)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: Binding(
                        get: { classifier.overrides[app.bundleID] ?? classifier.classify(bundleID: app.bundleID, appleCategory: nil) },
                        set: { newCategory in
                            classifier.setOverride(bundleID: app.bundleID, category: newCategory)
                        }
                    )) {
                        ForEach(AppCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 12, design: .monospaced))
                }
            }
        }
        .navigationTitle("App Categories")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            apps = appVM.todayReceipt.apps.sorted { $0.displayName < $1.displayName }
        }
    }
}
