import Foundation

protocol GridEntity: AnyObject {
    var col: Int { get set }
    var row: Int { get set }
    var x: Double { get set }
    var y: Double { get set }
    var dir: Dir { get set }
}

final class PacMan: GridEntity {
    var col: Int
    var row: Int
    var x: Double
    var y: Double
    var dir: Dir = .zero
    var queuedDir: Dir = .zero
    var lastDir: Dir = Dir(x: -1, y: 0)
    var turnBufferMs: Double = 0
    var mouthPhase: Double = 0

    init() {
        col = GameConfig.pacHome.col
        row = GameConfig.pacHome.row
        x = Double(col) * GameConfig.cell
        y = Double(row) * GameConfig.cell
    }

    func resetToHome() {
        col = GameConfig.pacHome.col
        row = GameConfig.pacHome.row
        x = Double(col) * GameConfig.cell
        y = Double(row) * GameConfig.cell
        dir = .zero
        queuedDir = .zero
        turnBufferMs = 0
    }
}

enum GhostState {
    case house, leaving, scatter, chase, frightened, eaten
}

final class Ghost: GridEntity {
    let name: String
    let home: GridPoint
    let scatter: GridPoint

    var col: Int
    var row: Int
    var x: Double
    var y: Double
    var dir: Dir = .zero
    var state: GhostState = .house
    var houseTimer: Double = 0
    var releaseDelay: Double
    var bouncePhase: Double = Double.random(in: 0...(2 * Double.pi))

    init(def: GameConfig.GhostDef, releaseDelay: Double) {
        name = def.name
        home = def.home
        scatter = def.scatter
        col = def.home.col
        row = def.home.row
        x = Double(col) * GameConfig.cell
        y = Double(row) * GameConfig.cell
        self.releaseDelay = releaseDelay
    }

    func resetToHome(releaseDelay: Double) {
        col = home.col
        row = home.row
        x = Double(col) * GameConfig.cell
        y = Double(row) * GameConfig.cell
        dir = .zero
        state = .house
        houseTimer = 0
        self.releaseDelay = releaseDelay
    }
}

/// Direct port of the JS `stepEntity`: slides an entity through the grid,
/// re-picking a direction whenever it lands exactly on a cell center.
func stepEntity<T: GridEntity>(_ e: T, speed: Double, dt: Double, pickDir: (T, Int, Int) -> Dir, onEnter: ((Int, Int) -> Void)? = nil) {
    var remainingDist = speed * dt
    var guardCount = 0
    let cell = GameConfig.cell
    let worldWidth = Double(GameConfig.cols) * cell

    while remainingDist > 0.001 && guardCount < 6 {
        guardCount += 1
        let modX = (e.x.truncatingRemainder(dividingBy: cell) + cell).truncatingRemainder(dividingBy: cell)
        let modY = (e.y.truncatingRemainder(dividingBy: cell) + cell).truncatingRemainder(dividingBy: cell)
        if modX < 0.05 && modY < 0.05 {
            var c = Int((e.x / cell).rounded())
            if c < 0 { c += GameConfig.cols }
            if c >= GameConfig.cols { c -= GameConfig.cols }
            let r = Int((e.y / cell).rounded())
            e.col = c; e.row = r
            e.x = Double(c) * cell; e.y = Double(r) * cell
            onEnter?(c, r)
            e.dir = pickDir(e, c, r)
        }
        if e.dir.x == 0 && e.dir.y == 0 { remainingDist = 0; break }
        let axisDir = e.dir.x != 0 ? e.dir.x : e.dir.y
        let axisPos = e.dir.x != 0 ? e.x : e.y
        let modPos = (axisPos.truncatingRemainder(dividingBy: cell) + cell).truncatingRemainder(dividingBy: cell)
        let distToBoundary: Double
        if modPos < 0.05 {
            distToBoundary = cell
        } else {
            distToBoundary = axisDir > 0 ? cell - modPos : modPos
        }
        let move = min(remainingDist, distToBoundary)
        e.x += Double(e.dir.x) * move
        e.y += Double(e.dir.y) * move
        remainingDist -= move

        if e.x < -0.01 { e.x += worldWidth }
        if e.x >= worldWidth - 0.01 { e.x -= worldWidth }
    }
}
