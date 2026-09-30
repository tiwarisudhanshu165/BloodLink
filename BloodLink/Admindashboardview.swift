import SwiftUI
import FirebaseFirestore

struct AdminDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var requests: [BloodRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var listener: ListenerRegistration?
    @State private var filter: StatusFilter = .all

    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case open = "Open"
        case fulfilled = "Fulfilled"
        case closed = "Closed"
        var id: String { rawValue }
    }

    private var filteredRequests: [BloodRequest] {
        switch filter {
        case .all: return requests
        case .open: return requests.filter { $0.status == .open }
        case .fulfilled: return requests.filter { $0.status == .fulfilled }
        case .closed: return requests.filter { $0.status == .closed }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $filter) {
                    ForEach(StatusFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    if isLoading {
                        ProgressView()
                    } else if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    } else if filteredRequests.isEmpty {
                        Text("No requests here.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filteredRequests) { request in
                            AdminRequestRow(request: request)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Admin")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Log Out") {
                        authViewModel.signOut()
                    }
                }
            }
            .onAppear { startListening() }
            .onDisappear { stopListening() }
        }
    }

    private func startListening() {
        guard listener == nil else { return }
        listener = DataService.shared.listenToAllRequests { result in
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

private struct AdminRequestRow: View {
    let request: BloodRequest
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    private var statusColor: Color {
        switch request.status {
        case .open: return .orange
        case .fulfilled: return .green
        case .closed: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(request.bloodGroup.rawValue) · \(request.unitsNeeded) unit(s)")
                    .font(.headline)
                Spacer()
                Text(request.status.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())
            }
            Text("\(request.patientName) · \(request.hospital), \(request.city)")
                .font(.subheadline)
            HStack {
                Text(request.urgency.rawValue)
                    .font(.caption)
                    .foregroundColor(request.urgency == .critical ? .red : .secondary)
                Text("· \(request.contactPhone)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                statusButton("Open", target: .open)
                statusButton("Fulfilled", target: .fulfilled)
                statusButton("Closed", target: .closed)

                Spacer()

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .disabled(isUpdating)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete this request?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deleteRequest() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This also removes all donor responses for it. This can't be undone.")
        }
    }

    @ViewBuilder
    private func statusButton(_ title: String, target: RequestStatus) -> some View {
        Button(title) {
            Task { await setStatus(target) }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .tint(request.status == target ? .accentColor : .secondary)
        .disabled(request.status == target)
    }

    private func setStatus(_ status: RequestStatus) async {
        isUpdating = true
        errorMessage = nil
        do {
            try await DataService.shared.setRequestStatus(id: request.id, status: status)
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }

    private func deleteRequest() async {
        isUpdating = true
        errorMessage = nil
        do {
            try await DataService.shared.deleteRequest(id: request.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isUpdating = false
    }
}
