import SwiftUI
import AVFoundation
import Firebase
import FirebaseFirestore

struct MemoryMatchView: View {
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        
        var id: String { rawValue }
        
        var pairCount: Int {
            switch self {
            case .easy: return 4
            case .medium: return 6
            case .hard: return 8
            }
        }
    }
    
    @State private var cards: [MemoryCard] = []
    @State private var firstSelectedIndex: Int? = nil
    @State private var isProcessing = false
    @State private var difficulty: Difficulty = .easy
    @State private var player: AVAudioPlayer?
  
    @State private var themeEmojis: [String] = []
    
    @State private var moveCount = 0
    @State private var startTime: Date?
    @State private var elapsedTime: TimeInterval = 0
    
    @AppStorage("bestMoveCountEasy") private var bestMoveCountEasy = Int.max
    @AppStorage("bestMoveCountMedium") private var bestMoveCountMedium = Int.max
    @AppStorage("bestMoveCountHard") private var bestMoveCountHard = Int.max
    
    @AppStorage("bestTimeEasy") private var bestTimeEasy = Double.greatestFiniteMagnitude
    @AppStorage("bestTimeMedium") private var bestTimeMedium = Double.greatestFiniteMagnitude
    @AppStorage("bestTimeHard") private var bestTimeHard = Double.greatestFiniteMagnitude
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 4)
    
    var body: some View {
        VStack {
            Text("🧠 Memory Match")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
         
            
            Picker("Difficulty", selection: $difficulty) {
                ForEach(Difficulty.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: difficulty) { _ in
                startGame()
            }
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(cards.indices, id: \.self) { index in
                    let card = cards[index]
                    CardView(content: card.content, isFaceUp: card.isFaceUp || card.isMatched)
                        .onTapGesture {
                            handleTap(on: index)
                        }
                        .disabled(card.isFaceUp || card.isMatched || isProcessing)
                }
            }
            .padding()
            
            if cards.allSatisfy({ $0.isMatched }) && !cards.isEmpty {
                Text("🎉 Great job! You matched them all!")
                    .font(.headline)
                    .foregroundColor(.green)
                    .padding(.top)
                    .onAppear {
                        finalizeGame()
                    }
                
                Button("Play Again") {
                    startGame()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            VStack {
                Text("Your moves: \(moveCount)")
                Text("Your time: \(String(format: "%.1f", elapsedTime)) s")
                Text("Best moves: \(bestMoveCountForDifficulty == Int.max ? "N/A" : "\(bestMoveCountForDifficulty)")")
                Text("Best time: \(bestTimeForDifficulty == Double.greatestFiniteMagnitude ? "N/A" : "\(String(format: "%.1f", bestTimeForDifficulty)) s")")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.bottom)
            
            Spacer()
        }
        .onAppear {
            fetchThemeEmojis()
        }
    }
    
    private func fetchThemeEmojis() {
        let db = Firestore.firestore()
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        let todayString = formatter.string(from: Date())
        
        db.collection("daily_content").document(todayString).getDocument { snapshot, error in
            if let error = error {
                print("❌ Firestore error: \(error.localizedDescription)")
                return
            }
            guard let data = snapshot?.data(),
                  let emojis = data["theme_emojis"] as? [String],
                  let themeName = data["theme"] as? String else {
                print("❌ Missing theme_emojis or theme")
                return
            }
            
            self.themeEmojis = emojis.shuffled()
         
            startGame()
        }
    }
    
    private func startGame() {
        guard !themeEmojis.isEmpty else { return }
        
        var emojiChoices = Array(themeEmojis.prefix(difficulty.pairCount))
        let pairedEmojis = (emojiChoices + emojiChoices).shuffled()
        
        cards = pairedEmojis.map { MemoryCard(content: $0) }
        firstSelectedIndex = nil
        isProcessing = false
        moveCount = 0
        startTime = Date()
        elapsedTime = 0
        player = nil
    }
    
    private func handleTap(on index: Int) {
        guard !cards[index].isFaceUp else { return }
        
        moveCount += 1
        cards[index].isFaceUp = true
        
        if let firstIndex = firstSelectedIndex {
            isProcessing = true
            if cards[firstIndex].content == cards[index].content {
                cards[firstIndex].isMatched = true
                cards[index].isMatched = true
                firstSelectedIndex = nil
                isProcessing = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    cards[firstIndex].isFaceUp = false
                    cards[index].isFaceUp = false
                    firstSelectedIndex = nil
                    isProcessing = false
                }
            }
        } else {
            firstSelectedIndex = index
        }
    }
    
    private func finalizeGame() {
        if let start = startTime {
            elapsedTime = Date().timeIntervalSince(start)
        }
        
        switch difficulty {
        case .easy:
            if moveCount < bestMoveCountEasy { bestMoveCountEasy = moveCount }
            if elapsedTime < bestTimeEasy { bestTimeEasy = elapsedTime }
        case .medium:
            if moveCount < bestMoveCountMedium { bestMoveCountMedium = moveCount }
            if elapsedTime < bestTimeMedium { bestTimeMedium = elapsedTime }
        case .hard:
            if moveCount < bestMoveCountHard { bestMoveCountHard = moveCount }
            if elapsedTime < bestTimeHard { bestTimeHard = elapsedTime }
        }
        
        playSuccessSound()
    }
    
    private func playSuccessSound() {
        if player == nil {
            guard let url = Bundle.main.url(forResource: "success", withExtension: "mp3") else {
                print("❌ success.mp3 not found in bundle.")
                return
            }
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.play()
            } catch {
                print("❌ Error playing success sound: \(error.localizedDescription)")
            }
        }
    }
    
    private var bestMoveCountForDifficulty: Int {
        switch difficulty {
        case .easy: return bestMoveCountEasy
        case .medium: return bestMoveCountMedium
        case .hard: return bestMoveCountHard
        }
    }
    
    private var bestTimeForDifficulty: Double {
        switch difficulty {
        case .easy: return bestTimeEasy
        case .medium: return bestTimeMedium
        case .hard: return bestTimeHard
        }
    }
}

struct MemoryCard {
    let content: String
    var isFaceUp = false
    var isMatched = false
}

struct CardView: View {
    let content: String
    let isFaceUp: Bool
    
    var body: some View {
        ZStack {
            if isFaceUp {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .shadow(radius: 3)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 2)
                Text(content)
                    .font(.largeTitle)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
