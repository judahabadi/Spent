import SwiftUI
import DeviceActivity

struct TotalActivityView: View {
    let model: TotalActivityModel

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Hero cost card
            VStack(alignment: .leading, spacing: 6) {
                Text("Cost Today")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(model.totalCost, format: .currency(code: currencyCode))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(formatDuration(model.totalDuration) + " on screen")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Per-app breakdown
            if !model.appItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("By App")
                        .font(.headline)
                        .padding(.bottom, 4)

                    ForEach(model.appItems.prefix(10)) { item in
                        AppRow(item: item, hourlyRate: model.hourlyRate)
                        if item.id != model.appItems.prefix(10).last?.id {
                            Divider()
                        }
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "clock.badge.checkmark",
                    description: Text("Come back after you've used your phone a bit.")
                )
                .frame(minHeight: 200)
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = Int(seconds) / 60 % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct AppRow: View {
    let item: TotalActivityModel.AppItem
    let hourlyRate: Double

    private var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

    var body: some View {
        HStack(spacing: 12) {
            Label(item.token)
                .labelStyle(.iconOnly)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Label(item.token)
                .labelStyle(.titleOnly)
                .font(.body)
                .lineLimit(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.cost(hourlyRate: hourlyRate), format: .currency(code: currencyCode))
                    .font(.subheadline.weight(.medium))
                Text(formatDuration(item.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = Int(seconds) / 60 % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
