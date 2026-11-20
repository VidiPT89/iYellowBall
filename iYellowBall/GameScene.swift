import SpriteKit

final class GameScene: SKScene {

    // MARK: Simulation state

    var cfg: DifficultyConfig = GameConfig.difficulties[.normal]!
    var difficulty: Difficulty = .normal
    var mode: GameMode = .classic

    var score = 0
    var level = 1
    var lives = 3
    var running = false
    var gamePaused = false
    var over = false
    var transitioning = false
    var transitionRemaining: Double = 0
    var transitionAction: (() -> Void)?
    var popping = false
    var popTimer: Double = 0
    var invulnerableTimer: Double = 0
    var freezeTimer: Double = 0
    var calmTimer: Double = 0
    var smashStreak = 0
    var extraLifeAwarded = false
    var gemToggle = false
    #if DEBUG
    /// Debug-only: the ball steers itself and cannot be caught (smoke tests, screenshots).
    var autopilot = false
    #endif

    var maze = MazeGenerator.make(seed: MazeGenerator.seed(forLevel: 1))
    var ball = Ball(home: GridPoint(col: 13, row: 21))
    var enemies: [Enemy] = []

    var collect: [Int] = []
    var remaining = 0

    // MARK: Rendering

    let simWidth = CGFloat(GameConfig.cols) * CGFloat(GameConfig.cell)
    let simHeight = CGFloat(GameConfig.rows) * CGFloat(GameConfig.cell)

    /// The hosting view fills the whole screen, so the scene insets itself to
    /// stay clear of the Dynamic Island and the home indicator.
    var topSafeInset: CGFloat = 0
    var bottomSafeInset: CGFloat = 0

    let mazeContainer = SKNode()
    var wallNode: SKNode?
    var gemNodes: [Int: SKShapeNode] = [:]
    var orbNodes: [Int: SKNode] = [:]

    let ballNode = SKNode()
    let ballBody = SKShapeNode(circleOfRadius: CGFloat(GameConfig.cell) * 0.45)
    let ballShine = SKShapeNode(circleOfRadius: CGFloat(GameConfig.cell) * 0.11)
    let ballEyes = SKNode()
    var enemyNodes: [EnemyKind: EnemyNode] = [:]

    var lastUpdateTime: TimeInterval = 0

    // MARK: UI (see GameScene+UI.swift)
    var hud = HUDNodes()
    var startOverlay: SKNode?
    var pauseOverlay: SKNode?
    var gameOverOverlay: SKNode?
    var toastNode: SKLabelNode?

    var buttons: [GameButton] = []
    var diffButtons: [Difficulty: (bg: SKShapeNode, name: SKLabelNode, meta: SKLabelNode)] = [:]
    var dailyButton: (bg: SKShapeNode, name: SKLabelNode, meta: SKLabelNode)?
    var startTitleLabel: SKLabelNode?
    var startHintLabel: SKLabelNode?
    var pauseTitleLabel: SKLabelNode?
    var pauseSubLabel: SKLabelNode?
    var pauseResumeLabel: SKLabelNode?
    var pauseResumeBg: SKShapeNode?
    var pauseMenuLabelNode: SKLabelNode?
    var pauseMenuBgNode: SKShapeNode?
    var gameOverTitleLabel: SKLabelNode?
    var gameOverStatsLabel: SKLabelNode?
    var gameOverReplayLabel: SKLabelNode?
    var gameOverCloseLabel: SKLabelNode?
    var gameOverReplayBg: SKShapeNode?
    var gameOverCloseBg: SKShapeNode?
    var creditLabel: SKLabelNode?
    var creditLinkLabel: SKLabelNode?
    var lastResult: (isNewBest: Bool, best: Int)?

    // Splash (see GameScene+Splash.swift)
    var splashOverlay: SKNode?
    var splashBg: SKShapeNode?
    var splashTitle: SKLabelNode?
    var splashBall: SKNode?
    var splashGems: [SKShapeNode] = []
    var splashCredit: SKLabelNode?
    var splashLink: SKLabelNode?
    var splashSkipLabel: SKLabelNode?
    var dpadNodes: [String: SKShapeNode] = [:]

    // Input (see GameScene+UI.swift)
    var heldDirs: [(id: AnyHashable, dir: Dir)] = []
    var activeTouchIds: [ObjectIdentifier: AnyHashable] = [:]
    var swipeStarts: [ObjectIdentifier: CGPoint] = [:]

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(hex: "#05060c")
        anchorPoint = .zero

