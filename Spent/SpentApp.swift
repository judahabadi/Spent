import SwiftUI

@main
struct SpentApp: App {
    @State private var appVM = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appVM)
                .preferredColorScheme(nil) // follows system
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appVM.screenTime.recheckAuthorization()
                if appVM.auth.isSignedIn {
                    Task { await appVM.initialize() }
                }
            }
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
            } else if appVM.needsAppSetup {
                AppSelectionView()
            } else {
                ReceiptView()
            }
        }
        .task {
            await appVM.initialize()
        }
        .onChange(of: appVM.auth.isSignedIn) { _, isSignedIn in
            if isSignedIn {
                Task { await appVM.initialize() }
            }
        }
    }
}
