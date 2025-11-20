import SwiftUI

struct GameView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            Color(UIColor.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                header
                board
                newGameButton
            }
            .padding()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text("2048")
                .font(.system(size: 48, weight: .heavy))
                .foregroundColor(Color(red: 119/255, green: 110/255, blue: 101/255))

            Spacer()

            HStack(spacing: 12) {
                scoreCard(title: "Score", value: viewModel.score)
                scoreCard(title: "Best", value: viewModel.best)
            }
        }
    }

    private var board: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: viewModel.size)

        return VStack(spacing: 12) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<viewModel.size, id: \.self) { row in
                    ForEach(0..<viewModel.size, id: \.self) { column in
                        tile(for: viewModel.grid[row][column])
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 187/255, green: 173/255, blue: 160/255))
        )
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height

                    if abs(horizontal) > abs(vertical) {
                        viewModel.move(horizontal > 0 ? .right : .left)
                    } else {
                        viewModel.move(vertical > 0 ? .down : .up)
                    }
                }
        )
    }

    private func tile(for value: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(color(for: value))
                .frame(height: 80)

            if value > 0 {
                Text("\(value)")
                    .font(.system(size: value < 100 ? 32 : 24, weight: .heavy))
                    .foregroundColor(value <= 4 ? Color(red: 119/255, green: 110/255, blue: 101/255) : .white)
            }
        }
    }

    private func scoreCard(title: String, value: Int) -> some View {
        VStack(spacing: 6) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.white)
            Text("\(value)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 187/255, green: 173/255, blue: 160/255))
        )
    }

    private var newGameButton: some View {
        Button(action: {
            viewModel.startNewGame()
        }) {
            Text("New Game")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 143/255, green: 122/255, blue: 102/255))
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                )
        }
    }

    private func color(for value: Int) -> Color {
        switch value {
        case 0:
            return Color(red: 205/255, green: 192/255, blue: 180/255)
        case 2:
            return Color(red: 238/255, green: 228/255, blue: 218/255)
        case 4:
            return Color(red: 237/255, green: 224/255, blue: 200/255)
        case 8:
            return Color(red: 242/255, green: 177/255, blue: 121/255)
        case 16:
            return Color(red: 245/255, green: 149/255, blue: 99/255)
        case 32:
            return Color(red: 246/255, green: 124/255, blue: 95/255)
        case 64:
            return Color(red: 246/255, green: 94/255, blue: 59/255)
        case 128:
            return Color(red: 237/255, green: 207/255, blue: 114/255)
        case 256:
            return Color(red: 237/255, green: 204/255, blue: 97/255)
        case 512:
            return Color(red: 237/255, green: 200/255, blue: 80/255)
        case 1024:
            return Color(red: 237/255, green: 197/255, blue: 63/255)
        case 2048:
            return Color(red: 237/255, green: 194/255, blue: 46/255)
        default:
            return Color(red: 60/255, green: 58/255, blue: 50/255)
        }
    }
}

#Preview {
    GameView()
}
