import SwiftUI
import FirebaseAuth
import GoogleSignIn

struct AuthAlert: Identifiable { let id = UUID(); let text: String }

struct Login2View: View {
    @State private var email     = ""
    @State private var password  = ""
    @State private var infoText  : String?
    @State private var showSignUp = false
    @State private var alertMsg  : AuthAlert?
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                
                Image("aha_logo")
                    .resizable().scaledToFit()
                    .frame(width: 120, height: 120)
                    .padding(.top, 40)
                
                Text("Log in to Aha")
                    .font(.title2).fontWeight(.semibold)
                
             
                Button { Task { await authViewModel.signIn() } } label: {
                    Image("google_signin_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 48)
                }
                .padding(.horizontal)
                
              
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
                    
                    SecureField("Password (≥ 8 chars)", text: $password)
                        .textFieldStyle(.roundedBorder)
                    
                    Button {
                        Task { await handleLoginTap() }
                    } label: {
                        Text("Log In")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .padding(.top, 10)
                }
                .frame(maxWidth: 320)
                .padding(.horizontal, 8)
                
               
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
            
            switch code {
            case .wrongPassword, .invalidCredential:
                alertMsg = AuthAlert(text: "Incorrect password. Please try again.")
            case .userNotFound:
                alertMsg = AuthAlert(text: "No account with that email.")
            case .invalidEmail:
                alertMsg = AuthAlert(text: "That doesn’t look like an email address.")
            default:
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
