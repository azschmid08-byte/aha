import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import PhotosUI


struct Fact: Identifiable {
    let id: String
    let text: String
}

struct ShareItem: Identifiable {
    let id = UUID()
    let text: String
}


@MainActor
final class FactsViewModel: ObservableObject {
    @Published var facts: [Fact] = []
    @Published var favoriteIDs: Set<String> = []  //test commit
    
    private let db = Firestore.firestore()
    
    func fetchTodayFacts() {
        let df = DateFormatter(); df.dateFormat = "MM-dd"
        let todayKey = df.string(from: Date())
        
        db.collection("daily_content").document(todayKey).getDocument { [weak self] snap, err in
            guard let self else { return }
            if let err { print("Firestore:", err); return }
            
            guard let data = snap?.data(),
                  let list = data["facts"] as? [String] else { return }
            
            facts = list.enumerated().map { i, txt in
                Fact(id: "\(todayKey)-\(i)", text: txt)
            }
            loadFavorites()
        }
    }
    
    private func loadFavorites() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).getDocument { snap, _ in
            if let ids = snap?["favorites"] as? [String] { self.favoriteIDs = Set(ids) }
        }
    }
    
    func toggleFavorite(id: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        favoriteIDs.formSymmetricDifference([id])
        db.collection("users").document(uid)
            .setData(["favorites": Array(favoriteIDs)], merge: true)
    }
}


struct FactsView: View {
    @StateObject private var vm = FactsViewModel()
    @State private var shareItem: ShareItem?
    @State private var showGuestFavoriteAlert = false

    @EnvironmentObject private var authViewModel: AuthViewModelGuest
    @Binding var forceLogin: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text("Did you know on this day …")
                    .font(.largeTitle.bold())
                    .padding(.top)
                
                List {
                    ForEach(vm.facts) { fact in
                        FactRow(
                            fact: fact,
                            isFav: vm.favoriteIDs.contains(fact.id),
                            isGuest: authViewModel.isGuest,
                            share: {
                                let msg = """
                                Did you know? On this day in \(fact.text)

                                I just unlocked a fun historical fact in this Aha! app!
                                Come learn something new every day  https://apps.apple.com/app/id6747645525
                                """
                                shareItem = ShareItem(text: msg)
                            },
                            toggle: {
                                if authViewModel.isGuest {
                                    showGuestFavoriteAlert = true
                                } else {
                                    vm.toggleFavorite(id: fact.id)
                                }
                            }
                        )
                    }
                }
                .listStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 8)
            }
            .padding(.horizontal)
            .onAppear { vm.fetchTodayFacts() }
            .sheet(item: $shareItem) { item in
                FactsActivityView(activityItems: [item.text])
            }
            .alert(isPresented: $showGuestFavoriteAlert) {
                Alert(
                    title: Text("Sign up to save favorites!"),
                    message: Text("Create an account or log in to start saving your favorite facts."),
                    primaryButton: .default(Text("Create Account or Log In")) {
                        forceLogin = true
                        authViewModel.isGuest = false
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}


private struct FactRow: View {
    let fact: Fact
    let isFav: Bool
    let isGuest: Bool
    let share: () -> Void
    let toggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            Text(fact.text)
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            
            Spacer(minLength: 8)
            
            if isFav {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.title3)
                    .padding(.top, 4)
            }
        }
        .contextMenu {
            Button(action: share) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(action: toggle) {
                Label(isFav ? "Unfavorite" : "Favorite",
                      systemImage: isFav ? "heart.fill" : "heart")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(action: share) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
            
            Button(action: toggle) {
                Label(isFav ? "Unfavorite" : "Favorite",
                      systemImage: isFav ? "heart.fill" : "heart")
            }
            .tint(.red)
        }
    }
}


private struct FactsActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
