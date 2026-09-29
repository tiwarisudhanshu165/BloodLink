#if DEBUG
import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Dev-only tool that fills Firebase with realistic demo data.
/// It creates real Auth accounts and writes each account's own documents while signed in
/// as that account, so your Phase 8 security rules accept every write.
///
/// Safe to run more than once: existing accounts are signed into (not duplicated) and
/// requests use fixed IDs, so they are overwritten instead of duplicated.
///
/// Called from the debug button on LoginView. Run it only while logged out.
enum DemoSeeder {

    // MARK: - Settings you may need to adjust

    /// These match your UserRole enum raw values in AuthViewModel.
    private static let roleRequester = "requester"
    private static let roleDonor = "donor"
    private static let roleAdmin = "admin"

    static let password = "Demo@1234"
    static let adminEmail = "admin@bloodlink.demo"

    // MARK: - Demo data

    private struct Person {
        let name: String
        let email: String
        let phone: String
    }

    private struct DemoDonor {
        let person: Person
        let group: BloodGroup
        let city: String
        let available: Bool
    }

    private struct DemoRequest {
        let id: String
        let requesterEmail: String
        let patient: String
        let group: BloodGroup
        let units: Int
        let hospital: String
        let city: String
        let urgency: Urgency
        let phone: String
        let notes: String
        let status: RequestStatus
        let hoursAgo: Double
    }

    private struct DemoResponse {
        let requestId: String
        let donorEmail: String
        let available: Bool
        let hoursAgo: Double
    }

    private static let requesters: [Person] = [
        Person(name: "Rohan Mehta", email: "rohan.requester@bloodlink.demo", phone: "+91 90000 10001"),
        Person(name: "Priya Sharma", email: "priya.requester@bloodlink.demo", phone: "+91 90000 10002"),
        Person(name: "Amit Verma", email: "amit.requester@bloodlink.demo", phone: "+91 90000 10003")
    ]

    private static let donors: [DemoDonor] = [
        DemoDonor(person: Person(name: "Aarav Singh", email: "aarav.donor@bloodlink.demo", phone: "+91 90000 20001"),
                  group: .oPos, city: "Noida", available: true),
        DemoDonor(person: Person(name: "Neha Gupta", email: "neha.donor@bloodlink.demo", phone: "+91 90000 20002"),
                  group: .aPos, city: "Noida", available: true),
        DemoDonor(person: Person(name: "Karan Yadav", email: "karan.donor@bloodlink.demo", phone: "+91 90000 20003"),
                  group: .bPos, city: "Greater Noida", available: true),
        DemoDonor(person: Person(name: "Simran Kaur", email: "simran.donor@bloodlink.demo", phone: "+91 90000 20004"),
                  group: .oNeg, city: "Delhi", available: true),
        DemoDonor(person: Person(name: "Vikram Rao", email: "vikram.donor@bloodlink.demo", phone: "+91 90000 20005"),
                  group: .abPos, city: "Ghaziabad", available: true),
        DemoDonor(person: Person(name: "Isha Jain", email: "isha.donor@bloodlink.demo", phone: "+91 90000 20006"),
                  group: .aPos, city: "Greater Noida", available: true),
        DemoDonor(person: Person(name: "Manish Tiwari", email: "manish.donor@bloodlink.demo", phone: "+91 90000 20007"),
                  group: .bNeg, city: "Noida", available: false),
        DemoDonor(person: Person(name: "Pooja Nair", email: "pooja.donor@bloodlink.demo", phone: "+91 90000 20008"),
                  group: .oPos, city: "Delhi", available: true)
    ]

    private static let requests: [DemoRequest] = [
        DemoRequest(id: "demo-req-1", requesterEmail: "rohan.requester@bloodlink.demo",
                    patient: "Suresh Mehta", group: .oPos, units: 2,
                    hospital: "Kailash Care Hospital", city: "Noida", urgency: .critical,
                    phone: "+91 90000 10001", notes: "Surgery scheduled this evening.",
                    status: .open, hoursAgo: 2),
        DemoRequest(id: "demo-req-2", requesterEmail: "rohan.requester@bloodlink.demo",
                    patient: "Anita Mehta", group: .aPos, units: 1,
                    hospital: "Sunrise Medical Centre", city: "Noida", urgency: .urgent,
                    phone: "+91 90000 10001", notes: "Needed within 24 hours.",
                    status: .open, hoursAgo: 6),
        DemoRequest(id: "demo-req-3", requesterEmail: "priya.requester@bloodlink.demo",
                    patient: "Rahul Sharma", group: .bPos, units: 3,
                    hospital: "Lifeline Hospital", city: "Greater Noida", urgency: .urgent,
                    phone: "+91 90000 10002", notes: "Accident case, ICU.",
                    status: .open, hoursAgo: 12),
        DemoRequest(id: "demo-req-4", requesterEmail: "priya.requester@bloodlink.demo",
                    patient: "Kavita Sharma", group: .oNeg, units: 1,
                    hospital: "Metro Care Hospital", city: "Delhi", urgency: .critical,
                    phone: "+91 90000 10002", notes: "Donor found, transfusion done.",
                    status: .fulfilled, hoursAgo: 48),
        DemoRequest(id: "demo-req-5", requesterEmail: "amit.requester@bloodlink.demo",
                    patient: "Deepak Verma", group: .abPos, units: 2,
                    hospital: "Green Valley Hospital", city: "Ghaziabad", urgency: .normal,
                    phone: "+91 90000 10003", notes: "Planned procedure next week.",
                    status: .open, hoursAgo: 30),
        DemoRequest(id: "demo-req-6", requesterEmail: "amit.requester@bloodlink.demo",
                    patient: "Sunita Verma", group: .aPos, units: 1,
                    hospital: "Sunrise Medical Centre", city: "Noida", urgency: .normal,
                    phone: "+91 90000 10003", notes: "No longer required.",
                    status: .closed, hoursAgo: 72)
    ]

