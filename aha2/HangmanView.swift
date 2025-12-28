import SwiftUI
import Firebase
import FirebaseFirestore
import AVFoundation

struct HangmanView: View {
    
    @State private var wordToGuess      = ""
    @State private var guessedLetters   : [Character] = []
    @State private var incorrectGuesses = 0
    @State private var showSolution     = false

   
    @State private var lastWord      = ""
    @State private var allWords      : [String] = []
    @State private var remainingWords: [String] = []

    
    @State private var player: AVAudioPlayer?

    private let maxIncorrectGuesses = 6

    
    private var displayWord: String {
        wordToGuess.map { guessedLetters.contains($0) ? String($0) : "_" }
                   .joined(separator: " ")
    }
    private var gameWon : Bool { wordToGuess.allSatisfy(guessedLetters.contains) }
    private var gameLost: Bool { incorrectGuesses >= maxIncorrectGuesses && !gameWon }
    private var gameOver: Bool { gameWon || gameLost }

    
    var body: some View {
        VStack(spacing: 20) {
            Text("🔠 Hangman")
                .font(.largeTitle).bold()

            HangmanDrawing(incorrectGuesses: incorrectGuesses)
                .frame(width: 150, height: 200)

            if wordToGuess.isEmpty {
                ProgressView("Loading word…").padding()
            } else {
                Text(displayWord)
                    .font(.system(size: fontSizeForWord(),
                                  weight: .medium,
                                  design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal)
            }

            Text("Incorrect guesses: \(incorrectGuesses)/\(maxIncorrectGuesses)")
                .foregroundColor(.red)

           
            let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)) {
                ForEach(alphabet.map(String.init), id: \.self) { letter in
                    Button(letter) { handleGuess(letter: Character(letter)) }
                        .disabled(guessedLetters.contains(Character(letter)) ||
                                  gameOver || wordToGuess.isEmpty)
                        .padding(6)
                        .background(guessedLetters.contains(Character(letter))
                                    ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
            }
            .padding()

            
            outcomeSection

            Spacer()
        }
        .padding()
        .onAppear {
            player?.stop()
            resetAllState()
            loadHangmanWords()
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                   AnalyticsParameterScreenName: "HangmanView",
                   AnalyticsParameterScreenClass: "HangmanView"
               ])
        }
        .onChange(of: gameWon) { won in      
            if won { playSuccessSoundOnce()
                Analytics.logEvent("hangman_win", parameters: [
                            "word": wordToGuess,
                            "incorrect_guesses": incorrectGuesses
                        ])}
        }
    }

    
    @ViewBuilder private var outcomeSection: some View {
        if gameWon {
            Text("You won! 🎉")
                .font(.headline)
                .foregroundColor(.green)

            Button("Play Again") { resetGame(sameWord: false) }
                .buttonStyle(RoundedBlue())
        } else if gameLost {
            Text("Sorry you lost! Try again?")
                .font(.headline)
                .foregroundColor(.red)

            HStack(spacing: 10) {
                        Button {
                            resetGame(sameWord: true)
                        } label: {
                            Text("Same Word")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(Rounded(color: .orange))

                        Button {
                            resetGame(sameWord: false)
                        } label: {
                            Text("New Word")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(Rounded(color: .blue))

                        Button {
                            showSolution = true
                        } label: {
                            Text("Give Up")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(Rounded(color: .gray))
                    }

            if showSolution {
                Text("The word was: \(wordToGuess)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 5)
            }
        }
    }

    
    private func handleGuess(letter: Character) {
        guessedLetters.append(letter)
        if !wordToGuess.contains(letter) { incorrectGuesses += 1 }
    }

    private func resetGame(sameWord: Bool) {
        if sameWord {
            wordToGuess = lastWord
        } else {
            if remainingWords.isEmpty { remainingWords = allWords.shuffled() }
            wordToGuess = remainingWords.popLast() ?? "SWIFTUI"
            lastWord    = wordToGuess
        }
        guessedLetters = []
        incorrectGuesses = 0
        showSolution = false
        player?.stop(); player = nil
    }

    private func resetAllState() {
        guessedLetters = []
        incorrectGuesses = 0
        showSolution = false
        lastWord = ""
        allWords = []
        remainingWords = []
    }

    
    private func loadHangmanWords() {
        let formatter = DateFormatter(); formatter.dateFormat = "MM-dd"
        let todayKey  = formatter.string(from: Date())

        Firestore.firestore().collection("daily_content").document(todayKey)
            .getDocument { snap, err in
                if let err { print("❌ Firestore error:", err.localizedDescription); return }
                guard let data  = snap?.data(),
                      let words = data["hangman_words"] as? [String],
                      !words.isEmpty
                else {
                    print("❌ No hangman_words for today")
                    return
                }

                allWords       = words.map { $0.uppercased() }
                remainingWords = allWords.shuffled()
                if let first = remainingWords.popLast() {
                    wordToGuess = first
                    lastWord    = first
                }
            }
    }

    
    private func playSuccessSoundOnce() {
        guard player == nil,
              let url = Bundle.main.url(forResource: "success", withExtension: "mp3") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }

    
    private func fontSizeForWord() -> CGFloat {
        let base: CGFloat = 36, maxLen = 12
        return wordToGuess.count > maxLen
               ? base * CGFloat(maxLen) / CGFloat(wordToGuess.count)
               : base
    }
}


private struct RoundedBlue: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label.padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
            .opacity(c.isPressed ? 0.8 : 1)
    }
}
private struct Rounded: ButtonStyle {
    var color: Color
    func makeBody(configuration c: Configuration) -> some View {
        c.label.padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
            .opacity(c.isPressed ? 0.8 : 1)
    }
}


struct HangmanDrawing: View {
    let incorrectGuesses: Int
    
    private let stroke: Color = .primary

    var body: some View {
        ZStack {
           
            Path { p in
                p.move   (to: CGPoint(x:  10, y:190))
                p.addLine(to: CGPoint(x: 140, y:190))
                p.move   (to: CGPoint(x:  40, y:190))
                p.addLine(to: CGPoint(x:  40, y: 10))
                p.addLine(to: CGPoint(x: 100, y: 10))
                p.addLine(to: CGPoint(x: 100, y: 30))
            }
            .stroke(stroke, lineWidth: 4)

           
            if incorrectGuesses > 0 {
                Circle()
                    .stroke(stroke, lineWidth: 3)
                    .frame(width: 30, height: 30)
                    .position(x: 100, y: 50)
            }
           
            if incorrectGuesses > 1 {
                Path { $0.move(to:  CGPoint(x: 100, y: 65))
                        $0.addLine(to: CGPoint(x: 100, y:120)) }
                    .stroke(stroke, lineWidth: 3)
            }
           
            if incorrectGuesses > 2 {
                Path { $0.move(to:  CGPoint(x: 100, y: 75))
                        $0.addLine(to: CGPoint(x:  80, y:100)) }
                    .stroke(stroke, lineWidth: 3)
            }
            
            if incorrectGuesses > 3 {
                Path { $0.move(to:  CGPoint(x: 100, y: 75))
                        $0.addLine(to: CGPoint(x: 120, y:100)) }
                    .stroke(stroke, lineWidth: 3)
            }
          
            if incorrectGuesses > 4 {
                Path { $0.move(to:  CGPoint(x: 100, y:120))
                        $0.addLine(to: CGPoint(x:  80, y:150)) }
                    .stroke(stroke, lineWidth: 3)
            }
            
            if incorrectGuesses > 5 {
                Path { $0.move(to:  CGPoint(x: 100, y:120))
                        $0.addLine(to: CGPoint(x: 120, y:150)) }
                    .stroke(stroke, lineWidth: 3)
            }
        }
    }
}


