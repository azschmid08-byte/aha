import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth


struct FavoritesActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}


struct FavoriteShareItem: Identifiable {
    let id = UUID()
    let text: String
}


struct FavoriteFact: Identifiable {
    let id:   String
    let text: String
    let date: String
    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.date(from: date)
    }
}


@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published var all: [FavoriteFact] = []
    @Published var searchText = ""

    private let db = Firestore.firestore()

    var filtered: [FavoriteFact] {
        guard !searchText.isEmpty else { return all }
        let q = searchText.lowercased()
        return all.filter { $0.text.lowercased().contains(q) }
    }

    func fetch() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        db.collection("users").document(uid).getDocument { [weak self] snap, err in
            guard let self else { return }
            if let err { print("Error loading user doc:", err); return }

            let ids = snap?["favorites"] as? [String] ?? []
            guard !ids.isEmpty else { self.all = []; return }

            let grouped = Dictionary(grouping: ids, by: { String($0.prefix(5)) })
            var results: [FavoriteFact] = []
            let dispatch = DispatchGroup()

            for (dateKey, idList) in grouped {
                dispatch.enter()
                self.db.collection("daily_content").document(dateKey)
                    .getDocument { docSnap, err in
                        if let err { print("daily_content \(dateKey):", err) }
                        if
                            let data = docSnap?.data(),
                            let factArray = data["facts"] as? [String]
                        {
                            for favID in idList {
                                if
                                    let indexPart = favID.split(separator: "-").last,
                                    let idx = Int(indexPart),
                                    idx < factArray.count
                                {
                                    results.append(
                                        FavoriteFact(id: favID,
                                                     text: factArray[idx],
                                                     date: dateKey)
                                    )
                                }
                            }
                        }
                        dispatch.leave()
                    }
            }

            dispatch.notify(queue: .main) {
                self.all = ids.compactMap { id in
                    results.first { $0.id == id }
                }
                .sorted {
                    ($0.dateValue ?? .distantPast) > ($1.dateValue ?? .distantPast)
                }
            }
        }
    }

    func unfavorite(ids: [String]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        all.removeAll { ids.contains($0.id) }
        db.collection("users").document(uid)
            .updateData(["favorites": FieldValue.arrayRemove(ids)])
    }
}


struct FavoritesView: View {
    @StateObject private var vm = FavoritesViewModel()
    @State private var shareItem: FavoriteShareItem?
    @State private var marked = Set<String>()

    private let appLink = "https://apps.apple.com/app/id6747645525"

    var body: some View {
        NavigationStack {
            List {
                Section(header:
                    VStack(spacing: 8) {
                        SearchField(text: $vm.searchText)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        HStack {
                            Button(marked.count == vm.filtered.count && !marked.isEmpty
                                   ? "Deselect All"
                                   : "Select All to Unfavorite") {
                                if marked.count == vm.filtered.count && !marked.isEmpty {
                                    marked.removeAll()
                                } else {
                                    marked = Set(vm.filtered.map(\.id))
                                }
                            }
                            .disabled(vm.filtered.isEmpty)

                            Spacer()

                            Button("Done") {
                                vm.unfavorite(ids: Array(marked))
                                marked.removeAll()
                            }
                            .disabled(marked.isEmpty)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color(UIColor.secondarySystemBackground))
                    }
                ) {
                    if vm.filtered.isEmpty {
                        NothingThereView(
                            title: "No Favorites",
                            systemImage: "tray",
                            message: "Add favorites to get started!"
                        )
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(vm.filtered) { fact in
                            FavoriteRow(
                                fact: fact,
                                isMarked: marked.contains(fact.id),
                                toggleMark: {
                                    if marked.contains(fact.id) { marked.remove(fact.id) }
                                    else { marked.insert(fact.id) }
                                },
                                share: {
                                    let msg = """
                                    Did you know? On this day in \(fact.text)
                                    
                                    I just unlocked a fun historical fact in this Aha! app! 
                                    Come learn something new every day  \(appLink)
                                    """
                                    shareItem = FavoriteShareItem(text: msg)
                                },
                                swipeUnfavorite: { vm.unfavorite(ids: [fact.id]) }
                            )
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(
                Text("Favorites")
                    .font(.system(size: 28, weight: .bold))
            )
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { vm.fetch() }
            .sheet(item: $shareItem) { item in
                FavoritesActivityView(activityItems: [item.text])
            }
        }
    }
}


private struct FavoriteRow: View {
    let fact: FavoriteFact
    let isMarked: Bool
    let toggleMark: () -> Void
    let share: () -> Void
    let swipeUnfavorite: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(fact.text)
                Text(fact.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(10)

            Spacer(minLength: 8)

            Image(systemName: isMarked ? "heart.slash.fill" : "heart.fill")
                .foregroundColor(.red)
                .font(.title3)
                .padding(.top, 4)
                .onTapGesture(perform: toggleMark)
        }
        .padding(.vertical, 4)
        .background(isMarked ? Color.accentColor.opacity(0.15) : Color.clear)
        .onLongPressGesture(perform: toggleMark)
        .contextMenu {
            Button(action: share) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: swipeUnfavorite) {
                Label("Unfavorite", systemImage: "heart.slash")
            }
        }
    }
}


private struct SearchField: View {
    @Binding var text: String
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search facts", text: $text)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(UIColor.systemGray5))
        .cornerRadius(10)
    }
}


struct NothingThereView: View {
    let title: String
    let systemImage: String
    let message: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.gray.opacity(0.5))

            Text(title)
                .font(.title2)
                .bold()

            if let message = message {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
