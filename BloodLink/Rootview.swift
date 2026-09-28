import SwiftUI

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var notificationManager: NotificationManager

    var body: some View {
        Group {
            if authViewModel.userSession == nil {
                LoginView()
            } else if let role = authViewModel.userRole {
                switch role {
                case .requester:
                    RequesterDashboardView()
                case .donor:
                    DonorDashboardView()
                case .admin:
                    AdminDashboardView()
                }
            } else {
                ProgressView("Loading...")
                    .task {
                        if let uid = authViewModel.userSession?.uid {
                            await authViewModel.fetchUserRole(uid: uid)
                        }
                    }
            }
        }
        .overlay(alignment: .top) {
            if let banner = notificationManager.banner {
                NotificationBannerView(item: banner) {
                    notificationManager.dismiss()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: notificationManager.banner)
        .onAppear { syncNotifications() }
        .onChange(of: authViewModel.userRole) { _ in
            syncNotifications()
        }
    }

    // Starts watching for events when someone is logged in, stops when they log out
    private func syncNotifications() {
        if let uid = authViewModel.userSession?.uid, let role = authViewModel.userRole {
            notificationManager.start(uid: uid, role: role)
        } else {
            notificationManager.stop()
        }
    }
}
