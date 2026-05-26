import SwiftUI
import FamilyControls

@main
struct SpentApp: App {
    @StateObject private var store = SpentStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
