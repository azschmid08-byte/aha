import SwiftUI

struct PuzzleDropDelegate: DropDelegate {
    let item: PuzzlePiece
    @Binding var puzzlePieces: [PuzzlePiece]
    @Binding var isSolved: Bool
    var playSoundAction: (() -> Void)?
    
    func performDrop(info: DropInfo) -> Bool {
        info.itemProviders(for: [.text]).first?.loadObject(ofClass: NSString.self) { (obj, _) in
            DispatchQueue.main.async {
                if let str = obj as? String,
                   let fromPos = Int(str),
                   let from = puzzlePieces.firstIndex(where: { $0.originalPosition == fromPos }),
                   let to = puzzlePieces.firstIndex(of: item) {
                    
                    withAnimation(.easeInOut) {
                        puzzlePieces.swapAt(from, to)
                    }
                    
                    checkSolved()
                }
            }
        }
        return true
    }
    
    func checkSolved() {
        isSolved = puzzlePieces.enumerated().allSatisfy { index, piece in
            piece.originalPosition == index
        }
        if isSolved {
            playSoundAction?()
        }
    }
}
