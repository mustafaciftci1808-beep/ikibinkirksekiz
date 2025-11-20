import Foundation
import SwiftUI

final class GameViewModel: ObservableObject {
    enum Direction {
        case up, down, left, right
    }

    @Published var grid: [[Int]]
    @Published var score: Int = 0 {
        didSet {
            best = max(best, score)
            UserDefaults.standard.set(best, forKey: Self.bestKey)
        }
    }
    @Published var best: Int

    let size = 4
    private static let bestKey = "bestScore"

    init() {
        self.grid = Array(repeating: Array(repeating: 0, count: size), count: size)
        self.best = UserDefaults.standard.integer(forKey: Self.bestKey)
        startNewGame()
    }

    func startNewGame() {
        grid = Array(repeating: Array(repeating: 0, count: size), count: size)
        score = 0
        addRandomTile()
        addRandomTile()
    }

    func move(_ direction: Direction) {
        let originalGrid = grid
        var gainedScore = 0

        switch direction {
        case .left:
            for row in 0..<size {
                let (newLine, gained) = merge(line: grid[row])
                grid[row] = newLine
                gainedScore += gained
            }
        case .right:
            for row in 0..<size {
                let reversed = Array(grid[row].reversed())
                let (newLine, gained) = merge(line: reversed)
                grid[row] = Array(newLine.reversed())
                gainedScore += gained
            }
        case .up:
            for column in 0..<size {
                let columnValues = (0..<size).map { grid[$0][column] }
                let (newLine, gained) = merge(line: columnValues)
                gainedScore += gained
                for row in 0..<size {
                    grid[row][column] = newLine[row]
                }
            }
        case .down:
            for column in 0..<size {
                let columnValues = Array((0..<size).map { grid[$0][column] }.reversed())
                let (newLine, gained) = merge(line: columnValues)
                gainedScore += gained
                let restoredLine = Array(newLine.reversed())
                for row in 0..<size {
                    grid[row][column] = restoredLine[row]
                }
            }
        }

        if grid != originalGrid {
            score += gainedScore
            addRandomTile()
        }
    }

    private func merge(line: [Int]) -> ([Int], Int) {
        var tiles = line.filter { $0 != 0 }
        var result: [Int] = []
        var gained = 0
        var index = 0

        while index < tiles.count {
            if index + 1 < tiles.count && tiles[index] == tiles[index + 1] {
                let newValue = tiles[index] * 2
                result.append(newValue)
                gained += newValue
                index += 2
            } else {
                result.append(tiles[index])
                index += 1
            }
        }

        while result.count < size {
            result.append(0)
        }

        return (result, gained)
    }

    private func addRandomTile() {
        let emptyPositions = emptyCells()
        guard !emptyPositions.isEmpty else { return }

        if let position = emptyPositions.randomElement() {
            let value = Bool.random(probability: 0.9) ? 2 : 4
            grid[position.row][position.column] = value
        }
    }

    private func emptyCells() -> [(row: Int, column: Int)] {
        var positions: [(Int, Int)] = []
        for row in 0..<size {
            for column in 0..<size {
                if grid[row][column] == 0 {
                    positions.append((row, column))
                }
            }
        }
        return positions
    }
}

private extension Bool {
    static func random(probability: Double) -> Bool {
        return Double.random(in: 0...1) < probability
    }
}