    private static let responses: [DemoResponse] = [
        DemoResponse(requestId: "demo-req-1", donorEmail: "aarav.donor@bloodlink.demo", available: true, hoursAgo: 1.5),
        DemoResponse(requestId: "demo-req-1", donorEmail: "pooja.donor@bloodlink.demo", available: false, hoursAgo: 1),
        DemoResponse(requestId: "demo-req-2", donorEmail: "neha.donor@bloodlink.demo", available: true, hoursAgo: 5),
        DemoResponse(requestId: "demo-req-3", donorEmail: "karan.donor@bloodlink.demo", available: true, hoursAgo: 10),
        DemoResponse(requestId: "demo-req-4", donorEmail: "simran.donor@bloodlink.demo", available: true, hoursAgo: 40),
        DemoResponse(requestId: "demo-req-5", donorEmail: "vikram.donor@bloodlink.demo", available: true, hoursAgo: 25),
        DemoResponse(requestId: "demo-req-6", donorEmail: "isha.donor@bloodlink.demo", available: true, hoursAgo: 60)
    ]

    // MARK: - Run

    @discardableResult
    static func run() async -> Bool {
        let db = Firestore.firestore()
        print("🌱 Seeding demo data...")

        do {
            // 1. Admin
            let adminUID = try await signInOrCreate(email: adminEmail)
            try await writeUser(db, uid: adminUID, email: adminEmail, role: roleAdmin)
            print("✅ Admin ready")

            // 2. Requesters and their requests
            for requester in requesters {
                let uid = try await signInOrCreate(email: requester.email)
                try await writeUser(db, uid: uid, email: requester.email, role: roleRequester)

                for item in requests where item.requesterEmail == requester.email {
                    let request = BloodRequest(
                        id: item.id,
                        requesterId: uid,
                        patientName: item.patient,
                        bloodGroup: item.group,
                        unitsNeeded: item.units,
                        hospital: item.hospital,
                        city: item.city,
                        urgency: item.urgency,
                        contactPhone: item.phone,
                        notes: item.notes,
                        status: item.status,
                        createdAt: Date().addingTimeInterval(-item.hoursAgo * 3600)
                    )
                    try await db.collection("requests").document(item.id).setData(request.dictionary)
                }
                print("✅ Requester ready: \(requester.name)")
            }

            // 3. Donors, their profiles, and their responses
            for donor in donors {
                let uid = try await signInOrCreate(email: donor.person.email)
                try await writeUser(db, uid: uid, email: donor.person.email, role: roleDonor)

                let profile = DonorProfile(fullName: donor.person.name,
                                           phone: donor.person.phone,
                                           bloodGroup: donor.group,
                                           city: donor.city,
                                           isAvailable: donor.available)
                try await DataService.shared.saveDonorProfile(uid: uid, profile: profile)

                for item in responses where item.donorEmail == donor.person.email {
                    let response = DonorResponse(
                        id: uid,
                        requestId: item.requestId,
                        donorName: donor.person.name,
                        donorPhone: donor.person.phone,
                        bloodGroup: donor.group,
                        isAvailable: item.available,
                        respondedAt: Date().addingTimeInterval(-item.hoursAgo * 3600)
                    )
                    try await DataService.shared.submitResponse(response)
                }
                print("✅ Donor ready: \(donor.person.name)")
            }

            try Auth.auth().signOut()
            print("🎉 Seeding complete. Signed out. All demo accounts use password: \(password)")
            return true
        } catch {
            print("❌ Seeding failed: \(error.localizedDescription)")
            print("   Full error: \(error)")
            return false
        }
    }

    // MARK: - Helpers

    /// Creates the account (which also signs in). If it already exists, signs in instead.
    private static func signInOrCreate(email: String) async throws -> String {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            return result.user.uid
        } catch {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return result.user.uid
        }
    }

    /// Writes exactly what AuthViewModel.signUp writes: email, role, createdAt.
    private static func writeUser(_ db: Firestore, uid: String, email: String, role: String) async throws {
        try await db.collection("users").document(uid).setData([
            "email": email,
            "role": role,
            "createdAt": Timestamp(date: Date())
        ], merge: true)
    }
}
#endif
