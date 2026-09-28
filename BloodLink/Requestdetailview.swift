import SwiftUI
import FirebaseFirestore

struct RequestDetailView: View {
    let request: BloodRequest

    @State private var responses: [DonorResponse] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var listener: ListenerRegistration?

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
                LabeledContent("Status", value: request.status.rawValue.capitalized)
                if !request.notes.isEmpty {
                    Text(request.notes)
                        .font(.footnote)
                        .foregroundColor(.secondary)
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
        }
        .navigationTitle("Request Details")
        .onAppear {
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
}
