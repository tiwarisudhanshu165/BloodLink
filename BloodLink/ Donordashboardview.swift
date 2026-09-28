import SwiftUI
import FirebaseFirestore

struct DonorDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var profile: DonorProfile?
    @State private var openRequests: [BloodRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var profileListener: ListenerRegistration?
    @State private var requestsListener: ListenerRegistration?
    @State private var listeningGroup: BloodGroup?

    // Requests that match this donor's blood group, city and availability
    private var matchingRequests: [BloodRequest] {
        guard let profile, profile.isAvailable,
              let uid = authViewModel.userSession?.uid else { return [] }
        return openRequests.filter {
            sameCity($0.city, profile.city) && $0.requesterId != uid
        }
    }

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
                    if isLoading {
                        ProgressView()
                    } else if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    } else if let profile, let uid = authViewModel.userSession?.uid {
                        if !profile.isAvailable {
                            Text("You're marked as not available, so no requests are shown. Turn availability on in your profile.")
                                .foregroundColor(.secondary)
                        } else if matchingRequests.isEmpty {
                            Text("No open requests match your blood group and city right now.")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(matchingRequests) { request in
                                IncomingRequestRow(request: request, profile: profile, donorId: uid)
                            }
                        }
                    } else {
                        Text("Set up your profile to see matching requests.")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Donor")
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

    private func sameCity(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespaces).lowercased() ==
        b.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private func startListening() {
        guard profileListener == nil,
              let uid = authViewModel.userSession?.uid else { return }

        profileListener = DataService.shared.listenToDonorProfile(uid: uid) { newProfile in
            profile = newProfile
            isLoading = false
            updateRequestsListener()
        }
    }

    // Re-attaches the requests listener whenever the donor's blood group changes
    private func updateRequestsListener() {
        guard let group = profile?.bloodGroup else {
            requestsListener?.remove()
            requestsListener = nil
            listeningGroup = nil
            openRequests = []
            return
        }
        if group == listeningGroup { return }

        requestsListener?.remove()
        listeningGroup = group
        requestsListener = DataService.shared.listenToOpenRequests(bloodGroup: group) { result in
            switch result {
            case .success(let items):
                openRequests = items
                errorMessage = nil
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func stopListening() {
        profileListener?.remove()
        requestsListener?.remove()
        profileListener = nil
        requestsListener = nil
        listeningGroup = nil
    }
}

private struct IncomingRequestRow: View {
    let request: BloodRequest
    let profile: DonorProfile
    let donorId: String

    @State private var myResponse: Bool?
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var responseListener: ListenerRegistration?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(request.bloodGroup.rawValue) · \(request.unitsNeeded) unit(s)")
                    .font(.headline)
                Spacer()
                Text(request.urgency.rawValue)
                    .font(.caption)
                    .foregroundColor(request.urgency == .critical ? .red : .secondary)
            }
            Text("\(request.hospital), \(request.city)")
                .font(.subheadline)
            Text("Patient: \(request.patientName) · Contact: \(request.contactPhone)")
                .font(.caption)
                .foregroundColor(.secondary)
            if !request.notes.isEmpty {
                Text(request.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let myResponse {
                Text("Your response: \(myResponse ? "Available" : "Not available")")
                    .font(.footnote)
                    .foregroundColor(myResponse ? .green : .orange)
            }

            HStack {
                Button("Available") {
                    Task { await respond(true) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Not Available") {
                    Task { await respond(false) }
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .disabled(isSending)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            guard responseListener == nil else { return }
            responseListener = DataService.shared.listenToMyResponse(requestId: request.id, donorId: donorId) { value in
                myResponse = value
            }
        }
        .onDisappear {
            responseListener?.remove()
            responseListener = nil
        }
    }

    private func respond(_ available: Bool) async {
        isSending = true
        errorMessage = nil
        let response = DonorResponse(
            id: donorId,
            requestId: request.id,
            donorName: profile.fullName,
            donorPhone: profile.phone,
            bloodGroup: profile.bloodGroup,
            isAvailable: available
        )
        do {
            try await DataService.shared.submitResponse(response)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}
