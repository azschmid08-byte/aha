import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import UserNotifications
import FirebaseFirestore

struct AlertMessage: Identifiable { let id = UUID(); let text: String }

struct SignUpView: View {
    
    @State private var name         = ""
    @State private var email        = ""
    @State private var password     = ""
    @State private var errorMessage : AlertMessage?
    @State private var isLoading    = false
    @State private var navigateToProfile = false
    @State private var currentUser  : User?
    @State private var shouldGoToLogin = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Text("Sign Up")
                    .font(.largeTitle).bold()
                    .padding(.top, 40)
                
                
                VStack(spacing: 14) {
                    TextField("Full Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password (≥ 8 chars)", text: $password)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        requestPushNotificationPermission()
                        signUpWithEmail()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 45)
                        } else {
                            Text("Sign Up with Email")
                                .frame(maxWidth: .infinity, minHeight: 45)
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 30)
            }
            .navigationDestination(isPresented: $navigateToProfile) {
                ProfileView()
            }
            .alert(item: $errorMessage) { msg in
                Alert(
                    title: Text("Info"),
                    message: Text(msg.text),
                    dismissButton: .default(Text("OK")) {
                        if shouldGoToLogin {
                            dismiss()
                        }
                    }
                )
            }
        }
    }

   
    private func signUpWithEmail() {
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = AlertMessage(text: "Please fill in Name, Email and Password.")
            return
        }
        guard password.count >= 8 else {
            errorMessage = AlertMessage(text: "Password must be at least 8 characters.")
            return
        }
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { res, err in
            isLoading = false
            if let err { errorMessage = AlertMessage(text: err.localizedDescription); return }
            guard let user = res?.user else {
                errorMessage = AlertMessage(text: "User creation failed."); return
            }

            let change = user.createProfileChangeRequest()
            change.displayName = name
            change.commitChanges(completion: nil)

           
            errorMessage = AlertMessage(text: "Welcome \(name)! Account created. You can now log in.")
            shouldGoToLogin = true

            Firestore.firestore().collection("users").document(user.uid).setData([
                "uid"        : user.uid,
                "name"       : name,
                "email"      : email,
                "streakCount": 0,
                "createdAt": FieldValue.serverTimestamp()
               
            ], merge: true, completion: nil)
        }
    }

    
    private func requestPushNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, err in
                if let err { print("Push permission error:", err) }
                if granted { DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() } }
            }
    }
}
