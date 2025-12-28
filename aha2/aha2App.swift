import SwiftUI
import Firebase
import UserNotifications
import FirebaseAuth

@main
struct aha2App: App {
    
    
    @StateObject var authViewModel = AuthViewModelGuest()
    
   
    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = false
    @AppStorage("notifHour") private var notifHour: Int = 9
    @AppStorage("notifMinute") private var notifMinute: Int = 0

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenGuestView()
                .environmentObject(authViewModel)
              .onAppear {
           
                    askForNotificationsIfNeeded()
                    
                    if pushNotificationsEnabled {
                        NotificationHelper.scheduleWeeklyNotifications(
                            hour: notifHour,
                            minute: notifMinute,
                            enabled: true
                        )
                    }
                }
        }
    }

    
    private func askForNotificationsIfNeeded() {
       
        if UserDefaults.standard.object(forKey: "pushNotificationsEnabled") == nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    self.pushNotificationsEnabled = granted
                   
                    saveNotificationPreferenceToFirestore(granted)
                   
                    if granted {
                        NotificationHelper.scheduleWeeklyNotifications(
                            hour: self.notifHour,
                            minute: self.notifMinute,
                            enabled: true
                        )
                    }
                }
            }
        }
    }
    
    private func saveNotificationPreferenceToFirestore(_ granted: Bool) {
        
        if let uid = Auth.auth().currentUser?.uid {
            let doc = Firestore.firestore().collection("users").document(uid)
            doc.setData(["pushNotificationsEnabled": granted], merge: true)
        }
    }
}
