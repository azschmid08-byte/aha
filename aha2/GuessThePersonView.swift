import SwiftUI
import Firebase
import FirebaseFirestore

struct GuessThePersonView: View {
    
    @State private var scratchPoints: [CGPoint] = []
    
    
    @State private var clues: [String] = []
    @State private var personName: String = ""
    
    private let db = Firestore.firestore()
    
   
    var body: some View {
        VStack(spacing: 16) {
            Text("Can you guess the person?")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
           
            if clues.isEmpty {
                ProgressView("Loading clues…")
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(clues.indices, id: \.self) { i in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .padding(.top, 2)
                            Text(clues[i])
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(nil)
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                        .shadow(color: .gray.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                }
                .padding(.horizontal)

            }
            
            Spacer()
            
       
            ZStack {
               
                Text(personName)
                    .font(.title)
                    .bold()
                    .foregroundColor(.green)
                    .frame(width: 300, height: 150)
                    .background(Color.clear)
                
               
                Canvas { ctx, _ in
                   
                    ctx.fill(Path(CGRect(x: 0, y: 0, width: 300, height: 150)),
                             with: .color(Color.blue))
                    
                    
                    ctx.blendMode = .destinationOut
                    for p in scratchPoints {
                        let circle = Path(ellipseIn:
                            CGRect(x: p.x - 18, y: p.y - 18,
                                   width: 36, height: 36))
                        ctx.fill(circle, with: .color(.black))
                    }
                }
                .frame(width: 300, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { scratchPoints.append($0.location) }
                )
                
                
                if scratchPoints.isEmpty {
                    Text("Scratch here to reveal the answer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                }
            }
            .padding()
            
            Spacer()
        }
        .padding(.bottom)
        .onAppear { loadGuessThePerson() }
    }
    
   
    private func loadGuessThePerson() {
        let df = DateFormatter()
        df.dateFormat = "MM-dd"
        let docID = df.string(from: Date())
        
        db.collection("daily_content").document(docID)
            .getDocument { snap, err in
                if let err { print("❌ Firestore:", err); return }
                guard
                    let data = snap?.data(),
                    let gtp  = data["guess_the_person"] as? [String: Any],
                    let cl   = gtp["clues"] as? [String],
                    let name = gtp["name"]  as? String
                else {
                    print("❌ guess_the_person missing for \(docID)")
                    return
                }
                clues = cl
                personName = name
            }
    }
}


