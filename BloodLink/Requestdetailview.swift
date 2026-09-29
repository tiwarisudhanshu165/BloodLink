import SwiftUI
import FirebaseFirestore

struct RequestDetailView: View {
    let request: BloodRequest

    @Environment(\.dismiss) var dismiss

    @State private var responses: [DonorResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var listener: ListenerRegistration?

    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var isUpdatingStatus = false
    @State private var statusError: String?
    @State private var currentStatus: RequestStatus = .open

    private var availableDonors: [DonorResponse] {
        responses.filter { $0.isAvailable }
    }

    private var notAvailableCount: Int {
        responses.filter { !$0.isAvailable }.count
    }

    var body: some View {
        List {
            Section("Request") {
                LabeledContent("Patient", value: request.patientName)
                LabeledContent("Blood group", value: request.bloodGroup.rawValue)
                LabeledContent("Units", value: "\(request.unitsNeeded)")
                LabeledContent("Hospital", value: request.hospital)
                LabeledContent("City", value: request.city)
                LabeledContent("Urgency", value: request.urgency.rawValue)
                LabeledContent("Contact", value: request.contactPhone)
                LabeledContent("Status", value: currentStatus.rawValue.capitalized)
                if !request.notes.isEmpty {
                    Text(request.notes)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            Section("Update Status") {
                Text("Once you've arranged the donation, mark this request Fulfilled so donors stop seeing it. Reopen it if plans fall through.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                HStack {
                    statusButton("Open", target: .open)
                    statusButton("Fulfilled", target: .fulfilled)
                    statusButton("Closed", target: .closed)
                }
                .disabled(isUpdatingStatus)
                if let statusError {
                    Text(statusError)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            Section("Donor Responses") {
                if isLoading {
                    ProgressView()
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                } else if responses.isEmpty {
                    Text("No donors have responded yet.")
                        .foregroundColor(.secondary)
                } else {
                    Text("\(availableDonors.count) available · \(notAvailableCount) not available")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    ForEach(availableDonors) { donor in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(donor.donorName)
                                .font(.headline)
                            Text("\(donor.bloodGroup.rawValue) · \(donor.donorPhone)")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            if let deleteError {
                Section {
                    Text(deleteError)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Request Details")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Request", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Request", systemImage: "trash")
                    }
                } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                .disabled(isDeleting)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                CreateRequestView(existingRequest: request)
            }
        }
        .confirmationDialog(
            "Delete this request?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await deleteRequest() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also removes any donor responses to it. This can't be undone.")
        }
        .onAppear {
            currentStatus = request.status
            guard listener == nil else { return }
            listener = DataService.shared.listenToResponses(requestId: request.id) { result in
                switch result {
                case .success(let items):
                    responses = items
                    errorMessage = nil
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
    }

    @ViewBuilder
    private func statusButton(_ title: String, target: RequestStatus) -> some View {
        Button(title) {
            Task { await setStatus(target) }
        }
        .font(.caption)
        .buttonStyle(.bordered)
        .tint(currentStatus == target ? .accentColor : .secondary)
        .disabled(currentStatus == target)
    }

    private func setStatus(_ status: RequestStatus) async {
        isUpdatingStatus = true
        statusError = nil
        do {
            try await DataService.shared.setRequestStatus(id: request.id, status: status)
            currentStatus = status
        } catch {
            statusError = error.localizedDescription
        }
        isUpdatingStatus = false
    }

    private func deleteRequest() async {
        isDeleting = true
        deleteError = nil
        do {
            try await DataService.shared.deleteRequest(id: request.id)
            dismiss()
        } catch {
            deleteError = error.localizedDescription
            isDeleting = false
        }
    }
}
