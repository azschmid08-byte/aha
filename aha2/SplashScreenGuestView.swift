import SwiftUI

struct SplashScreenGuestView: View {
    @State private var isActive = false
    @State private var animate = false
    @StateObject var authViewModel = AuthViewModelGuest()
    
    var body: some View {
        if isActive {
            ContentRootGuestView()
                .environmentObject(authViewModel)
        } else {
            ZStack {
                splashBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.white)
                        .scaleEffect(animate ? 1.2 : 1.0)
                        .opacity(animate ? 1 : 0.7)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: animate)
                    
                    Text(splashTagline)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                    
                    Text("Get smarter every day ✨")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .padding()
            }
            .onAppear {
                animate = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation { isActive = true }
                }
            }
        }
    }
    
   
    private var splashBackground: some View {
        if isSpecialDay {
            return AnyView(
                Image("flag_bg")
                    .resizable()
                    .scaledToFill()
            )
        } else {
            return AnyView(
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            )
        }
    }
    
    
    private var splashTagline: String {
        isSpecialDay ? "Celebrate Freedom 🇺🇸" : "Your Daily Dose of Facts"
    }
    
   
    private var isSpecialDay: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: Date()) == "07-04"
    }
}


struct ContentRootGuestView: View {
    @EnvironmentObject var authViewModel: AuthViewModelGuest
    @Environment(\.scenePhase) var scenePhase
    @State private var forceLogin = false

    var body: some View {
        VStack {
       
            if forceLogin && !authViewModel.isGuest && authViewModel.user == nil {
               
                LoginGuestView(forceLogin: $forceLogin)
            } else if authViewModel.user != nil || authViewModel.isGuest {
                MainTabGuestView(forceLogin: $forceLogin)
            } else {
                LoginGuestView(forceLogin: $forceLogin)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await authViewModel.refreshStreakOnLaunch() }
            }
        }
    }
}




