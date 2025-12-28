import SwiftUI

struct MainTabGuestView: View {
    @EnvironmentObject private var authViewModel: AuthViewModelGuest
    @Binding var forceLogin: Bool

    @State private var selectedTab = 0
    @AppStorage("lastFactDate") private var lastFactDate = ""

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                
                HomeGuestView(forceLogin: $forceLogin)
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(0)

               
                Group {
                    if authViewModel.isGuest {
                        GuestLockView(feature: "Favorites") {
                           
                            authViewModel.isGuest = false
                            forceLogin = true
                        }
                    } else {
                        FavoritesView()
                    }
                }
                .tabItem {
                    Image(systemName: "star.fill")
                    Text("Favorites")
                }
                .tag(1)

                GamesMenuView()
                    .tabItem {
                        Label("Games", systemImage: "puzzlepiece.fill")
                    }
                    .tag(2)

                FactsView(forceLogin: $forceLogin)
                    .environmentObject(authViewModel)
                    .tabItem {
                        Image(systemName: "book.fill")
                        Text("Facts")
                    }
                    .tag(3)
                

               
                ProfileGuestView(forceLogin: $forceLogin)
                    .environmentObject(authViewModel)
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
                    .tag(4)
            }
            .onAppear(perform: checkForNewDay)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                checkForNewDay()
            }
        }
    }

    
    private func checkForNewDay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())

        if lastFactDate != todayString {
            selectedTab = 0
            lastFactDate = todayString
        }
    }
}

struct GuestLockView: View {
    let feature: String
    let onLoginTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 10)
            
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 80, height: 80)
                .foregroundColor(.gray)
                .padding(.top, 8)
                .padding(.bottom, 18)

          
            VStack(spacing: 8) {
                Text("You're using Aha! as a guest")
                    .font(.headline)
                Text("Sign up to save favorites, track your streak, and personalize your experience!")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                Button(action: {
                    onLoginTap()
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
            .padding(.vertical, 16)
            .padding(.horizontal)
            .background(Color.yellow.opacity(0.15))
            .cornerRadius(14)
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            Divider()
                .padding(.horizontal, 36)

            Spacer().frame(height: 18)

          
            HStack {
                Label("Favorites", systemImage: "star.fill")
                Spacer()
                Image(systemName: "lock.fill").foregroundColor(.gray)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 36)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

