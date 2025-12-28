import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct HomeGuestView: View {
    @EnvironmentObject var authViewModel: AuthViewModelGuest
    @Binding var forceLogin: Bool 
    @State private var todayFunDayTitle = ""
    @State private var todayFunDayDescription = ""
    @State private var todayFunDayEmoji = "🎉"
    @State private var showNationalDayDetail = false
    @AppStorage("lastHomeLoadDate") private var lastHomeLoadDate: String = ""
    @State private var debugText: String = ""

    private let db = Firestore.firestore()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
           
                VStack(alignment: .center, spacing: 4) {
                    Text("Today is")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(todayFunDayTitle)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Spacer().frame(height: 8)
                    
                    Button(action: {
                        showNationalDayDetail = true
                    }) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(todayFunDayDescription)
                                .foregroundColor(.primary)
                            Text("... Read more")
                                .font(.caption)
                                .italic()
                                .foregroundColor(.blue)
                        }
                        .padding(8)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
              
                VStack(spacing: 16) {
                    NavigationLink(destination: GuessThePersonView()) {
                        TileView2(title: "Guess the Person", color: .green)
                    }
                    
                    NavigationLink(destination: FactsView(forceLogin: $forceLogin)) {
                        TileView2(title: "Facts on This Day", color: .blue)
                    }
                    .environmentObject(authViewModel)
                    
                   
                    NavigationLink(destination: TriviasView()) {
                        TileView2(title: "Trivia", color: .orange)
                    }
                    
                    NavigationLink(destination: GamesMenuView()) {
                        TileView2(title: "Mini Games", color: .purple)
                    }
                }
                .padding(.top, 50)
                .padding(.horizontal)
                
                Spacer()
                
             
                NavigationLink(destination: NationalHolidayView(), isActive: $showNationalDayDetail) {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 20)
            .onAppear { refreshIfNeeded() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                refreshIfNeeded()
            }
        }
    }
    
    private func refreshIfNeeded() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: Date())
        debugText = "refreshIfNeeded called\nisGuest: \(authViewModel.isGuest)\nlastHomeLoadDate: \(lastHomeLoadDate)\ntoday: \(todayString)"
        
        loadTodayFunDayFromDB()
        lastHomeLoadDate = todayString
    }
    
    private func loadTodayFunDayFromDB() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        let todayKey = formatter.string(from: Date())
        todayFunDayTitle = "Loading..."
        todayFunDayDescription = "Loading..."
        todayFunDayEmoji = "🎉"
        
        db.collection("daily_content").document(todayKey).getDocument { snapshot, error in
            if let error = error {
                let errMsg = "❌ Error fetching fun day: \(error.localizedDescription)"
                todayFunDayTitle = "a special day"
                todayFunDayDescription = "Discover what makes today unique"
                todayFunDayEmoji = "🎉"
                debugText += "\n\(errMsg)"
                return
            }
            
            guard let data = snapshot?.data(),
                  let nationalDay = data["national_day"] as? [String: Any],
                  let title = nationalDay["title"] as? String,
                  let description = nationalDay["description"] as? String,
                  let emoji = nationalDay["emoji"] as? String else {
                todayFunDayTitle = "a special day"
                todayFunDayDescription = "Discover what makes today unique"
                todayFunDayEmoji = "🎉"
                debugText += "\nNo data found for today's national day"
                return
            }
            
            todayFunDayTitle = "\(emoji) \(title)"
            todayFunDayDescription = description
            todayFunDayEmoji = emoji
            debugText += "\nNational day loaded: \(title)"
        }
    }
}
