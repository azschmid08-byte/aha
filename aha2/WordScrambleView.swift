import SwiftUI
import Firebase
import FirebaseFirestore

struct WordScrambleView: View {
    @State private var originalWord  = ""
    @State private var scrambledWord = ""
    @State private var userGuess     : [String] = []
    @State private var hintIndices   : Set<Int> = []
    @State private var attempts      = 0
    @State private var startTime     : Date?
    @State private var elapsedTime   : TimeInterval = 0
    @State private var showSuccess   = false
    @State private var showTryAgain  = false
    @State private var gaveUp        = false
    @State private var scrambleWords : [String] = []
    @State private var theme         = ""

    
    @State private var justFocused: Int? = nil

    @FocusState private var focusedField: Int?

    @AppStorage("wordBestAttempts") private var wordBestAttempts = Int.max
    @AppStorage("wordBestTime")     private var wordBestTime     = Double.greatestFiniteMagnitude

    var body: some View {
        VStack(spacing: 20) {
            Text("📝 Word Scramble")
                .font(.largeTitle.bold())
                .padding(.top)

            
            if !scrambledWord.isEmpty {
                HStack(spacing: 8) {
                    ForEach(scrambledWord.map(String.init), id: \.self) { ch in
                        Text(ch)
                            .font(.title)
                            .frame(width: boxWidth, height: boxWidth)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(5)
                    }
                }
            } else {
                ProgressView("Loading word…")
            }

         
            HStack(spacing: 8) {
                ForEach(0..<originalWord.count, id: \.self) { idx in
                    let correctLetter = String(originalWord[originalWord.index(originalWord.startIndex, offsetBy: idx)])
                       let guessLetter = userGuess.indices.contains(idx) ? userGuess[idx] : ""
                       let isCorrect = guessLetter.uppercased() == correctLetter.uppercased() && !guessLetter.isEmpty
                    CustomLetterBox(
                        letter: userGuess.indices.contains(idx) ? userGuess[idx] : "",
                        isFocused: focusedField == idx,
                        highlight: hintIndices.contains(idx),
                        isCorrect: isCorrect,
                        onLetterChange: { newLetter in
                            guard idx < userGuess.count else { return }
                            userGuess[idx] = newLetter
                            
                            if !newLetter.isEmpty, idx < userGuess.count - 1 {
                                focusedField = idx + 1
                            }
                        },
                        onBackspace: {
                            guard idx < userGuess.count else { return }
                            if !userGuess[idx].isEmpty {
                                userGuess[idx] = ""
                            } else if idx > 0 {
                                focusedField = idx - 1
                            }
                        },
                        onFocus: {
                            justFocused = idx
                        }
                    )
                    .frame(width: boxWidth, height: boxWidth)
                    .focused($focusedField, equals: idx)
                    .onTapGesture {
                        focusedField = idx
                    }
                }
            }

           
            HStack {
                Button("Check", action: checkGuess)
                    .padding()
                    .background(allFilled ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(!allFilled)

                Button("Hint 💡", action: provideHint)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.black)
                    .cornerRadius(8)

                Button("Give Up", action: giveUp)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            if showTryAgain {
                Button("Try Again", action: clearGuess)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Text("Attempts: \(attempts)")
                .foregroundColor(.secondary)

            if showSuccess {
                VStack(spacing: 4) {
                    Text("🎉 Correct! Great job!")
                        .font(.headline)
                        .foregroundColor(.green)

                    Text("Your time: \(String(format: "%.1f", elapsedTime)) s")
                    Text("Best attempts: \(wordBestAttempts == Int.max ? "N/A" : "\(wordBestAttempts)")")
                    Text(wordBestTime == Double.greatestFiniteMagnitude
                         ? "Best time: N/A"
                         : "Best time: \(String(format: "%.1f", wordBestTime)) s")
                }
                .padding(.top, 4)

                Button("Play Again", action: startGame)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            Spacer()
        }
        .padding()
        .onAppear { loadScrambleWords() }
    }

    private var allFilled: Bool { !userGuess.contains(where: \.isEmpty) }

    private var boxWidth: CGFloat {
        guard !originalWord.isEmpty else { return 40 }
        let spacing: CGFloat = 8
        let totalSpacing = CGFloat(originalWord.count - 1) * spacing
        let available = UIScreen.main.bounds.width - 40 - totalSpacing
        return max(min(available / CGFloat(originalWord.count), 40), 20)
    }

    private func startGame() {
        guard !scrambleWords.isEmpty else { return }

        originalWord  = scrambleWords.randomElement() ?? "SWIFT"
        scrambledWord = String(originalWord.shuffled())
        while scrambledWord == originalWord && originalWord.count > 1 {
            scrambledWord = String(originalWord.shuffled())
        }

        userGuess     = Array(repeating: "", count: originalWord.count)
        hintIndices   = []
        attempts      = 0
        elapsedTime   = 0
        startTime     = Date()
        showSuccess   = false
        showTryAgain  = false
        gaveUp        = false
        focusedField  = 0
    }

    private func clearGuess() {
        userGuess = Array(repeating: "", count: originalWord.count)
        hintIndices.removeAll()
        showTryAgain = false
        focusedField = 0
    }

    private func checkGuess() {
        attempts += 1
        if userGuess.joined().uppercased() == originalWord {
            if let start = startTime { elapsedTime = Date().timeIntervalSince(start) }
            updateBests()
            showSuccess  = true
            showTryAgain = false
            focusedField = nil
        } else {
            showTryAgain = true
        }
    }

    private func provideHint() {
        for i in 0..<originalWord.count {
            let correct = String(originalWord[originalWord.index(originalWord.startIndex, offsetBy: i)])
            if userGuess[i] != correct {
                userGuess[i] = correct
                hintIndices.insert(i)
                focusedField = nextEmpty(start: i + 1)
                break
            }
        }
    }

    private func giveUp() {
        userGuess   = originalWord.map(String.init)
        hintIndices = Set(0..<originalWord.count)
        showTryAgain = false
        gaveUp = true
        focusedField = nil
    }

    private func updateBests() {
        if attempts      < wordBestAttempts { wordBestAttempts = attempts }
        if elapsedTime   < wordBestTime     { wordBestTime     = elapsedTime }
    }

    private func nextEmpty(start: Int) -> Int? {
        (start..<userGuess.count).first { userGuess[$0].isEmpty }
    }

    private func loadScrambleWords() {
        let db = Firestore.firestore()
        let df = DateFormatter(); df.dateFormat = "MM-dd"
        let key = df.string(from: Date())

        db.collection("daily_content").document(key).getDocument { snap, err in
            if let err { print("❌ Firestore:", err.localizedDescription); return }

            guard
                let data  = snap?.data(),
                let words = data["scramble_words"] as? [String], !words.isEmpty
            else {
                
                originalWord   = "SWIFT"
                scrambledWord  = "WIFTS"
                userGuess      = Array(repeating: "", count: originalWord.count)
                return
            }

            scrambleWords = words.map { $0.uppercased() }
            theme         = data["theme"] as? String ?? ""
            startGame()
        }
    }
}


struct CustomLetterBox: UIViewRepresentable {
    var letter: String
    var isFocused: Bool
    var highlight: Bool
    var isCorrect: Bool
    var onLetterChange: (String) -> Void
    var onBackspace: () -> Void
    var onFocus: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.delegate = context.coordinator
        tf.autocapitalizationType = .allCharacters
        tf.autocorrectionType = .no
        tf.textAlignment = .center
        tf.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
        tf.backgroundColor = UIColor.clear
        tf.layer.cornerRadius = 5
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        tf.addTarget(context.coordinator, action: #selector(Coordinator.didBegin), for: .editingDidBegin)
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
          if tf.text != letter { tf.text = letter }
        
          if isCorrect {
              tf.layer.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.6).cgColor
          } else if isFocused {
              tf.layer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.25).cgColor
          } else if highlight {
              tf.layer.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.5).cgColor
          } else {
              tf.layer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.10).cgColor
          }
          if isFocused && !tf.isFirstResponder {
              tf.becomeFirstResponder()
          } else if !isFocused && tf.isFirstResponder {
              tf.resignFirstResponder()
          }
      }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CustomLetterBox

        init(_ parent: CustomLetterBox) { self.parent = parent }

        @objc func editingChanged(_ tf: UITextField) {
            let filtered = tf.text?.uppercased().filter { $0.isLetter } ?? ""
            
            if filtered.count > 1 {
                tf.text = String(filtered.last!)
                parent.onLetterChange(String(filtered.last!))
            } else {
                tf.text = filtered
                parent.onLetterChange(filtered)
            }
        }

        @objc func didBegin(_ tf: UITextField) {
            tf.selectedTextRange = tf.textRange(from: tf.beginningOfDocument, to: tf.endOfDocument)
            parent.onFocus()
        }

        func textField(_ tf: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
           
            if string.isEmpty && range.length == 1 {
                tf.text = ""
                parent.onLetterChange("")
                parent.onBackspace()
                return false
            }
           
            return true
        }
    }
}

