
import SwiftUI
import PhotosUI
import AVFoundation
import FirebaseAnalytics


struct PuzzleView4: View {
    @State private var difficulty: Difficulty = .easy
    @State private var selectedImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showBanner = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var imageErrorMsg = ""
    @State private var showImageAlert = false
    @State private var puzzleKey = UUID()

    private let samples = (1...10).map { "puzzle_sample\($0)" }

    var body: some View {
        VStack(spacing: 14) {
            if showBanner {
                Text("🎉 Puzzle Solved! 🎉")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            }

            imagePickerSection

            Picker("Difficulty", selection: $difficulty) {
                ForEach(Difficulty.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .onChange(of: difficulty) { _ in
                regeneratePuzzle()
            }

            if let selectedImage {
                UIKitPuzzleGridView4(
                    difficulty: difficulty,
                    selectedImage: selectedImage,
                    showBanner: $showBanner,
                    playSound: playSuccess,
                    puzzleKey: puzzleKey
                )
                .frame(width: 320, height: 320)
                .border(Color.gray)
            }

            Spacer()
        }
        .padding(.top)
        .alert("Image Error", isPresented: $showImageAlert, actions: { },
               message: { Text(imageErrorMsg) })
        .onAppear {
                    Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                        AnalyticsParameterScreenName: "PuzzleView4",
                        AnalyticsParameterScreenClass: "PuzzleView4"
                    ])
                }
    }

    @ViewBuilder
    private var imagePickerSection: some View {
        if let img = selectedImage {
            VStack(spacing: 6) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 180, maxHeight: 180)
                    .border(Color.gray)
                Button("🔄 Change Image") {
                    selectedImage = nil
                    showBanner = false
                    puzzleKey = UUID()
                }.font(.subheadline)
            }
        } else {
            VStack(spacing: 12) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Text("📸 Choose Your Own Image (More Fun!)")
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                .onChange(of: pickerItem) { _ in loadPickedImage() }

                Text("Or select one of our sample images:")
                    .font(.subheadline).foregroundColor(.secondary)
                let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(samples, id: \.self) { name in
                        if let image = UIImage(named: name) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 60)
                                .border(Color.gray)
                                .onTapGesture {
                                    selectedImage = image
                                    showBanner = false
                                    puzzleKey = UUID()
                                }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(10)
        }
    }

    private func regeneratePuzzle() {
        if let img = selectedImage {
            selectedImage = img
            showBanner = false
            puzzleKey = UUID()
        }
    }

    private func playSuccess() {
        guard let url = Bundle.main.url(forResource: "success", withExtension: "mp3") else { return }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
    }

    private func loadPickedImage() {
        Task {
            if let data = try? await pickerItem?.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                let fixedImg = img.normalized()
                selectedImage = fixedImg
                showBanner = false
                puzzleKey = UUID()
            }
            else {
                imageErrorMsg  = "Unable to load the selected image."
                showImageAlert = true
            }
        }
    }
}


struct UIKitPuzzleGridView4: UIViewRepresentable {
    let difficulty: Difficulty
    let selectedImage: UIImage
    @Binding var showBanner: Bool
    let playSound: () -> Void
    let puzzleKey: UUID

    func makeUIView(context: Context) -> PuzzleGridView3 {
        let grid = PuzzleGridView3(difficulty: difficulty, image: selectedImage)
        grid.onSolved = {
            DispatchQueue.main.async {
                showBanner = true
                playSound()
            }
        }
        return grid
    }

    func updateUIView(_ uiView: PuzzleGridView3, context: Context) {
        
        if !showBanner {
            uiView.onSolved = {
                DispatchQueue.main.async {
                    showBanner = true
                    playSound()
                }
            }
            uiView.updatePuzzle(difficulty: difficulty, image: selectedImage)
        }
        uiView.isSolved = showBanner
    }

    static func dismantleUIView(_ uiView: PuzzleGridView4, coordinator: ()) {
        uiView.onSolved = nil
    }
}


