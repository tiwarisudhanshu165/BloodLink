import SwiftUI

struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

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
    }
}
