import SwiftUI

struct CreateRequestView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

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
                        Text("Submit Request").frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSubmit)
            }
        }
        .navigationTitle("New Blood Request")
    }

    private func submit() async {
        guard let uid = authViewModel.userSession?.uid else { return }
        isSaving = true
        errorMessage = nil
        let request = BloodRequest(
            id: "",
            requesterId: uid,
            patientName: patientName.trimmingCharacters(in: .whitespaces),
            bloodGroup: bloodGroup,
            unitsNeeded: units,
            hospital: hospital.trimmingCharacters(in: .whitespaces),
            city: city.trimmingCharacters(in: .whitespaces),
            urgency: urgency,
            contactPhone: contactPhone.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        do {
            try await DataService.shared.createRequest(request)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
