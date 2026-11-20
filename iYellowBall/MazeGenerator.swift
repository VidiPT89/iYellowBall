import Foundation

/// Tile values: 0 = gem, 1 = wall, 3 = ice orb, 4 = empty floor.
struct Maze {
    var tiles: [Int]
    let ballHome = GridPoint(col: 13, row: 21)
    let plazaCenter = GridPoint(col: 13, row: 13)
    static let tunnelRow = 13

    /// Wraps the column (side tunnel) and treats rows outside the board as wall.
    func tile(_ col: Int, _ row: Int) -> Int {
        if row < 0 || row >= GameConfig.rows { return 1 }
        var c = col
        if c < 0 { c += GameConfig.cols }
        if c >= GameConfig.cols { c -= GameConfig.cols }
        return tiles[GameConfig.idx(c, row)]
    }

    func isWall(_ col: Int, _ row: Int) -> Bool { tile(col, row) == 1 }

    func openNeighbours(_ col: Int, _ row: Int) -> Int {
        Dir.all.filter { !isWall(col + $0.x, row + $0.y) }.count
    }

    var orbs: [GridPoint] {
        tiles.indices.filter { tiles[$0] == 3 }.map { GridPoint(col: $0 % GameConfig.cols, row: $0 / GameConfig.cols) }
    }
}

/// Small deterministic RNG so a seed always produces the same maze on every device.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Builds a left/right symmetric maze: a randomised depth-first carve on the
/// left half, mirrored, then every dead end is opened into a loop so the ball
/// always has an escape route. A central plaza holds the enemies' spawn and a
/// side tunnel wraps across the board.
enum MazeGenerator {
    static func seed(forLevel level: Int, base: UInt64 = 0xC0FFEE) -> UInt64 {
        base &+ UInt64(level) &* 0x2545_F491_4F6C_DD1D
    }

    static func make(seed: UInt64) -> Maze {
        var rng = SplitMix64(seed: seed)
        let cols = GameConfig.cols, rows = GameConfig.rows
        let mid = cols / 2
        var t = [Int](repeating: 1, count: cols * rows)

        func open(_ c: Int, _ r: Int, _ value: Int = 0) {
            t[GameConfig.idx(c, r)] = value
            t[GameConfig.idx(cols - 1 - c, r)] = value
        }
        func isOpen(_ c: Int, _ r: Int) -> Bool {
            c >= 0 && c < cols && r >= 0 && r < rows && t[GameConfig.idx(c, r)] != 1
        }
        func isCell(_ c: Int, _ r: Int) -> Bool { c % 2 == 1 && r % 2 == 1 && c > 0 && r > 0 && c < cols - 1 && r < rows - 1 }

        // 1. Carve a spanning tree on the left half (columns up to the centre).
        var visited = Set<GridPoint>()
        var stack = [GridPoint(col: 1, row: 1)]
        visited.insert(stack[0])
        open(1, 1)
        while let current = stack.last {
            let next = Dir.all.map { GridPoint(col: current.col + $0.x * 2, row: current.row + $0.y * 2) }
                .filter { isCell($0.col, $0.row) && $0.col <= mid && !visited.contains($0) }
            guard let pick = next.randomElement(using: &rng) else { stack.removeLast(); continue }
            open((current.col + pick.col) / 2, (current.row + pick.row) / 2)
            open(pick.col, pick.row)
            visited.insert(pick)
            stack.append(pick)
        }

        // 2. A few extra openings so there are several routes between areas.
        for r in 1..<(rows - 1) {
            for c in 1...mid where (c + r) % 2 == 1 && t[GameConfig.idx(c, r)] == 1 {
                let horizontal = c % 2 == 0 // wall between two cells left/right of it
                let a = horizontal ? (c - 1, r) : (c, r - 1)
                let b = horizontal ? (c + 1, r) : (c, r + 1)
                guard isCell(a.0, a.1), isCell(b.0, b.1) else { continue }
                if Double.random(in: 0..<1, using: &rng) < 0.09 { open(c, r) }
            }
        }

        // 3. Central plaza (enemy spawn) and side tunnel.
        for r in 11...15 { for c in 11...15 { open(c, r, 4) } }
        open(0, Maze.tunnelRow, 4)

        // 4. Remove every dead end by knocking through to another cell.
        var changed = true
        while changed {
            changed = false
            for r in stride(from: 1, to: rows - 1, by: 2) {
                for c in stride(from: 1, to: cols - 1, by: 2) where isOpen(c, r) {
                    let exits = Dir.all.filter { isOpen(c + $0.x, r + $0.y) }
                    guard exits.count <= 1 else { continue }
                    let candidates = Dir.all.filter { d in
                        !isOpen(c + d.x, r + d.y) && isCell(c + d.x * 2, r + d.y * 2)
                    }
                    guard let d = candidates.randomElement(using: &rng) else { continue }
                    open(c + d.x, r + d.y)
                    changed = true
                }
            }
        }

        // 5. Every corridor tile already holds a gem (0); clear the start and add ice orbs.
        var maze = Maze(tiles: t)
        maze.tiles[GameConfig.idx(maze.ballHome.col, maze.ballHome.row)] = 4
        for orb in [GridPoint(col: 1, row: 3), GridPoint(col: cols - 2, row: 3), GridPoint(col: 1, row: rows - 4), GridPoint(col: cols - 2, row: rows - 4)] {
            maze.tiles[GameConfig.idx(orb.col, orb.row)] = maze.tiles[GameConfig.idx(orb.col, orb.row)] == 1 ? 1 : 3
        }
        return maze
    }
}
