import SwiftUI
import FirebaseFirestore

// MARK: - Banner data

struct BannerItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let isPositive: Bool   // green banner for good news, red for urgent requests
}

// MARK: - Notification manager
// Watches Firestore in the background (once someone is logged in) and shows a banner
// when something new happens:
//  - Donor: a new open request matching their blood group and city appears
//  - Requester: a donor marks themselves Available for one of their requests

final class NotificationManager: ObservableObject {
    @Published var banner: BannerItem?

    private var currentUid: String?
    private var currentRole: UserRole?
    private var dismissWork: DispatchWorkItem?

    // Donor state
    private var profileListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?
    private var donorProfile: DonorProfile?
    private var listeningGroup: BloodGroup?
    private var knownRequestIds: Set<String> = []
    private var requestsLoaded = false

    // Requester state
    private var myRequestsListener: ListenerRegistration?
    private var responseListeners: [String: ListenerRegistration] = [:]
    private var myRequests: [String: BloodRequest] = [:]
    private var seenResponses: [String: Set<String>] = [:]

    // MARK: Start / stop

    func start(uid: String, role: UserRole) {
        if currentUid == uid && currentRole == role { return }
        stop()
        currentUid = uid
        currentRole = role
        switch role {
        case .donor:
            startDonor(uid: uid)
        case .requester:
            startRequester(uid: uid)
        case .admin:
            break
        }
    }

    func stop() {
        profileListener?.remove()
        requestsListener?.remove()
        myRequestsListener?.remove()
        responseListeners.values.forEach { $0.remove() }

        profileListener = nil
        requestsListener = nil
        myRequestsListener = nil
        responseListeners = [:]
        donorProfile = nil
        listeningGroup = nil
        knownRequestIds = []
        requestsLoaded = false
        myRequests = [:]
        seenResponses = [:]
        currentUid = nil
        currentRole = nil

        dismissWork?.cancel()
        banner = nil
    }

    func dismiss() {
        dismissWork?.cancel()
        banner = nil
    }

    // MARK: Donor side

    private func startDonor(uid: String) {
        profileListener = DataService.shared.listenToDonorProfile(uid: uid) { [weak self] profile in
            guard let self else { return }
            self.donorProfile = profile
            self.updateRequestsListener(uid: uid)
        }
    }

    private func updateRequestsListener(uid: String) {
        guard let group = donorProfile?.bloodGroup else {
            requestsListener?.remove()
            requestsListener = nil
            listeningGroup = nil
            knownRequestIds = []
            requestsLoaded = false
            return
        }
        if group == listeningGroup { return }

        requestsListener?.remove()
        listeningGroup = group
        knownRequestIds = []
        requestsLoaded = false
        requestsListener = DataService.shared.listenToOpenRequests(bloodGroup: group) { [weak self] result in
            guard let self, case .success(let items) = result else { return }
            self.handleOpenRequests(items, uid: uid)
        }
    }

    private func handleOpenRequests(_ items: [BloodRequest], uid: String) {
        let ids = Set(items.map { $0.id })
        defer {
            knownRequestIds = ids
            requestsLoaded = true
        }

        // The first snapshot only records what already exists, so there is no banner on login
        guard requestsLoaded, let profile = donorProfile, profile.isAvailable else { return }

        let newMatches = items.filter {
            !knownRequestIds.contains($0.id) &&
            sameCity($0.city, profile.city) &&
            $0.requesterId != uid
        }
        guard let newest = newMatches.sorted(by: { $0.createdAt > $1.createdAt }).first else { return }

        var message = "\(newest.bloodGroup.rawValue) needed at \(newest.hospital), \(newest.city) (\(newest.urgency.rawValue))"
        if newMatches.count > 1 {
            message += " +\(newMatches.count - 1) more"
        }
        show(title: "New blood request", message: message, isPositive: false)
    }

    // MARK: Requester side

    private func startRequester(uid: String) {
        myRequestsListener = DataService.shared.listenToRequests(requesterId: uid) { [weak self] result in
            guard let self, case .success(let items) = result else { return }
            self.handleMyRequests(items)
        }
    }

    private func handleMyRequests(_ items: [BloodRequest]) {
        myRequests = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        for request in items where responseListeners[request.id] == nil {
            let requestId = request.id
            responseListeners[requestId] = DataService.shared.listenToResponses(requestId: requestId) { [weak self] result in
                guard let self, case .success(let responses) = result else { return }
                self.handleResponses(responses, requestId: requestId)
            }
        }

        for (id, listener) in responseListeners where myRequests[id] == nil {
            listener.remove()
            responseListeners[id] = nil
            seenResponses[id] = nil
        }
    }

    private func handleResponses(_ responses: [DonorResponse], requestId: String) {
        let keys = Set(responses.map { "\($0.id)-\($0.isAvailable)" })
        let previous = seenResponses[requestId]
        seenResponses[requestId] = keys

        // The first snapshot for a request only records existing responses
        guard let previous else { return }

        let newlyAvailable = responses.filter {
            $0.isAvailable && !previous.contains("\($0.id)-true")
        }
        guard let donor = newlyAvailable.first, let request = myRequests[requestId] else { return }

        show(title: "Donor available",
             message: "\(donor.donorName) (\(donor.bloodGroup.rawValue)) can donate for \(request.patientName) at \(request.hospital)",
             isPositive: true)
    }

    // MARK: Helpers

    private func sameCity(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespaces).lowercased() ==
        b.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private func show(title: String, message: String, isPositive: Bool) {
        dismissWork?.cancel()
        banner = BannerItem(title: title, message: message, isPositive: isPositive)

        let work = DispatchWorkItem { [weak self] in
            self?.banner = nil
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
}

// MARK: - Banner view

struct NotificationBannerView: View {
    let item: BannerItem
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.isPositive ? "checkmark.circle.fill" : "drop.fill")
                .font(.title2)
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(item.message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(item.isPositive ? Color.green : Color.red)
        )
        .shadow(radius: 6)
        .padding(.horizontal)
        .padding(.top, 4)
        .onTapGesture(perform: onTap)
    }
}   
