import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedRole: UserRole = .donor

    // MARK: - Password rules

    private var hasMinLength: Bool { password.count >= 8 }
    private var hasUppercase: Bool { password.contains { $0.isUppercase } }
    private var hasLowercase: Bool { password.contains { $0.isLowercase } }
    private var hasNumber: Bool { password.contains { $0.isNumber } }
    private var hasSpecial: Bool {
        password.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }
    }

    private var isPasswordValid: Bool {
        hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecial
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.title)
                    .fontWeight(.bold)

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 4) {
                    ruleRow("At least 8 characters", met: hasMinLength)
                    ruleRow("One uppercase letter (A-Z)", met: hasUppercase)
                    ruleRow("One lowercase letter (a-z)", met: hasLowercase)
                    ruleRow("One number (0-9)", met: hasNumber)
                    ruleRow("One special character (e.g. @ # $ !)", met: hasSpecial)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(.roundedBorder)

                Picker("I am a...", selection: $selectedRole) {
                    Text("Donor").tag(UserRole.donor)
                    Text("Requester").tag(UserRole.requester)
                }
                .pickerStyle(.segmented)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                if password != confirmPassword && !confirmPassword.isEmpty {
                    Text("Passwords do not match")
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button {
                    Task {
                        await authViewModel.signUp(email: email, password: password, role: selectedRole)
                        if authViewModel.userSession != nil {
                            dismiss()
                        }
                    }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Sign Up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty
                          || !isPasswordValid
                          || password != confirmPassword
                          || authViewModel.isLoading)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func ruleRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundColor(met ? .green : .secondary)
            Text(text)
                .foregroundColor(met ? .green : .secondary)
        }
        .font(.caption)
    }
}
