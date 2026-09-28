import SwiftUI

struct DonorDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var profile: DonorProfile?
    @State private var matchingRequests: [BloodRequest] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

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
                        authViewModel.signOut()
                    }
                }
            }
            .onAppear {
                Task { await load() }
            }
        }
    }

    private func sameCity(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespaces).lowercased() ==
        b.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private func load() async {
        guard let uid = authViewModel.userSession?.uid else { return }
        profile = try? await DataService.shared.fetchDonorProfile(uid: uid)

        if let profile, profile.isAvailable {
            do {
                let openRequests = try await DataService.shared.fetchOpenRequests(bloodGroup: profile.bloodGroup)
                matchingRequests = openRequests.filter {
                    sameCity($0.city, profile.city) && $0.requesterId != uid
                }
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            matchingRequests = []
        }
        isLoading = false
    }
}

private struct IncomingRequestRow: View {
    let request: BloodRequest
    let profile: DonorProfile
    let donorId: String

    @State private var myResponse: Bool?
    @State private var isSending = false
    @State private var errorMessage: String?

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
        .task {
            myResponse = try? await DataService.shared.fetchMyResponse(requestId: request.id, donorId: donorId)
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
            myResponse = available
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}

