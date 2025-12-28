import SwiftUI
import FirebaseFirestore

struct NationalHolidayView: View {
    @State private var nationalDay: NationalDay?
    @State private var isLoading = true
    @State private var isSharing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let nationalDay = nationalDay {
                        
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(nationalDay.emoji) \(nationalDay.title)")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            Button {
                                isSharing = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                                    .imageScale(.large)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .accessibilityLabel("Share this day")
                        }
                        .padding()
                        .background(Color.brown.opacity(0.1))
                        .cornerRadius(10)
                        
                        sectionView(title: "Description", text: nationalDay.description, color: .yellow.opacity(0.1))
                        sectionView(title: "History & Origins", text: nationalDay.history_and_origins, color: .blue.opacity(0.1))
                        sectionView(title: "How It's Celebrated", text: nationalDay.how_celebrated, color: .purple.opacity(0.1))
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fun Facts")
                                .font(.headline)
                            ForEach(nationalDay.fun_facts, id: \.self) { fact in
                                Text(" \(fact)")
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    } else if isLoading {
                        ProgressView("Loading...")
                            .padding()
                    } else {
                        Text("No national day info available.")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Today's National Day")
           
            .sheet(isPresented: $isSharing) {
                if let nationalDay = nationalDay {
                    let message = """
                    Happy \(nationalDay.emoji) \(nationalDay.title)!
                    
                    Download Aha! and see what makes every day special: https://apps.apple.com/app/id6747645525
                    """
                    ActivityView(activityItems: [message])
                }
            }
            .onAppear {
                loadNationalDay(daysAhead: 2)   // change this for production
            }
        }
    }
    
    private func sectionView(title: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(color)
        .cornerRadius(10)
    }
    
    private func loadNationalDay(daysAhead: Int = 0) {
        let targetDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        let dateString = formatter.string(from: targetDate)
        
        let db = Firestore.firestore()
        db.collection("daily_content").document(dateString).getDocument { snap, err in
            if let data = snap?.data(), let dayData = data["national_day"] as? [String: Any] {
                self.nationalDay = NationalDay.fromDict(dayData)
            }
            self.isLoading = false
        }
    }
    
    
  
    struct ActivityView: UIViewControllerRepresentable {
        let activityItems: [Any]
        let applicationActivities: [UIActivity]? = nil
        
        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        }
        
        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
    }
    
    
    struct NationalDay {
        var title: String
        var emoji: String
        var description: String
        var history_and_origins: String
        var what_makes_special: String
        var how_celebrated: String
        var fun_facts: [String]
        
        static func fromDict(_ dict: [String: Any]) -> NationalDay {
            NationalDay(
                title: dict["title"] as? String ?? "N/A",
                emoji: dict["emoji"] as? String ?? "",
                description: dict["description"] as? String ?? "",
                history_and_origins: dict["history_and_origins"] as? String ?? "",
                what_makes_special: dict["what_makes_special"] as? String ?? "",
                how_celebrated: dict["how_celebrated"] as? String ?? "",
                fun_facts: dict["fun_facts"] as? [String] ?? []
            )
        }
    }
}
