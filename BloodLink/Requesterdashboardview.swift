import SwiftUI

struct RequesterDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var requests: [BloodRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("Create New Blood Request") {
                        CreateRequestView()
                    }
                }

                Section("My Requests") {
                    if isLoading {
                        ProgressView()
                    } else if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    } else if requests.isEmpty {
                        Text("No requests yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(requests) { request in
                            NavigationLink {
                                RequestDetailView(request: request)
                            } label: {
                                RequestRow(request: request)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Requester")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log Out") {
                        authViewModel.signOut()
                    }
                }
            }
            .onAppear {
                Task { await loadRequests() }
            }
        }
    }

    private func loadRequests() async {
        guard let uid = authViewModel.userSession?.uid else { return }
        do {
            requests = try await DataService.shared.fetchRequests(requesterId: uid)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct RequestRow: View {
    let request: BloodRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(request.bloodGroup.rawValue) · \(request.unitsNeeded) unit(s)")
                    .font(.headline)
                Spacer()
                Text(request.urgency.rawValue)
                    .font(.caption)
                    .foregroundColor(request.urgency == .critical ? .red : .secondary)
            }
            Text("\(request.patientName) · \(request.hospital), \(request.city)")
                .font(.subheadline)
            Text("Status: \(request.status.rawValue.capitalized)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

