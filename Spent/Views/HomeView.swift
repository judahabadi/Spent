import SwiftUI
import DeviceActivity

struct HomeView: View {
    private var filter: DeviceActivityFilter {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        return DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: startOfDay, end: now)),
            users: .all,
            devices: .init([.iPhone, .iPad])
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                DeviceActivityReport(.totalActivity, filter: filter)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
