import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: SpentStore

    var body: some View {
        switch store.authorizationStatus {
        case .approved:
            TabView {
                HomeView()
                    .tabItem { Label("Today", systemImage: "clock.fill") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
        default:
            OnboardingView()
        }
    }
}
