import SwiftUI
import PhotosUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import StoreKit
import UserNotifications

struct ProfileGuestView: View {
    @EnvironmentObject private var auth: AuthViewModelGuest
    @Binding var forceLogin: Bool

    
    @State private var displayName    = ""
    @State private var userEmail      = ""
    @State private var birthday: Date? = nil
    @State private var favoritesCount = 0
    @State private var streak         = 1

    @State private var localImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?

    @AppStorage("pushNotificationsEnabled") private var pushNotificationsEnabled = false
    @AppStorage("notifHour") private var notifHour: Int = 9
    @AppStorage("notifMinute") private var notifMinute: Int = 0

    @State private var showToast         = false
    @State private var errorText: String?
    @State private var showLogoutConfirm = false
    @State private var showBirthdaySheet = false
    @State private var tmpBirthday       = Date()
    @State private var infoText: String? = nil

    @State private var showDeleteConfirm = false
    @State private var deletingAccount = false
    @State private var showDeleteSuccessAlert = false

    @State private var systemNotificationAllowed = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                if auth.isGuest {
                    
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                        .padding(.top, 32)

                    
                    VStack(spacing: 8) {
                        Text("You're using Aha! as a guest")
                            .font(.headline)
                        Text("Sign up to save favorites, track your streak, and personalize your experience!")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        Button(action: {
                            auth.isGuest = false
                            forceLogin = true
                        }) {
                            Text("Create Account or Log In")
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Divider().padding(.horizontal)

                  
                    VStack(spacing: 16) {
                        HStack {
                            Label("Favorites", systemImage: "star.fill")
                            Spacer()
                            Image(systemName: "lock.fill").foregroundColor(.gray)
                        }
                        HStack {
                            Label("Daily Streak", systemImage: "flame.fill")
                            Spacer()
                            Image(systemName: "lock.fill").foregroundColor(.gray)
                        }
                        HStack {
                            Label("Birthday", systemImage: "calendar")
                            Spacer()
                            Image(systemName: "lock.fill").foregroundColor(.gray)
                        }
                        HStack {
                            Label("Notifications", systemImage: "bell.fill")
                            Spacer()
                            Image(systemName: "lock.fill").foregroundColor(.gray)
                        }
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                } else {
                    
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        ZStack {
                            Circle()
                                .fill(Color(UIColor.secondarySystemBackground))
                                .frame(width: 100, height: 100)
                            avatarContent
                        }
                    }
                    .onChange(of: pickerItem) { _ in loadPickedImage() }
                    .padding(.top, 32)

                  
                    Text(displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.top, 4)

                    Text(userEmail)
                        .foregroundColor(.secondary)

                   
                    HStack {
                        Text("Favorites: \(favoritesCount)")
                        Spacer()
                        Text("Streak 🔥 \(streak)")
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)

                   
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("🔔 Daily Reminder", isOn: $pushNotificationsEnabled)
                            .disabled(!systemNotificationAllowed)
                            .opacity(systemNotificationAllowed ? 1 : 0.5)
                            .padding(.trailing)
                            .onChange(of: pushNotificationsEnabled) { newVal in
                                if systemNotificationAllowed {
                                    saveNotificationSettings()
                                    NotificationHelper.scheduleWeeklyNotifications(
                                        hour: self.notifHour,
                                        minute: self.notifMinute,
                                        enabled: newVal
                                    )
                                }
                            }

                        if systemNotificationAllowed && pushNotificationsEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "clock")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                DatePicker(
                                    "",
                                    selection: Binding(
                                        get: {
                                            Calendar.current.date(from: DateComponents(hour: notifHour, minute: notifMinute)) ?? Date()
                                        },
                                        set: { newDate in
                                            let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                                            notifHour = comps.hour ?? 9
                                            notifMinute = comps.minute ?? 0
                                            saveNotificationSettings()
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .frame(width: 80)
                                .colorScheme(.dark)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.5))
                            .cornerRadius(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                        }

                        if !systemNotificationAllowed {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notifications are turned off in Settings. Enable to get daily reminders.")
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                Button("Open Settings") {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                                .font(.footnote.bold())
                                .foregroundColor(.blue)
                            }
                            .padding(.top, 6)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)

                 
                    birthdayRow

                  
                    Button {
    #if DEBUG
                        showToast = true
                        infoText = "Pretend: Would show App Store review dialog!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showToast = false }
                            infoText = nil
                        }
    #else
                        requestReview()
    #endif
                    } label: {
                        HStack {
                            Image(systemName: "star.bubble")
                            Text("Rate This App")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .tint(.blue)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(10)
                    .padding(.horizontal)

                   
                    Button(action: saveProfile) {
                        Text("Save Profile")
                            .primaryButton()
                    }
                    .padding(.horizontal)

                    Button(action: { showLogoutConfirm = true }) {
                        Text("Log Out")
                            .primaryButton()
                    }
                    .padding(.horizontal)
                    .confirmationDialog("Log out of Aha?", isPresented: $showLogoutConfirm) {
                        Button("Log Out", role: .destructive) { auth.signOut() }
                        Button("Cancel", role: .cancel) { }
                    }

                  
                    HStack {
                        Spacer()
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Text("Delete Account")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.gray)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 14)
                                .background(Color(UIColor.tertiarySystemFill))
                                .cornerRadius(14)
                        }
                        .disabled(deletingAccount)
                        Spacer()
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
        }
        .overlay(
            VStack {
                if showToast {
                    Text(infoText ?? "Profile saved ✓")
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue, in: Capsule())
                        .opacity(showToast ? 1 : 0)
                }
            },
            alignment: .center
        )
        .animation(.easeInOut, value: showToast)
        .alert("Error", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } })
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorText ?? "")
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deletingAccount = true
                auth.deleteAccount { error in
                    deletingAccount = false
                    if let error = error {
                        errorText = error.localizedDescription
                    } else {
                        showDeleteSuccessAlert = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete your account? This cannot be undone.")
        }
        .alert("Account Deleted", isPresented: $showDeleteSuccessAlert) {
            Button("OK") {
                auth.signOut()
            }
        } message: {
            Text("Your account has been deleted.")
        }
        .onAppear {
            localImage = AvatarStore.load()
            if !auth.isGuest {
                loadProfile()
                refreshSystemNotificationPermission()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if !auth.isGuest {
                refreshSystemNotificationPermission()
            }
        }
    }

 
    private func refreshSystemNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                systemNotificationAllowed = (settings.authorizationStatus == .authorized)
                if !systemNotificationAllowed {
                    pushNotificationsEnabled = false
                }
            }
        }
    }

    private var avatarContent: some View {
        Group {
            if let img = localImage {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Text(initials(of: displayName))
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
    }

    private var birthdayRow: some View {
        Button {
            tmpBirthday = birthday ?? Date()
            showBirthdaySheet = true
        } label: {
            HStack {
                Text("Birthday (optional)")
                Spacer()
                if let bday = birthday {
                    Text(bday.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.primary)
                } else {
                    Text("(e.g. \(Date().formatted(.dateTime.month().day().year())))")
                        .foregroundColor(.secondary)
                }
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .contextMenu {
            if birthday != nil {
                Button(role: .destructive) {
                    birthday = nil
                } label: {
                    Label("Remove Birthday", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showBirthdaySheet) {
            VStack {
                DatePicker("Select your birthday",
                           selection: $tmpBirthday,
                           displayedComponents: [.date])
                .labelsHidden()
                .datePickerStyle(.wheel)
                .frame(maxHeight: 250)
                HStack {
                    if birthday != nil {
                        Button("Remove", role: .destructive) {
                            birthday = nil
                            showBirthdaySheet = false
                        }
                    }
                    Spacer()
                    Button("Done") {
                        birthday = tmpBirthday
                        showBirthdaySheet = false
                    }
                }
                .padding(.top)
            }
            .presentationDetents([.medium])
            .padding()
        }
    }
}


extension ProfileGuestView {
    private func loadProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        userEmail = Auth.auth().currentUser?.email ?? ""

        Firestore.firestore().collection("users").document(uid)
            .getDocument { snap, err in
                if let err {
                    errorText = err.localizedDescription
                    return
                }
                guard let data = snap?.data() else { return }

                displayName = data["name"] as? String ?? "No Name"
                if let ts = data["birthday"] as? Timestamp {
                    birthday = ts.dateValue()
                }

                if let favIDs = data["favorites"] as? [String] {
                    favoritesCount = Set(favIDs).count
                } else {
                    favoritesCount = data["favoritesCount"] as? Int ?? 0
                }

                streak = data["streakCount"] as? Int ?? 1

                if let notifFlag = data["pushNotificationsEnabled"] as? Bool {
                    pushNotificationsEnabled = notifFlag
                }
                if let hour = data["notifHour"] as? Int {
                    notifHour = hour
                }
                if let min = data["notifMinute"] as? Int {
                    notifMinute = min
                }
            }
    }

    private func loadPickedImage() {
        guard let item = pickerItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                localImage = uiImage
            } else {
                errorText = "Couldn't load image."
            }
        }
    }

    private func saveProfile() {
        NotificationHelper.scheduleWeeklyNotifications(
            hour: notifHour,
            minute: notifMinute,
            enabled: pushNotificationsEnabled
        )

        guard let uid = Auth.auth().currentUser?.uid else { return }
        let doc = Firestore.firestore().collection("users").document(uid)

        var payload: [String: Any] = [
            "name": displayName,
            "pushNotificationsEnabled": pushNotificationsEnabled
        ]
        if pushNotificationsEnabled {
            payload["notifHour"] = notifHour
            payload["notifMinute"] = notifMinute
        } else {
            payload["notifHour"] = FieldValue.delete()
            payload["notifMinute"] = FieldValue.delete()
        }
        if let bday = birthday { payload["birthday"] = Timestamp(date: bday) }
        else                   { payload["birthday"] = FieldValue.delete() }

        doc.setData(payload, merge: true) { err in
            if let err { errorText = err.localizedDescription }
        }

        if let img = localImage {
            do   { try AvatarStore.save(img) }
            catch { errorText = "Save image error: \(error.localizedDescription)" }
        }
        showToastFor2Sec()
    }

    private func saveNotificationSettings() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let doc = Firestore.firestore().collection("users").document(uid)

        var payload: [String: Any] = [
            "pushNotificationsEnabled": pushNotificationsEnabled
        ]
        if pushNotificationsEnabled {
            payload["notifHour"] = notifHour
            payload["notifMinute"] = notifMinute
        } else {
            payload["notifHour"] = FieldValue.delete()
            payload["notifMinute"] = FieldValue.delete()
        }

        doc.setData(payload, merge: true) { err in
            if let err { errorText = err.localizedDescription }
        }

        NotificationHelper.scheduleWeeklyNotifications(
            hour: notifHour,
            minute: notifMinute,
            enabled: pushNotificationsEnabled
        )
    }

    private func showToastFor2Sec() {
        showToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
        }
    }
}


extension ProfileGuestView {
    private func initials(of name: String) -> String {
        let parts = name.split(separator: " ").compactMap(\.first)
        return parts.isEmpty ? "?" : parts.map(String.init).joined().uppercased()
    }

    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}
