import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    // Used by the debug-only seeder button below
    @State private var isSeeding = false
    @State private var seedStatus: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("BloodLink")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button {
                    Task {
                        await authViewModel.signIn(email: email, password: password)
                    }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Log In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)

                Button("Don't have an account? Sign Up") {
                    showRegister = true
                }
                .font(.footnote)

                #if DEBUG
                Divider()

                Button {
                    Task {
                        isSeeding = true
                        seedStatus = "Seeding... this takes about 30 seconds."
                        let success = await DemoSeeder.run()
                        seedStatus = success
                            ? "Demo data ready. Log in with any demo account (password: \(DemoSeeder.password))."
                            : "Seeding failed. Check the Xcode console for details."
                        isSeeding = false
                    }
                } label: {
                    Text(isSeeding ? "Seeding..." : "Seed Demo Data (debug only)")
                }
                .font(.footnote)
                .disabled(isSeeding)

                if let seedStatus {
                    Text(seedStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                #endif
            }
            .padding()
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }
}
