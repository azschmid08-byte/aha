import SwiftUI
import FirebaseFirestore
import FirebaseAnalytics


struct TriviaQuestion: Identifiable {
    let id = UUID()
    let question: String
    let answers: [String]
    let correctAnswer: String
}

struct TriviasView: View {
    @State private var triviaQuestions: [TriviaQuestion] = []
    @State private var currentIndex      = 0
    @State private var selectedAnswers: Set<String> = []
    @State private var isCorrect         = false
    @State private var showWrongMsg      = false
    
    
    private var current: TriviaQuestion? {
        triviaQuestions.isEmpty ? nil : triviaQuestions[currentIndex]
    }
    private var isLast: Bool {
        currentIndex == triviaQuestions.count - 1
    }
    
    
    var body: some View {
        VStack(spacing: 12) {
            
          
            Text("Trivia")
                .font(.largeTitle.bold())
                .padding(.top)
             
            
            Spacer(minLength: 10)          
            
           
            if triviaQuestions.isEmpty {
                ProgressView("Loading trivia…")
                    .onAppear { fetchTrivia() }
            } else if let q = current {
                
                Text(q.question)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                
             
                VStack(spacing: 15) {
                    ForEach(q.answers, id: \.self) { option in
                        Button {
                            handleAnswer(option, correct: q.correctAnswer)
                        } label: {
                            Text(option)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(buttonColor(for: option, correct: q.correctAnswer))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(isCorrect || selectedAnswers.contains(option))
                    }
                }
                .padding(.horizontal)
                
              
                Group {
                    if isCorrect {
                        Text(isLast ? "🎉 All questions completed!" : "✅ Correct!")
                            .foregroundColor(.green)
                    } else if showWrongMsg {
                        Text("❌ Try again!")
                            .foregroundColor(.red)
                    }
                }
                .font(.title3)
                .padding(.top, 6)
                
               
                if isCorrect {
                    Button(isLast ? "Restart" : "Next") {
                        advance()
                    }
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 6)
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
                    Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                        AnalyticsParameterScreenName: "TriviasView",
                        AnalyticsParameterScreenClass: "TriviasView"
                    ])
                }
    }
    
    
    private func handleAnswer(_ option: String, correct: String) {
        if option == correct {
            isCorrect = true
            showWrongMsg = false
            selectedAnswers.removeAll()
        } else {
            selectedAnswers.insert(option)
            showWrongMsg = true
        }
    }
    
    private func advance() {
        if isLast { currentIndex = 0 } else { currentIndex += 1 }
        selectedAnswers.removeAll(); isCorrect = false; showWrongMsg = false
    }
    
    private func buttonColor(for option: String, correct: String) -> Color {
        if isCorrect { return option == correct ? .green : .blue }
        if selectedAnswers.contains(option) { return .red }
        return .blue
    }
    
   
    private func fetchTrivia() {
        let fmt = DateFormatter(); fmt.dateFormat = "MM-dd"
        let key = fmt.string(from: Date())
        
        Firestore.firestore().collection("daily_content").document(key)
            .getDocument { snap, err in
                if let err { print("Firestore:", err.localizedDescription); return }
                guard let raw = snap?.data()?["trivia"] as? [[String: Any]] else { return }
                
                triviaQuestions = raw.compactMap { dict in
                    guard let q  = dict["question"]       as? String,
                          let ans = dict["answers"]        as? [String],
                          let cor = dict["correct_answer"] as? String else { return nil }
                    return TriviaQuestion(
                        question: q,
                        answers: ans.shuffled(),
                        correctAnswer: cor
                    )
                }
            }
    }
}


