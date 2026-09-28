import SwiftUI
import FirebaseFirestore

struct RequesterDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var requests: [BloodRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var listener: ListenerRegistration?

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
                        stopListening()
                        authViewModel.signOut()
                    }
                }
            }
            .onAppear { startListening() }
            .onDisappear { stopListening() }
        }
    }

    private func startListening() {
        guard listener == nil,
              let uid = authViewModel.userSession?.uid else { return }
        listener = DataService.shared.listenToRequests(requesterId: uid) { result in
            switch result {
            case .success(let items):
                requests = items
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
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
