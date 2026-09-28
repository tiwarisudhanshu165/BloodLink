import SwiftUI

struct RequesterDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack {
                Text("Requester Dashboard")
                    .font(.title)
                Text("Blood request creation and tracking will go here (Phase 3-4).")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .navigationTitle("Requester")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log Out") {
                        authViewModel.signOut()
                    }
                }
            }
        }
    }
}

