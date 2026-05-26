import SwiftUI

struct PermissionDeniedView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Spent needs access\nto Screen Time")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                step(number: 1, text: "Open the Settings app")
                step(number: 2, text: "Tap Screen Time")
                step(number: 3, text: "Tap \"Share Across Devices\" or enable for this device")
                step(number: 4, text: "Return to Spent")
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.primary)
                        .foregroundStyle(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Button {
                    Task { await appVM.screenTime.requestAuthorization() }
                } label: {
                    Text("Try Again")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func step(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number).")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 13, design: .monospaced))
        }
    }
}
