import SwiftUI
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var infoText: String? = nil
    @State private var showSignUp = false
    @State private var alertMsg: AuthAlert?

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showLogoutReason: Bool = false


    
    let fieldWidth: CGFloat = 260

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
               
                Image("aha_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .padding(.top, 40)

                Text("Log in to Aha!")
                    .font(.title2).fontWeight(.semibold)

                
                VStack(spacing: 14) {
                   
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        switch result {
                        case .success(let authResults):
                            Task { await authViewModel.handleApple(result: authResults) }
                        case .failure(let error):
                            alertMsg = AuthAlert(text: "Apple sign-in failed: \(error.localizedDescription)")
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(width: fieldWidth, height: 48)
                    .cornerRadius(8)

                   
                    Button {
                        Task { await authViewModel.signIn() }
                    } label: {
                        Image("google_signin_logo_black")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: fieldWidth, height: 48)
                            .clipped()
                    }
                    .frame(width: fieldWidth, height: 48)
                    .background(Color.black)
                   
                    .cornerRadius(8)
                }

              
                HStack(alignment: .center, spacing: 10) {
                    Rectangle()
                        .frame(width: 40, height: 1)
                        .foregroundColor(.secondary)
                    Text("or sign in with email")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Rectangle()
                        .frame(width: 40, height: 1)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

               
                VStack(spacing: 12) {
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: fieldWidth, height: 44)

                    SecureField("Password (≥ 8 chars)", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: fieldWidth, height: 44)

                    Button {
                        Task { await handleLoginTap() }
                    } label: {
                        Text("Log In")
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundColor(.white)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                    .frame(width: fieldWidth, height: 48)
                    .padding(.top, 2)
                }

              
                if let info = infoText {
                    Text(info)
                        .font(.footnote).bold()
                        .foregroundColor(.blue)
                }

                Button("Forgot your password?") {
                    Task { await sendPasswordReset() }
                }
                .font(.footnote)
                .foregroundColor(.blue)

               
                HStack(spacing: 2) {
                    Text("First time here?")
                    Button("Sign up") { showSignUp = true }
                        .foregroundColor(.blue).fontWeight(.medium)
                }
                .font(.footnote)

                Spacer()
            }
            .onAppear {
                        if let reason = authViewModel.lastLogoutReason {
                            alertMsg = AuthAlert(text: reason)
                            authViewModel.lastLogoutReason = nil
                        }
                    }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .alert(item: $alertMsg) { msg in
                Alert(title: Text("Error"),
                      message: Text(msg.text),
                      dismissButton: .default(Text("OK")))
            }
        }
    }

    
    private func handleLoginTap() async {
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mail.isEmpty, !password.isEmpty else {
            alertMsg = AuthAlert(text: "Please enter both email and password.")
            return
        }
        do {
            try await authViewModel.signIn(email: mail, password: password)
        } catch {
            let nsErr = error as NSError
            let code = AuthErrorCode(rawValue: nsErr.code)
            let lowerDesc = nsErr.localizedDescription.lowercased()
            if code == .userNotFound ||
               (code == .wrongPassword && lowerDesc.contains("no user record")) {
                alertMsg = AuthAlert(text: "No account with that email.")
            } else if code == .wrongPassword || code == .invalidCredential {
                alertMsg = AuthAlert(text: "Incorrect password. Please try again.")
            } else if code == .invalidEmail {
                alertMsg = AuthAlert(text: "That doesn’t look like an email address.")
            } else {
                alertMsg = AuthAlert(text: error.localizedDescription)
            }
        }
    }


    private func sendPasswordReset() async {
        let mail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mail.isEmpty else {
            alertMsg = AuthAlert(text: "Enter your e-mail above first.")
            return
        }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: mail)
            infoText = "Reset link sent! Check your inbox."
        } catch {
            guard let nsErr = error as NSError?,
                  nsErr.domain == AuthErrorDomain,
                  let code = AuthErrorCode(rawValue: nsErr.code) else {
                alertMsg = AuthAlert(text: error.localizedDescription)
                return
            }
            switch code {
            case .userNotFound:
                alertMsg = AuthAlert(text: "No account with that e-mail.")
            case .invalidEmail:
                alertMsg = AuthAlert(text: "That doesn’t look like an e-mail.")
            default:
                alertMsg = AuthAlert(text: error.localizedDescription)
            }
        }
    }
}
