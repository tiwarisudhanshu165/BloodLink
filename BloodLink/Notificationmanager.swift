import SwiftUI
import FirebaseFirestore

// MARK: - Banner data

struct BannerItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let isPositive: Bool   // green banner for good news, red for urgent requests
}

// MARK: - Listeners that also report whether the data came from the server
// (Firestore first sends a possibly stale "cache" snapshot, then the real server one.
//  We must not treat either of those as "something new happened".)

extension DataService {
    func watchOpenRequests(bloodGroup: BloodGroup,
                           onChange: @escaping ([BloodRequest], Bool) -> Void) -> ListenerRegistration {
        Firestore.firestore().collection("requests")
            .whereField("bloodGroup", isEqualTo: bloodGroup.rawValue)
            .whereField("status", isEqualTo: RequestStatus.open.rawValue)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[BloodLink notify] open requests listener error: \(error.localizedDescription)")
                    return
                }
                guard let snapshot else { return }
                let items = snapshot.documents.compactMap {
                    BloodRequest(id: $0.documentID, data: $0.data())
                }
                onChange(items, !snapshot.metadata.isFromCache)
            }
    }

    func watchResponses(requestId: String,
                        onChange: @escaping ([DonorResponse], Bool) -> Void) -> ListenerRegistration {
        Firestore.firestore().collection("requests").document(requestId)
            .collection("responses")
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("[BloodLink notify] responses listener error: \(error.localizedDescription)")
                    return
                }
                guard let snapshot else { return }
                let items = snapshot.documents.compactMap {
                    DonorResponse(id: $0.documentID, requestId: requestId, data: $0.data())
                }
                onChange(items, !snapshot.metadata.isFromCache)
            }
    }
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
    private var requestsBaselineDone = false

    // Requester state
    private var myRequestsListener: ListenerRegistration?
    private var responseListeners: [String: ListenerRegistration] = [:]
    private var myRequests: [String: BloodRequest] = [:]
    private var seenResponses: [String: Set<String>] = [:]
    private var responseBaselineDone: Set<String> = []

    private func log(_ message: String) {
        print("[BloodLink notify] \(message)")
    }

    // MARK: Start / stop

    func start(uid: String, role: UserRole) {
        if currentUid == uid && currentRole == role { return }
        stop()
        currentUid = uid
        currentRole = role
        log("start as \(role.rawValue)")
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
        requestsBaselineDone = false
        myRequests = [:]
        seenResponses = [:]
        responseBaselineDone = []
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
            self.log("donor profile update: \(profile == nil ? "none yet" : "loaded")")
            self.updateRequestsListener(uid: uid)
        }
    }

    private func updateRequestsListener(uid: String) {
        guard let group = donorProfile?.bloodGroup else {
            requestsListener?.remove()
            requestsListener = nil
            listeningGroup = nil
            knownRequestIds = []
            requestsBaselineDone = false
            return
        }
        if group == listeningGroup { return }

        requestsListener?.remove()
        listeningGroup = group
        knownRequestIds = []
        requestsBaselineDone = false
        requestsListener = DataService.shared.watchOpenRequests(bloodGroup: group) { [weak self] items, fromServer in
            self?.handleOpenRequests(items, fromServer: fromServer, uid: uid)
        }
    }

    private func handleOpenRequests(_ items: [BloodRequest], fromServer: Bool, uid: String) {
        let ids = Set(items.map { $0.id })

        // Until the first real server snapshot arrives, just remember what already exists
        if !requestsBaselineDone {
            knownRequestIds = ids
            if fromServer { requestsBaselineDone = true }
            log("donor baseline: \(ids.count) open request(s), fromServer=\(fromServer)")
            return
        }

        let previous = knownRequestIds
        knownRequestIds = ids

        guard let profile = donorProfile, profile.isAvailable else {
            log("donor update ignored (no profile or marked not available)")
            return
        }

        let newMatches = items.filter {
            !previous.contains($0.id) &&
            sameCity($0.city, profile.city) &&
            $0.requesterId != uid
        }
        log("donor update: \(items.count) open, \(newMatches.count) new match(es)")

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
            responseListeners[requestId] = DataService.shared.watchResponses(requestId: requestId) { [weak self] responses, fromServer in
                self?.handleResponses(responses, fromServer: fromServer, requestId: requestId)
            }
        }

        for (id, listener) in responseListeners where myRequests[id] == nil {
            listener.remove()
            responseListeners[id] = nil
            seenResponses[id] = nil
            responseBaselineDone.remove(id)
        }
    }

    private func handleResponses(_ responses: [DonorResponse], fromServer: Bool, requestId: String) {
        let keys = Set(responses.map { "\($0.id)-\($0.isAvailable)" })
        let previous = seenResponses[requestId] ?? []
        seenResponses[requestId] = keys

        // Until the first real server snapshot arrives, just remember existing responses
        if !responseBaselineDone.contains(requestId) {
            if fromServer { responseBaselineDone.insert(requestId) }
            log("requester baseline for request \(requestId.prefix(6)): \(responses.count) response(s), fromServer=\(fromServer)")
            return
        }

        let newlyAvailable = responses.filter {
            $0.isAvailable && !previous.contains("\($0.id)-true")
        }
        log("requester update for request \(requestId.prefix(6)): \(newlyAvailable.count) newly available")

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
        log("SHOW BANNER: \(title) – \(message)")
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
