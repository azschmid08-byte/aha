

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices

@MainActor
class AuthViewModelGuest: NSObject, ObservableObject {
    
   
    @Published var user: User? = Auth.auth().currentUser
    @Published var didCompleteSignIn = false
    @Published var lastLogoutReason: String? = nil
    @Published var isGuest: Bool = false

    func continueAsGuest() {
        isGuest = true
        user = nil
    }

    
    private let db = Firestore.firestore()
    
    
    func signIn() async {
        guard
          let rootVC  = await UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where:{ $0.isKeyWindow })?.rootViewController,
          let clientID = FirebaseApp.app()?.options.clientID
        else { return }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        do {
            let res = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = res.user.idToken?.tokenString else { return }
            let cred = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: res.user.accessToken.tokenString)
            try await firebaseLogin(credential: cred,
                                    displayName: res.user.profile?.name)
        } catch {
            print("Google sign‑in error:", error.localizedDescription)
        }
    }
    
    

    func handleApple(result: ASAuthorization) async {
        guard
            let appleIDCredential = result.credential as? ASAuthorizationAppleIDCredential,
            let idTokenData = appleIDCredential.identityToken,
            let idTokenString = String(data: idTokenData, encoding: .utf8)
        else {
            print("❌ Failed to get Apple credentials")
            return
        }

        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: ""
        )

        do {
            let authResult = try await Auth.auth().signIn(with: credential)

            
            if let fullName = appleIDCredential.fullName,
               let user = Auth.auth().currentUser {
                let displayName = PersonNameComponentsFormatter().string(from: fullName)
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()
            }

            print("✅ Apple sign-in succeeded:", authResult.user.uid)
            
            self.user = Auth.auth().currentUser
            self.didCompleteSignIn = true
            self.isGuest = false

           
            let doc = db.collection("users").document(authResult.user.uid)
            let snap = try? await doc.getDocument()
            if snap?.exists == false {
                let name = Auth.auth().currentUser?.displayName ?? "No Name"
                try await doc.setData([
                    "uid": authResult.user.uid,
                    "name": name,
                    "email": authResult.user.email ?? "",
                    "createdAt": FieldValue.serverTimestamp()
                ])
            }
            try? await doc.setData([
                            "lastLoggedIn": FieldValue.serverTimestamp()
                        ], merge: true)
                        await updateDailyStreak()
           
        } catch {
            print("❌ Apple sign-in error:", error.localizedDescription)
        }
    }

   
    func signIn(email: String, password: String) async throws {
        let res = try await Auth.auth().signIn(withEmail: email, password: password)
        self.user = res.user
        didCompleteSignIn = true
        self.isGuest = false
     
        
        let doc = db.collection("users").document(res.user.uid)
                try? await doc.setData([
                    "lastLoggedIn": FieldValue.serverTimestamp()
                ], merge: true)
                await updateDailyStreak()
    }

 
    
    
    private func firebaseLogin(credential: AuthCredential,
                               displayName: String?) async throws {
        let res = try await Auth.auth().signIn(with: credential)
        self.user = res.user
        
        let doc = db.collection("users").document(res.user.uid)
        if try await doc.getDocument().exists == false {
            let name = displayName ?? res.user.displayName ?? "No Name"
            try await doc.setData([
                "uid"      : res.user.uid,
                "name"     : name,
                "email"    : res.user.email ?? "",
                "createdAt": FieldValue.serverTimestamp()
            ])
        }
        try? await doc.setData([
                    "lastLoggedIn": FieldValue.serverTimestamp()
                ], merge: true)
                didCompleteSignIn = true
                self.isGuest = false 
                await updateDailyStreak()
    }
    
    
    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        user  = nil
        didCompleteSignIn = false
        isGuest = false
    }
    
    
    func updateDailyStreak() async -> Int? {
        guard let uid = user?.uid else { return nil }
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let doc   = db.collection("users").document(uid)
        
       
        let snap  = try? await doc.getDocument()
        let data  = snap?.data() ?? [:]
        let lastTS = data["lastActive"]  as? Timestamp
        let streak = data["streakCount"] as? Int ?? 0
        var newStreak = max(1, streak)
        
        if let lastTS {
            let lastDay = cal.startOfDay(for: lastTS.dateValue())
            if cal.isDate(lastDay, inSameDayAs: today) {
                
            } else if cal.date(byAdding: .day, value: 1, to: lastDay) == today {
                newStreak += 1
            } else {
                newStreak = 1
            }
        }
        
        
        try? await doc.setData([
            "lastActive" : Timestamp(date: today),
            "streakCount": newStreak
        ], merge: true)
        
        
        return newStreak
    }

    
      func deleteAccount(completion: @escaping (Error?) -> Void) {
          guard let user = Auth.auth().currentUser else {
              completion(NSError(domain: "No user", code: -1, userInfo: nil))
              return
          }

         
          let uid = user.uid
          Firestore.firestore().collection("users").document(uid).delete { error in
              if let error = error {
                  completion(error)
                  return
              }

             
              user.delete { error in
                  if let error = error {
                      
                      if let err = error as NSError?, err.code == AuthErrorCode.requiresRecentLogin.rawValue {
                          DispatchQueue.main.async {
                              self.lastLogoutReason = "Please log in again to delete your account."
                              self.signOut()
                          }
                      }
                      completion(error)
                      return
                  }
                  
                  
                  completion(nil)
              }
          }
      }
    
    @MainActor
    func refreshStreakOnLaunch() async { await updateDailyStreak() }
}
