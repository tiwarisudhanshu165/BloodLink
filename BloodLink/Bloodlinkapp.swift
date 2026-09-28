import SwiftUI
import FirebaseCore

@main
struct BloodLinkApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var notificationManager = NotificationManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .environmentObject(notificationManager)
        }
    }
}
