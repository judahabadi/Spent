import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: SpentStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "hourglass.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse)

                VStack(spacing: 8) {
                    Text("Spent")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text("See the real cost of your screen time")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Spacer()

            VStack(spacing: 16) {
                Button {
                    Task { await store.requestAuthorization() }
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.indigo)

                Text("Screen Time access is required to calculate costs.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 32)
    }
}
