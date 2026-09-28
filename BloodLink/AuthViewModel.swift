import Foundation
import FirebaseAuth
import FirebaseFirestore

enum UserRole: String, Codable {
    case requester
    case donor
    case admin
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var userRole: UserRole?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let db = Firestore.firestore()

    init() {
        self.userSession = Auth.auth().currentUser
        if let uid = userSession?.uid {
            Task { await fetchUserRole(uid: uid) }
        }
    }

    func signUp(email: String, password: String, role: UserRole) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            try await db.collection("users").document(result.user.uid).setData([
                "email": email,
                "role": role.rawValue,
                "createdAt": Timestamp(date: Date())
            ])
            self.userSession = result.user
            self.userRole = role
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            await fetchUserRole(uid: result.user.uid)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.userRole = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func fetchUserRole(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            if let roleString = document.data()?["role"] as? String,
               let role = UserRole(rawValue: roleString) {
                self.userRole = role
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}

