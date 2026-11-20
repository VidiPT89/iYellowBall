import Foundation

/// Grid direction (x right, y down).
struct Dir: Equatable {
    var x: Int
    var y: Int
    static let zero = Dir(x: 0, y: 0)
    var reversed: Dir { Dir(x: -x, y: -y) }
    var isZero: Bool { x == 0 && y == 0 }

    /// Order used for tie-breaks when enemies pick a corridor.
    static let all = [Dir(x: 0, y: -1), Dir(x: -1, y: 0), Dir(x: 0, y: 1), Dir(x: 1, y: 0)]
}

struct GridPoint: Equatable, Hashable {
    var col: Int
    var row: Int
}

enum Difficulty: String, CaseIterable {
    case easy, normal, hard
}

enum GameMode: Equatable {
    case classic
    /// A maze sequence seeded by the calendar day, the same for every player.
    case daily(seed: UInt64, key: String)
}

struct DifficultyConfig {
    let lives: Int
    let ballSpeedMul: Double
    let enemySpeedMul: Double
    let freezeMs: Double
    let releaseDelays: [Double]
    let extraLifeScore: Int
}

enum GameConfig {
    static let difficulties: [Difficulty: DifficultyConfig] = [
        .easy: DifficultyConfig(lives: 4, ballSpeedMul: 0.85, enemySpeedMul: 0.70, freezeMs: 8000, releaseDelays: [600, 2600, 5200, 8000], extraLifeScore: 6000),
        .normal: DifficultyConfig(lives: 3, ballSpeedMul: 0.95, enemySpeedMul: 0.82, freezeMs: 6500, releaseDelays: [500, 2000, 4200, 6500], extraLifeScore: 8000),
        .hard: DifficultyConfig(lives: 2, ballSpeedMul: 1.05, enemySpeedMul: 0.95, freezeMs: 5000, releaseDelays: [400, 1300, 2800, 4500], extraLifeScore: 10000),
    ]

    /// Odd size so the generator can alternate cell/wall tiles.
    static let cols = 27
    static let rows = 27
    static let cell: Double = 20 // simulation units; speeds are tuned against this

    static let baseBallSpeed = 0.125 // sim units / ms
    static let baseEnemySpeed = 0.115
    static let popAnimMs = 900.0
    static let readyPauseMs = 650.0
    static let calmMs = 4000.0
    static let reformMs = 3000.0
    static let smashValues = [100, 200, 400, 800]

    static func idx(_ col: Int, _ row: Int) -> Int { row * cols + col }

    struct EnemyDef {
        let kind: EnemyKind
        let colorHex: String
        let spawn: GridPoint
    }

    static let enemyDefs: [EnemyDef] = [
        EnemyDef(kind: .hunter, colorHex: "#ff4d5e", spawn: GridPoint(col: 12, row: 12)),
        EnemyDef(kind: .cutter, colorHex: "#3ee07a", spawn: GridPoint(col: 14, row: 12)),
        EnemyDef(kind: .drifter, colorHex: "#b06bff", spawn: GridPoint(col: 12, row: 14)),
        EnemyDef(kind: .guard, colorHex: "#ff9d2e", spawn: GridPoint(col: 14, row: 14)),
    ]

    /// Wall colour per level, cycling. Kept away from the ball's yellow.
    static let wallThemes = ["#1fc8b8", "#8a5cff", "#3ccf6e", "#ff5fa2"]
}

enum EnemyKind: String {
    /// Heads straight for the ball.
    case hunter
    /// Races to the next junction the ball is rolling towards.
    case cutter
    /// Wanders at random until the ball comes close, then pounces.
    case drifter
    /// Camps the ice orb nearest the ball while any are left.
    case `guard`
}
