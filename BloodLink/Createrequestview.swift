import SwiftUI

struct CreateRequestView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    /// Pass an existing request to edit it. Leave nil to create a new one.
    var existingRequest: BloodRequest?

    @State private var patientName = ""
    @State private var bloodGroup: BloodGroup = .oPos
    @State private var units = 1
    @State private var hospital = ""
    @State private var city = ""
    @State private var urgency: Urgency = .normal
    @State private var contactPhone = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool { existingRequest != nil }

    private func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var canSubmit: Bool {
        !isBlank(patientName) && !isBlank(hospital) && !isBlank(city) && !isBlank(contactPhone) && !isSaving
    }

    var body: some View {
        Form {
            Section("Patient") {
                TextField("Patient name", text: $patientName)
                Picker("Blood group needed", selection: $bloodGroup) {
                    ForEach(BloodGroup.allCases) { group in
                        Text(group.rawValue).tag(group)
                    }
                }
                Stepper("Units needed: \(units)", value: $units, in: 1...10)
            }

            Section("Location & Contact") {
                TextField("Hospital", text: $hospital)
                TextField("City", text: $city)
                TextField("Contact phone", text: $contactPhone)
                    .keyboardType(.phonePad)
            }

            Section("Details") {
                Picker("Urgency", selection: $urgency) {
                    ForEach(Urgency.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    Task { await submit() }
                } label: {
                    if isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(isEditing ? "Save Changes" : "Submit Request").frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .navigationTitle(isEditing ? "Edit Request" : "New Blood Request")
        .onAppear { loadExistingIfNeeded() }
    }

    private func loadExistingIfNeeded() {
        guard let request = existingRequest, patientName.isEmpty else { return }
        patientName = request.patientName
        bloodGroup = request.bloodGroup
        units = request.unitsNeeded
        hospital = request.hospital
        city = request.city
        urgency = request.urgency
        contactPhone = request.contactPhone
        notes = request.notes
    }

    private func submit() async {
        guard let uid = authViewModel.userSession?.uid else { return }
        isSaving = true
        errorMessage = nil

        let request = BloodRequest(
            id: existingRequest?.id ?? "",
            requesterId: existingRequest?.requesterId ?? uid,
            patientName: patientName.trimmingCharacters(in: .whitespaces),
            bloodGroup: bloodGroup,
            unitsNeeded: units,
            hospital: hospital.trimmingCharacters(in: .whitespaces),
            city: city.trimmingCharacters(in: .whitespaces),
            urgency: urgency,
            contactPhone: contactPhone.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            status: existingRequest?.status ?? .open,
            createdAt: existingRequest?.createdAt ?? Date()
        )

        do {
            if isEditing {
                try await DataService.shared.updateRequest(request)
            } else {
                try await DataService.shared.createRequest(request)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
