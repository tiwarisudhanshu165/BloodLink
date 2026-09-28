import Foundation
import FirebaseFirestore

// MARK: - Enums

enum BloodGroup: String, CaseIterable, Identifiable {
    case aPos = "A+"
    case aNeg = "A-"
    case bPos = "B+"
    case bNeg = "B-"
    case abPos = "AB+"
    case abNeg = "AB-"
    case oPos = "O+"
    case oNeg = "O-"

    var id: String { rawValue }
}

enum Urgency: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case urgent = "Urgent"
    case critical = "Critical"

    var id: String { rawValue }
}

enum RequestStatus: String {
    case open
    case fulfilled
    case closed
}

// MARK: - Donor profile (Firestore: donors/{uid})

struct DonorProfile {
    var fullName: String
    var phone: String
    var bloodGroup: BloodGroup
    var city: String
    var isAvailable: Bool
}

extension DonorProfile {
    init?(data: [String: Any]) {
        guard let fullName = data["fullName"] as? String,
              let phone = data["phone"] as? String,
              let groupRaw = data["bloodGroup"] as? String,
              let group = BloodGroup(rawValue: groupRaw),
              let city = data["city"] as? String else { return nil }
        self.init(fullName: fullName,
                  phone: phone,
                  bloodGroup: group,
                  city: city,
                  isAvailable: data["isAvailable"] as? Bool ?? true)
    }

    var dictionary: [String: Any] {
        [
            "fullName": fullName,
            "phone": phone,
            "bloodGroup": bloodGroup.rawValue,
            "city": city,
            "isAvailable": isAvailable
        ]
    }
}

// MARK: - Blood request (Firestore: requests/{autoId})

struct BloodRequest: Identifiable {
    var id: String
    var requesterId: String
    var patientName: String
    var bloodGroup: BloodGroup
    var unitsNeeded: Int
    var hospital: String
    var city: String
    var urgency: Urgency
    var contactPhone: String
    var notes: String
    var status: RequestStatus = .open
    var createdAt: Date = Date()
}

extension BloodRequest {
    init?(id: String, data: [String: Any]) {
        guard let requesterId = data["requesterId"] as? String,
              let patientName = data["patientName"] as? String,
              let groupRaw = data["bloodGroup"] as? String,
              let group = BloodGroup(rawValue: groupRaw),
              let units = data["unitsNeeded"] as? Int,
              let hospital = data["hospital"] as? String,
              let city = data["city"] as? String,
              let urgencyRaw = data["urgency"] as? String,
              let urgency = Urgency(rawValue: urgencyRaw),
              let contactPhone = data["contactPhone"] as? String else { return nil }

        self.init(id: id,
                  requesterId: requesterId,
                  patientName: patientName,
                  bloodGroup: group,
                  unitsNeeded: units,
                  hospital: hospital,
                  city: city,
                  urgency: urgency,
                  contactPhone: contactPhone,
                  notes: data["notes"] as? String ?? "",
                  status: RequestStatus(rawValue: data["status"] as? String ?? "open") ?? .open,
                  createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date())
    }

    var dictionary: [String: Any] {
        [
            "requesterId": requesterId,
            "patientName": patientName,
            "bloodGroup": bloodGroup.rawValue,
            "unitsNeeded": unitsNeeded,
            "hospital": hospital,
            "city": city,
            "urgency": urgency.rawValue,
            "contactPhone": contactPhone,
            "notes": notes,
            "status": status.rawValue,
            "createdAt": Timestamp(date: createdAt)
        ]
    }
}

// MARK: - Donor response (used in Phase 4: requests/{id}/responses/{donorUid})

struct DonorResponse: Identifiable {
    var id: String            // donor's uid
    var requestId: String
    var donorName: String
    var donorPhone: String
    var bloodGroup: BloodGroup
    var isAvailable: Bool
    var respondedAt: Date = Date()
}

extension DonorResponse {
    init?(id: String, requestId: String, data: [String: Any]) {
        guard let donorName = data["donorName"] as? String,
              let donorPhone = data["donorPhone"] as? String,
              let groupRaw = data["bloodGroup"] as? String,
              let group = BloodGroup(rawValue: groupRaw),
              let isAvailable = data["isAvailable"] as? Bool else { return nil }
        self.init(id: id,
                  requestId: requestId,
                  donorName: donorName,
                  donorPhone: donorPhone,
                  bloodGroup: group,
                  isAvailable: isAvailable,
                  respondedAt: (data["respondedAt"] as? Timestamp)?.dateValue() ?? Date())
    }

    var dictionary: [String: Any] {
        [
            "donorName": donorName,
            "donorPhone": donorPhone,
            "bloodGroup": bloodGroup.rawValue,
            "isAvailable": isAvailable,
            "respondedAt": Timestamp(date: respondedAt)
        ]
    }
}

// MARK: - Firestore service

final class DataService {
    static let shared = DataService()
    private let db = Firestore.firestore()

    func saveDonorProfile(uid: String, profile: DonorProfile) async throws {
        var data = profile.dictionary
        data["updatedAt"] = Timestamp(date: Date())
        try await db.collection("donors").document(uid).setData(data, merge: true)
    }

    func fetchDonorProfile(uid: String) async throws -> DonorProfile? {
        let doc = try await db.collection("donors").document(uid).getDocument()
        guard let data = doc.data() else { return nil }
        return DonorProfile(data: data)
    }

    func createRequest(_ request: BloodRequest) async throws {
        _ = try await db.collection("requests").addDocument(data: request.dictionary)
    }

    func fetchRequests(requesterId: String) async throws -> [BloodRequest] {
        let snapshot = try await db.collection("requests")
            .whereField("requesterId", isEqualTo: requesterId)
            .getDocuments()
        return snapshot.documents
            .compactMap { BloodRequest(id: $0.documentID, data: $0.data()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: Phase 4 – matching and responses

    /// Open requests that need a given blood group (city/availability filtering happens in the view).
    func fetchOpenRequests(bloodGroup: BloodGroup) async throws -> [BloodRequest] {
        let snapshot = try await db.collection("requests")
            .whereField("bloodGroup", isEqualTo: bloodGroup.rawValue)
            .whereField("status", isEqualTo: RequestStatus.open.rawValue)
            .getDocuments()
        return snapshot.documents
            .compactMap { BloodRequest(id: $0.documentID, data: $0.data()) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func submitResponse(_ response: DonorResponse) async throws {
        try await db.collection("requests").document(response.requestId)
            .collection("responses").document(response.id)
            .setData(response.dictionary)
    }

    func fetchMyResponse(requestId: String, donorId: String) async throws -> Bool? {
        let doc = try await db.collection("requests").document(requestId)
            .collection("responses").document(donorId).getDocument()
        return doc.data()?["isAvailable"] as? Bool
    }

    func fetchResponses(requestId: String) async throws -> [DonorResponse] {
        let snapshot = try await db.collection("requests").document(requestId)
            .collection("responses").getDocuments()
        return snapshot.documents
            .compactMap { DonorResponse(id: $0.documentID, requestId: requestId, data: $0.data()) }
            .sorted { $0.respondedAt > $1.respondedAt }
    }
}
