import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    // Start from the currently tracked selection so reopening the picker shows
    // existing apps as selected (otherwise saving would drop them).
    @State private var selection = TrackedAppTokens.savedSelection()
    @State private var isLoading = false

    // Spent tracks individual apps via per-app thresholds, so we need actual app
    // selections. Apple's "All Apps & Categories" toggle yields category tokens
    // with no application tokens, which we can't track — so require ≥1 app.
    private var canSave: Bool { !selection.applicationTokens.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FamilyActivityPicker(selection: $selection)

                if selection.applicationTokens.isEmpty && !selection.categoryTokens.isEmpty {
                    Text("Pick individual apps rather than whole categories — Spent tracks each app separately.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle("Select Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, design: .monospaced))
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Done") { save() }
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .disabled(!canSave)
                    }
                }
            }
        }
        .fontDesign(.monospaced)
    }

    private func save() {
        isLoading = true
        // Names are no longer entered by the user — the receipt renders each app's
        // real name/icon via Label(token). These defaults are only a fallback for
        // contexts where the token can't be rendered (e.g. exported images).
        let count = selection.applicationTokens.count
        let names = (0..<count).map { "App \($0 + 1)" }
        appVM.screenTime.setupAppTracking(selection: selection, names: names)
        appVM.reloadTrackedApps()
        dismiss()
    }
}
