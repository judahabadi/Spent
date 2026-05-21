import SwiftUI

@main
struct SpentApp: App {
    @State private var appVM = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appVM)
                .preferredColorScheme(nil) // follows system
        }
    }
}

struct RootView: View {
    @Environment(AppViewModel.self) private var appVM

    var body: some View {
        Group {
            if !appVM.auth.isSignedIn {
                OnboardingView()
            } else if appVM.screenTime.authorizationStatus == .notDetermined || appVM.screenTime.authorizationStatus == .denied {
                PermissionDeniedView()
            } else {
                ReceiptView()
            }
        }
        .task {
            await appVM.initialize()
        }
    }
}
