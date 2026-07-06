import Foundation

// Grid coordinate helper.
struct Dir: Equatable {
    var x: Int
    var y: Int
    static let zero = Dir(x: 0, y: 0)
    static func == (a: Dir, b: Dir) -> Bool { a.x == b.x && a.y == b.y }
    var reversed: Dir { Dir(x: -x, y: -y) }
}

struct GridPoint {
    var col: Int
    var row: Int
}

enum Difficulty: String, CaseIterable {
    case easy, normal, hard
}

struct DifficultyConfig {
    let lives: Int
    let ghostSpeedMul: Double
    let frightenedMs: Double
    let releaseDelays: [Double]
    let extraLifeScore: Int
}

enum GameConfig {
    static let difficulties: [Difficulty: DifficultyConfig] = [
        .easy: DifficultyConfig(lives: 4, ghostSpeedMul: 0.82, frightenedMs: 9000, releaseDelays: [150, 2200, 6000, 10000], extraLifeScore: 8000),
        .normal: DifficultyConfig(lives: 3, ghostSpeedMul: 0.94, frightenedMs: 7000, releaseDelays: [150, 2000, 5500, 9000], extraLifeScore: 10000),
        .hard: DifficultyConfig(lives: 2, ghostSpeedMul: 1.08, frightenedMs: 5000, releaseDelays: [150, 1200, 3800, 6500], extraLifeScore: 12000),
    ]

    // 0 = dot, 1 = wall, 2 = ghost house, 3 = power pellet, 4 = empty path
    static let cols = 28
    static let rows = 28
    static let cell: Double = 20 // internal simulation units (px/ms speeds are tuned against this)

    static let maze: [Int] = [
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,
        1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1,
        1,3,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,3,1,
        1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1,
        1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
        1,0,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,0,1,
        1,0,1,1,1,1,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,0,1,
        1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,
        1,1,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1,
        1,1,1,1,1,1,0,1,1,4,4,4,4,4,4,4,4,4,4,1,1,0,1,1,1,1,1,1,
        1,1,1,1,1,1,0,1,1,4,1,1,1,2,2,1,1,1,4,1,1,0,1,1,1,1,1,1,
        1,1,1,1,1,1,0,1,1,4,1,2,2,2,2,2,2,1,4,1,1,0,1,1,1,1,1,1,
        4,4,4,4,4,4,0,0,0,4,1,2,2,2,2,2,2,1,4,0,0,0,4,4,4,4,4,4,
        1,1,1,1,1,1,0,1,1,4,1,2,2,2,2,2,2,1,4,1,1,0,1,1,1,1,1,1,
        1,1,1,1,1,1,0,1,1,4,1,1,1,1,1,1,1,1,4,1,1,0,1,1,1,1,1,1,
        1,1,1,1,1,1,0,1,1,4,1,1,1,1,1,1,1,1,4,1,1,0,1,1,1,1,1,1,
        1,0,0,0,0,0,0,0,0,4,4,4,4,4,4,4,4,4,4,0,0,0,0,0,0,0,0,1,
        1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1,
        1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,0,1,1,1,1,1,0,1,1,1,1,0,1,
        1,3,0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,3,1,
        1,1,1,0,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1,0,1,1,1,
        1,1,1,0,1,1,0,1,1,0,1,1,1,1,1,1,1,1,0,1,1,0,1,1,0,1,1,1,
        1,0,0,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,1,1,0,0,0,0,0,0,1,
        1,0,1,1,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1,
        1,0,1,1,1,1,1,1,1,1,1,1,0,1,1,0,1,1,1,1,1,1,1,1,1,1,0,1,
        1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    ]

    static let pacHome = GridPoint(col: 14, row: 17)
    static let doorExit = GridPoint(col: 13, row: 10)
    static let houseEntry = GridPoint(col: 13, row: 12)

    struct GhostDef {
        let name: String
        let colorHex: String
        let home: GridPoint
        let scatter: GridPoint
    }

    static let ghostDefs: [GhostDef] = [
        GhostDef(name: "blinky", colorHex: "#ff2e6c", home: GridPoint(col: 12, row: 12), scatter: GridPoint(col: 26, row: 0)),
        GhostDef(name: "pinky", colorHex: "#ff8fd0", home: GridPoint(col: 12, row: 13), scatter: GridPoint(col: 1, row: 0)),
        GhostDef(name: "inky", colorHex: "#33e0ff", home: GridPoint(col: 15, row: 12), scatter: GridPoint(col: 26, row: 27)),
        GhostDef(name: "clyde", colorHex: "#ffb347", home: GridPoint(col: 15, row: 13), scatter: GridPoint(col: 1, row: 27)),
    ]

    enum PhaseMode { case scatter, chase }
    struct Phase { let mode: PhaseMode; let dur: Double }

    static let phases: [Phase] = [
        Phase(mode: .scatter, dur: 7000),
        Phase(mode: .chase, dur: 20000),
        Phase(mode: .scatter, dur: 7000),
        Phase(mode: .chase, dur: 20000),
        Phase(mode: .scatter, dur: 5000),
        Phase(mode: .chase, dur: 999_999),
    ]

    static let basePacSpeed = 0.155 // sim units / ms
    static let baseGhostSpeed = 0.135
    static let deathAnimMs = 900.0
    static let readyPauseMs = 650.0

    static func idx(_ col: Int, _ row: Int) -> Int { row * cols + col }

    /// Wraps column (tunnel), clamps row, returns tile value at (col,row).
    static func rawTile(_ col: Int, _ row: Int) -> Int {
        if row < 0 || row >= rows { return 1 }
        var c = col
        if c < 0 { c += cols }
        if c >= cols { c -= cols }
        return maze[idx(c, row)]
    }
}