class PuzzleGridView4: UIView {
    private var rows: Int = 0
    private var cols: Int = 0
    private var tileSize: CGSize = .zero
    private var tileViews: [UIImageView] = []
    private var tileOrder: [Int] = []
    private var correctOrder: [Int] = []
    var onSolved: (() -> Void)?
    var isSolved: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    convenience init(difficulty: Difficulty, image: UIImage) {
        self.init(frame: .zero)
        updatePuzzle(difficulty: difficulty, image: image)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updatePuzzle(difficulty: Difficulty, image: UIImage) {
        subviews.forEach { $0.removeFromSuperview() }
        tileViews.removeAll()
        tileOrder.removeAll()
        isSolved = false

        rows = Int(sqrt(Double(difficulty.pieceCount)))
        cols = rows
        let count = rows * cols

        let normImage = image.normalized()
        guard let cgImage = normImage.cgImage else { return }
      
        let side = CGFloat(min(cgImage.width, cgImage.height))
        let cropRect = CGRect(x: (CGFloat(cgImage.width) - side)/2, y: (CGFloat(cgImage.height) - side)/2, width: side, height: side)
        guard let square = cgImage.cropping(to: cropRect) else { return }
        let pieceWidth = side / CGFloat(cols)
        let pieceHeight = side / CGFloat(rows)

       
        var pieces: [(img: UIImage, correctIndex: Int)] = []
        for r in 0..<rows {
            for c in 0..<cols {
                let x = CGFloat(c) * pieceWidth
                let y = CGFloat(r) * pieceHeight
                let w = (c == cols-1) ? (side - x) : pieceWidth
                let h = (r == rows-1) ? (side - y) : pieceHeight
                let rect = CGRect(x: x, y: y, width: w, height: h)
                if let sub = square.cropping(to: rect) {
                    let img = UIImage(cgImage: sub)
                    let idx = r * cols + c
                    pieces.append((img, idx))
                }
            }
        }
        correctOrder = Array(0..<count)

      
        let shuffled = pieces.shuffled()
        tileOrder = shuffled.map { $0.correctIndex }

        
        for i in 0..<shuffled.count {
            let iv = UIImageView(image: shuffled[i].img)
            iv.layer.cornerRadius = 0
            iv.layer.masksToBounds = true
            iv.isUserInteractionEnabled = true
            addSubview(iv)
            tileViews.append(iv)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            iv.addGestureRecognizer(pan)
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !tileViews.isEmpty else { return }
        tileSize = CGSize(width: bounds.width / CGFloat(cols), height: bounds.height / CGFloat(rows))
        for (i, tile) in tileViews.enumerated() {
            let row = i / cols
            let col = i % cols
            tile.frame = CGRect(x: CGFloat(col) * tileSize.width,
                                y: CGFloat(row) * tileSize.height,
                                width: tileSize.width,
                                height: tileSize.height)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard !isSolved, let tile = gesture.view as? UIImageView else { return }
        guard let fromIdx = tileViews.firstIndex(of: tile) else { return }

        switch gesture.state {
        case .began:
            bringSubviewToFront(tile)
        case .changed:
            let translation = gesture.translation(in: self)
            tile.center = CGPoint(x: tile.center.x + translation.x, y: tile.center.y + translation.y)
            gesture.setTranslation(.zero, in: self)
        case .ended, .cancelled:
            let newCol = min(max(Int(tile.center.x / tileSize.width), 0), cols - 1)
            let newRow = min(max(Int(tile.center.y / tileSize.height), 0), rows - 1)
            let toIdx = newRow * cols + newCol

            if fromIdx != toIdx, toIdx < tileViews.count {
                tileViews.swapAt(fromIdx, toIdx)
                tileOrder.swapAt(fromIdx, toIdx)
                UIView.animate(withDuration: 0.22, animations: {
                    self.layoutSubviews()
                }, completion: { _ in
                    self.checkSolved()
                })
            } else {
                UIView.animate(withDuration: 0.15) {
                    self.layoutSubviews()
                }
            }
        default:
            break
        }
    }

    private func checkSolved() {
        if tileOrder == correctOrder, !isSolved {
            isSolved = true
            onSolved?()
        }
    }
}

extension UIImage {
    func normalized() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}