        addChild(mazeContainer)
        buildEntityNodes()
        buildHUD()
        buildOverlays()
        buildSplash()
        refreshTexts()
        layout(size: size)

        newGame(difficulty: .normal)
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--smoke-test") {
            runGameplaySmokeTests()
            return
        }
        if let i = args.firstIndex(of: "--demo"), i + 1 < args.count {
            prepareDemo(args[i + 1])
            return
        }
        #endif
        playSplash()
        view.isMultipleTouchEnabled = true
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layout(size: size)
    }

    func layout(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        topSafeInset = view?.safeAreaInsets.top ?? 0
        bottomSafeInset = view?.safeAreaInsets.bottom ?? 0
        let hudHeight: CGFloat = 110 + topSafeInset
        let controlsHeight: CGFloat = 190 + bottomSafeInset
        let sideMargin: CGFloat = 12
        let availableW = size.width - sideMargin * 2
        let availableH = size.height - hudHeight - controlsHeight
        let s = max(1, min(availableW, availableH)) / simWidth
        mazeContainer.xScale = s
        mazeContainer.yScale = s
        let mazeScreenSize = simWidth * s
        let originX = (size.width - mazeScreenSize) / 2
        let bottomY = controlsHeight + max(0, (availableH - mazeScreenSize) / 2)
        mazeContainer.position = CGPoint(x: originX, y: bottomY)

        layoutHUD(size: size)
        layoutOverlays(size: size)
        layoutControls(size: size)
        layoutSplash(size: size)
    }

    /// Simulation space is y-down; SpriteKit is y-up.
    func localPoint(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: CGFloat(x), y: simHeight - CGFloat(y))
    }

    func screenVector(_ d: Dir) -> CGVector {
        CGVector(dx: CGFloat(d.x), dy: CGFloat(-d.y))
    }

    func tileCenter(_ c: Int, _ r: Int) -> CGPoint {
        localPoint(Double(c) * GameConfig.cell + GameConfig.cell / 2, Double(r) * GameConfig.cell + GameConfig.cell / 2)
    }

    var wallColor: SKColor { SKColor(hex: GameConfig.wallThemes[(level - 1) % GameConfig.wallThemes.count]) }

    // MARK: Maze build

    /// Walls are drawn as rounded neon pipes joining neighbouring wall tiles,
    /// then baked into one texture: they never change during a level.
    func buildMaze() {
        wallNode?.removeFromParent()
        gemNodes.values.forEach { $0.removeFromParent() }
        orbNodes.values.forEach { $0.removeFromParent() }
        gemNodes.removeAll()
        orbNodes.removeAll()

        let pipes = CGMutablePath()
        var pillars: [CGPoint] = []
        for r in 0..<GameConfig.rows {
            for c in 0..<GameConfig.cols {
                let v = maze.tiles[GameConfig.idx(c, r)]
                let i = GameConfig.idx(c, r)
                switch v {
                case 1:
                    let p = tileCenter(c, r)
                    var joined = false
                    for (dc, dr) in [(1, 0), (0, 1)] {
                        let nc = c + dc, nr = r + dr
                        guard nc < GameConfig.cols, nr < GameConfig.rows, maze.tiles[GameConfig.idx(nc, nr)] == 1 else { continue }
                        pipes.move(to: p)
                        pipes.addLine(to: tileCenter(nc, nr))
                        joined = true
                    }
                    let hasLeftOrUp = (c > 0 && maze.tiles[GameConfig.idx(c - 1, r)] == 1) || (r > 0 && maze.tiles[GameConfig.idx(c, r - 1)] == 1)
                    if !joined && !hasLeftOrUp { pillars.append(p) }
                case 0:
                    let gem = SKShapeNode(rectOf: CGSize(width: 3.6, height: 3.6))
                    gem.zRotation = .pi / 4
                    gem.fillColor = SKColor(hex: "#d8f6ff")
                    gem.strokeColor = .clear
                    gem.position = tileCenter(c, r)
                    mazeContainer.addChild(gem)
                    gemNodes[i] = gem
                case 3:
                    let orb = makeOrbNode()
                    orb.position = tileCenter(c, r)
                    mazeContainer.addChild(orb)
                    orbNodes[i] = orb
                default:
                    break
                }
            }
        }

        let layer = SKNode()
        let color = wallColor
        for (width, alpha) in [(11.0, 0.18), (7.0, 1.0)] as [(CGFloat, CGFloat)] {
            let node = SKShapeNode(path: pipes)
            node.strokeColor = color.withAlphaComponent(alpha)
            node.lineWidth = width
            node.lineCap = .round
            node.lineJoin = .round
            layer.addChild(node)
        }
        // Lone wall blocks are squares so they never read as something to collect.
        for p in pillars {
            let block = SKShapeNode(rectOf: CGSize(width: 9, height: 9), cornerRadius: 2)
            block.position = p
            block.fillColor = color
            block.strokeColor = color.withAlphaComponent(0.3)
            block.lineWidth = 2
            layer.addChild(block)
        }
        let core = SKShapeNode(path: pipes)
        core.strokeColor = SKColor(white: 1, alpha: 0.35)
        core.lineWidth = 1.5
        core.lineCap = .round
        layer.addChild(core)

        mazeContainer.addChild(layer)
        wallNode = layer
        let frame = layer.calculateAccumulatedFrame()
        if let view, frame.width > 0, frame.height > 0, let texture = view.texture(from: layer) {
            layer.removeFromParent()
            let sprite = SKSpriteNode(texture: texture)
            sprite.position = CGPoint(x: frame.midX, y: frame.midY)
            mazeContainer.addChild(sprite)
            wallNode = sprite
        }
        wallNode?.zPosition = 1
    }

    func makeOrbNode() -> SKNode {
        let orb = SKNode()
        orb.zPosition = 2
        let halo = SKShapeNode(circleOfRadius: 6.5)
        halo.fillColor = SKColor(hex: "#5cc8ff").withAlphaComponent(0.25)
        halo.strokeColor = .clear
        orb.addChild(halo)
        let flake = CGMutablePath()
        for k in 0..<3 {
            let a = CGFloat(k) * .pi / 3
            flake.move(to: CGPoint(x: cos(a) * 5, y: sin(a) * 5))
            flake.addLine(to: CGPoint(x: -cos(a) * 5, y: -sin(a) * 5))
        }
        let star = SKShapeNode(path: flake)
        star.strokeColor = SKColor(hex: "#e8faff")
        star.lineWidth = 1.6
        star.lineCap = .round
        orb.addChild(star)
        star.run(.repeatForever(.rotate(byAngle: .pi, duration: 2.4)))
        halo.run(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.5), .scale(to: 0.9, duration: 0.5)])))
        return orb
    }

    func buildEntityNodes() {
        ballBody.fillColor = SKColor(hex: "#ffd21f")
        ballBody.strokeColor = SKColor(hex: "#ffb300")
        ballBody.lineWidth = 1
        ballNode.addChild(ballBody)
        ballShine.fillColor = SKColor(white: 1, alpha: 0.75)
        ballShine.strokeColor = .clear
        ballNode.addChild(ballShine)
        for side: CGFloat in [-1, 1] {
            let eye = SKShapeNode(ellipseOf: CGSize(width: 3.4, height: 4.6))
            eye.fillColor = SKColor(hex: "#1a1300")
            eye.strokeColor = .clear
            eye.position = CGPoint(x: side * 3.2, y: 1.5)
            ballEyes.addChild(eye)
        }
        ballNode.addChild(ballEyes)
        ballNode.zPosition = 10
        mazeContainer.addChild(ballNode)

        for def in GameConfig.enemyDefs {
            let node = EnemyNode(colorHex: def.colorHex)
            node.zPosition = 9
            mazeContainer.addChild(node)
            enemyNodes[def.kind] = node
        }
    }

    func loadLevelMaze() {
        let seed: UInt64
        switch mode {
        case .classic: seed = MazeGenerator.seed(forLevel: level)
        case .daily(let base, _): seed = MazeGenerator.seed(forLevel: level, base: base)
        }
        maze = MazeGenerator.make(seed: seed)
        collect = maze.tiles.map { $0 == 0 ? 1 : ($0 == 3 ? 2 : 0) }
        remaining = collect.filter { $0 > 0 }.count
        buildMaze()
    }

    // MARK: Main loop

    override func update(_ currentTime: TimeInterval) {
        var dt = (currentTime - lastUpdateTime) * 1000
        if lastUpdateTime == 0 { dt = 16 }
        dt = min(40, dt)
        lastUpdateTime = currentTime

        tick(dt: dt)
        render()
    }

    func scheduleTransition(_ ms: Double, action: @escaping () -> Void) {
        transitionRemaining = ms
        transitionAction = action
    }

    func tick(dt: Double) {
        if gamePaused || over { return }

        if let action = transitionAction {
            transitionRemaining -= dt
            if transitionRemaining <= 0 {
                transitionAction = nil
                action()
            }
            return
        }

        if popping {
            popTimer += dt
            if popTimer >= GameConfig.popAnimMs { finishPop() }
            return
        }

        if !running || transitioning { return }

        stepEntity(ball, speed: GameConfig.baseBallSpeed * cfg.ballSpeedMul, dt: dt, pickDir: { [weak self] e, c, r in
            self?.pickBallDir(e, c, r) ?? .zero
        }, onEnter: { [weak self] c, r in
            self?.collectTile(c, r)
        })
        if transitioning { return }
        if ball.turnBufferMs > 0 {
            ball.turnBufferMs = max(0, ball.turnBufferMs - dt)
            if ball.turnBufferMs == 0 { ball.queuedDir = .zero }
        }
        if !ball.dir.isZero { ball.roll += dt * 0.012 }

        for e in enemies { updateEnemy(e, dt: dt) }

        if calmTimer > 0 { calmTimer -= dt }
        updateFreeze(dt)
        if invulnerableTimer > 0 { invulnerableTimer -= dt }

        checkEnemyCollisions()
    }

    // MARK: Render

    func render() {
        renderBall()
        for e in enemies { renderEnemy(e) }
    }

    func renderBall() {
        ballNode.position = localPoint(ball.x + GameConfig.cell / 2, ball.y + GameConfig.cell / 2)
        if popping {
            let p = CGFloat(min(1, popTimer / GameConfig.popAnimMs))
            ballNode.isHidden = false
            ballNode.setScale(1 + p * 0.8)
            ballNode.alpha = 1 - p
            ballEyes.isHidden = true
            return
        }
        ballNode.setScale(1)
        ballNode.alpha = 1
        ballEyes.isHidden = false
        ballNode.isHidden = invulnerableTimer > 0 && Int(CACurrentMediaTime() * 10) % 2 == 0
        let d = ball.dir.isZero ? ball.lastDir : ball.dir
        let v = screenVector(d)
        ballEyes.position = CGPoint(x: v.dx * 2.6, y: v.dy * 2.6)
        // The shine circles the ball as it rolls.
        let r = CGFloat(GameConfig.cell) * 0.22
        ballShine.position = CGPoint(x: -r * 0.6 + CGFloat(cos(ball.roll)) * r * 0.25, y: r * 0.7 + CGFloat(sin(ball.roll)) * r * 0.2)
    }

    func renderEnemy(_ e: Enemy) {
        guard let node = enemyNodes[e.kind] else { return }
        node.position = localPoint(e.x + GameConfig.cell / 2, e.y + GameConfig.cell / 2)
        if e.state == .dormant && !e.frozen {
            node.position.y += CGFloat(sin(e.wobble)) * 1.5
        }
        let dir = e.dir.isZero ? Dir(x: 0, y: 1) : e.dir
        let progress = e.state == .reforming ? min(1, e.timer / GameConfig.reformMs) : 1
        node.update(state: e.state, frozen: e.frozen, freezeLeft: freezeTimer, dir: screenVector(dir), reformProgress: progress)
    }

    // MARK: Effects

    func spawnScorePopup(x: Double, y: Double, text: String) {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 12
        label.fontColor = SKColor(hex: "#ffe28a")
        label.position = localPoint(x, y)
        label.zPosition = 20
        mazeContainer.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 14, duration: 0.6), .fadeOut(withDuration: 0.6)]),
            .removeFromParent(),
        ]))
    }

    func spawnShards(at point: CGPoint, color: SKColor, count: Int = 8) {
        for k in 0..<count {
            let shard = SKShapeNode(rectOf: CGSize(width: 3, height: 3))
            shard.fillColor = color
            shard.strokeColor = .clear
            shard.position = point
            shard.zPosition = 15
            mazeContainer.addChild(shard)
            let angle = CGFloat(k) / CGFloat(count) * .pi * 2 + CGFloat.random(in: -0.3...0.3)
            let dist = CGFloat.random(in: 10...20)
            shard.run(.sequence([
                .group([.moveBy(x: cos(angle) * dist, y: sin(angle) * dist, duration: 0.45),
                        .rotate(byAngle: .pi * 2, duration: 0.45),
                        .fadeOut(withDuration: 0.45)]),
                .removeFromParent(),
            ]))
        }
    }
}
