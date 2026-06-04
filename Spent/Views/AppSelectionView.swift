import SwiftUI
import FamilyControls

struct AppSelectionView: View {
    @Environment(AppViewModel.self) private var appVM
    @Environment(\.dismiss) private var dismiss

    @State private var selection = FamilyActivitySelection()
    @State private var step = 0  // 0 = pick, 1 = name
    @State private var names: [String] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            if step == 0 {
                pickerStep
            } else {
                namingStep
            }
        }
        .fontDesign(.monospaced)
    }

    private var pickerStep: some View {
        FamilyActivityPicker(selection: $selection)
            .navigationTitle("Select Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, design: .monospaced))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Next") {
                        let count = selection.applicationTokens.count
                        names = (0..<count).map { "App \($0 + 1)" }
                        step = 1
                    }
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .disabled(selection.applicationTokens.isEmpty)
                }
            }
    }

    private var namingStep: some View {
        List {
            Section {
                ForEach(names.indices, id: \.self) { i in
                    TextField("App \(i + 1)", text: $names[i])
                        .font(.system(size: 14, design: .monospaced))
                }
            } header: {
                Text("Name each app you selected.\nYou can change these later in Settings.")
                    .font(.system(size: 12, design: .monospaced))
                    .textCase(nil)
            }
        }
        .navigationTitle("Name Your Apps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { step = 0 }
                    .font(.system(size: 14, design: .monospaced))
            }
            ToolbarItem(placement: .confirmationAction) {
                if isLoading {
                    ProgressView()
                } else {
                    Button("Done") { save() }
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
            }
        }
    }

    private func save() {
        isLoading = true
        let finalNames = names.map { $0.trimmingCharacters(in: .whitespaces) }
            .enumerated()
            .map { i, n in n.isEmpty ? "App \(i + 1)" : n }
        appVM.screenTime.setupAppTracking(selection: selection, names: finalNames)
        appVM.reloadTrackedApps()
        dismiss()
    }
}
