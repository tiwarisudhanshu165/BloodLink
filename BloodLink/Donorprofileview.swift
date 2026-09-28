import SwiftUI

struct DonorProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var fullName = ""
    @State private var phone = ""
    @State private var city = ""
    @State private var bloodGroup: BloodGroup = .oPos
    @State private var isAvailable = true
    @State private var isSaving = false
    @State private var message: String?
    @State private var saved = false

    private var canSave: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phone.trimmingCharacters(in: .whitespaces).isEmpty &&
        !city.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isSaving
    }

    var body: some View {
        Form {
            Section("Personal Details") {
                TextField("Full name", text: $fullName)
                TextField("Phone number", text: $phone)
                    .keyboardType(.phonePad)
                TextField("City", text: $city)
            }

            Section("Blood Details") {
                Picker("Blood group", selection: $bloodGroup) {
                    ForEach(BloodGroup.allCases) { group in
                        Text(group.rawValue).tag(group)
                    }
                }
                Toggle("Available to donate", isOn: $isAvailable)
            }

            if let message {
                Section {
                    Text(message)
                        .foregroundColor(saved ? .green : .red)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Save Profile").frame(maxWidth: .infinity)
                    }
                }
                .disabled(!canSave)
            }
        }
        .navigationTitle("My Donor Profile")
        .onAppear {
            Task { await load() }
        }
    }

    private func load() async {
        guard let uid = authViewModel.userSession?.uid else { return }
        do {
            if let profile = try await DataService.shared.fetchDonorProfile(uid: uid) {
                fullName = profile.fullName
                phone = profile.phone
                city = profile.city
                bloodGroup = profile.bloodGroup
                isAvailable = profile.isAvailable
            }
        } catch {
            message = error.localizedDescription
            saved = false
        }
    }

    private func save() async {
        guard let uid = authViewModel.userSession?.uid else { return }
        isSaving = true
        message = nil
        let profile = DonorProfile(
            fullName: fullName.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            bloodGroup: bloodGroup,
            city: city.trimmingCharacters(in: .whitespaces),
            isAvailable: isAvailable
        )
        do {
            try await DataService.shared.saveDonorProfile(uid: uid, profile: profile)
            message = "Profile saved."
            saved = true
        } catch {
            message = error.localizedDescription
            saved = false
        }
        isSaving = false
    }
}
