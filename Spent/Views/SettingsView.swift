import SwiftUI

private let sharedDefaults = UserDefaults(suiteName: "group.com.spent.app")

struct SettingsView: View {
    @AppStorage("hourlyRate", store: sharedDefaults)
    private var hourlyRate: Double = 30.0

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Hourly Rate")
                        Spacer()
                        Text(hourlyRate, format: .currency(code: currencyCode))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $hourlyRate, in: 1...500, step: 1) {
                        Text("Hourly Rate")
                    } minimumValueLabel: {
                        Text("$1")
                            .font(.caption)
                    } maximumValueLabel: {
                        Text("$500")
                            .font(.caption)
                    }
                } header: {
                    Text("Your Value")
                } footer: {
                    Text("Used to calculate the cost of your screen time. \(hourlyRate, format: .currency(code: currencyCode))/hr means every hour on your phone costs you that much.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
