
import SwiftUI

struct GamesMenuView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Fun Games")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            VStack(spacing: 20) {
                NavigationLink(destination: PuzzleView4()) {
                    TileView2(title: "🧩 Puzzles", color: .pink)
                }
                
                NavigationLink(destination: HangmanView()) {
                    TileView2(title: "🔠 Hangman", color: .orange)
                }

                NavigationLink(destination: MemoryMatchView()) {
                    TileView2(title: "🧠 Memory Match", color: .green)
                }
                
                NavigationLink(destination: WordScrambleView()) {
                    TileView2(title: "📝 Word Scramble", color: .purple)
                }
            }
            .padding(.top, 80) 
            
            Spacer()
        }
    }
}

struct TileView2: View {
    var title: String
    var color: Color
    
    var body: some View {
        Text(title)
            .font(.headline)
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: 300, minHeight: 80)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(15)
            .shadow(radius: 3)
    }
}
