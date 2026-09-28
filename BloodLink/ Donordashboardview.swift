import SwiftUI

struct DonorDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var profile: DonorProfile?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                Section("My Profile") {
                    if isLoading {
                        ProgressView()
                    } else if let profile {
                        LabeledContent("Name", value: profile.fullName)
                        LabeledContent("Blood group", value: profile.bloodGroup.rawValue)
                        LabeledContent("City", value: profile.city)
                        LabeledContent("Status", value: profile.isAvailable ? "Available" : "Not available")
                    } else {
                        Text("You haven't set up your donor profile yet.")
                            .foregroundColor(.secondary)
                    }

                    NavigationLink(profile == nil ? "Set up profile" : "Edit profile") {
                        DonorProfileView()
                    }
                }

                Section("Incoming Requests") {
                    Text("Matching blood requests will appear here (Phase 4).")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Donor")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log Out") {
                        authViewModel.signOut()
                    }
                }
            }
            .onAppear {
                Task { await loadProfile() }
            }
        }
    }

    private func loadProfile() async {
        guard let uid = authViewModel.userSession?.uid else { return }
        profile = try? await DataService.shared.fetchDonorProfile(uid: uid)
        isLoading = false
    }
}
