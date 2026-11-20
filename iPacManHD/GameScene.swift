import SpriteKit

final class GameScene: SKScene {

    // MARK: Simulation state (mirrors `state` in script.js)

    var cfg: DifficultyConfig = GameConfig.difficulties[.normal]!
    var difficulty: Difficulty = .normal

    var score = 0
    var level = 1
    var lives = 3
    var running = false
    var gamePaused = false
    var over = false
    var transitioning = false
    var transitionRemaining: Double = 0
    var transitionAction: (() -> Void)?
    var dying = false
    var dyingTimer: Double = 0
    var invulnerableTimer: Double = 0
    var frightenedTimer: Double = 0
    var ghostEatStreak = 0
    var extraLifeAwarded = false
    var phaseIndex = 0
    var phaseTimer: Double = 0
    var chompToggle = false

    var pacman = PacMan()
    var ghosts: [Ghost] = []

    var collect: [Int] = []
    var remaining = 0

    // MARK: Rendering

    let simWidth = CGFloat(GameConfig.cols) * CGFloat(GameConfig.cell)
    let simHeight = CGFloat(GameConfig.rows) * CGFloat(GameConfig.cell)

    /// The hosting view fills the whole screen (`.ignoresSafeArea()`), so the
    /// scene has to inset itself manually to stay clear of the notch/Dynamic
    /// Island and the home indicator — otherwise the HUD renders straight
    /// under the sensor housing on notched devices.
    var topSafeInset: CGFloat = 0
    var bottomSafeInset: CGFloat = 0

    let mazeContainer = SKNode()
    var dotNodes: [Int: SKShapeNode] = [:]
    var powerNodes: [Int: SKShapeNode] = [:]

    let pacmanNode = SKShapeNode()
    var ghostNodes: [String: GhostNode] = [:]

    var lastUpdateTime: TimeInterval = 0

    // MARK: UI (see GameScene+UI.swift)
    var hud = HUDNodes()
    var startOverlay: SKNode?
    var pauseOverlay: SKNode?
    var gameOverOverlay: SKNode?
    var toastNode: SKLabelNode?

    var buttons: [GameButton] = []
    var diffButtons: [Difficulty: (bg: SKShapeNode, name: SKLabelNode, meta: SKLabelNode)] = [:]
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

    // Splash / intro presentation (see GameScene+Splash.swift)
    var splashOverlay: SKNode?
    var splashBg: SKShapeNode?
    var splashTitle: SKLabelNode?
    var splashPac: SKShapeNode?
    var splashDots: [SKShapeNode] = []
    var splashCredit: SKLabelNode?
    var splashLink: SKLabelNode?
    var splashSkipLabel: SKLabelNode?
    var dpadNodes: [String: SKShapeNode] = [:]

    // Input (see GameScene+UI.swift)
    var heldDirs: [(id: AnyHashable, dir: Dir)] = []
    var activeTouchIds: [ObjectIdentifier: AnyHashable] = [:]

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(hex: "#010102")
        anchorPoint = .zero

        addChild(mazeContainer)
        buildMaze()
        buildEntityNodes()
        buildHUD()
        buildOverlays()
        buildSplash()
        refreshTexts()
        layout(size: size)

        newGame(difficulty: .normal)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--smoke-test") {
            runGameplaySmokeTests()
        } else {
            playSplash()
        }
        #else
        playSplash()
        #endif

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
        let sideMargin: CGFloat = 16
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

    /// Converts a JS-style top-down (x right, y down) simulation coordinate
    /// into this scene's `mazeContainer`-local (y-up) coordinate space.
    func localPoint(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: CGFloat(x), y: simHeight - CGFloat(y))
    }

    /// Converts a JS-style direction vector (y+ = down) into a screen-space
    /// vector (y+ = up) for rotation/eye-offset math.
    func screenVector(_ d: Dir) -> CGVector {
        CGVector(dx: CGFloat(d.x), dy: CGFloat(-d.y))
    }

    // MARK: Maze build

    func buildMaze() {
        // Walls never change after this point, so they're built into a
        // throwaway layer and baked into a single cached texture instead of
        // staying as ~480 individual glowing SKShapeNodes: SpriteKit has to
        // re-render every node's glow pass each frame regardless of whether
        // it changed, and that many was enough to tank frame rate on older
        // devices — the exact stutter already fixed for the web build in
        // "Fix severe frame-rate stutter by caching the static maze layers".
        let wallLayer = SKNode()
        let wallPath = CGMutablePath()
        for r in 0..<GameConfig.rows {
            for c in 0..<GameConfig.cols {
                let v = GameConfig.maze[GameConfig.idx(c, r)]
                let x = Double(c) * GameConfig.cell
                let y = Double(r) * GameConfig.cell
                if v == 1 {
                    let path = wallPath
                    func wall(_ col: Int, _ row: Int) -> Bool {
                        col >= 0 && col < GameConfig.cols && row >= 0 && row < GameConfig.rows && GameConfig.maze[GameConfig.idx(col, row)] == 1
                    }
                    func edge(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) {
                        path.move(to: localPoint(ax, ay))
                        path.addLine(to: localPoint(bx, by))
                    }
                    let cell = GameConfig.cell
                    if !wall(c, r - 1) { edge(x, y, x + cell, y) }
                    if !wall(c, r + 1) { edge(x, y + cell, x + cell, y + cell) }
                    if !wall(c - 1, r) { edge(x, y, x, y + cell) }
                    if !wall(c + 1, r) { edge(x + cell, y, x + cell, y + cell) }
                } else if v == 0 {
                    let node = SKShapeNode(circleOfRadius: 2.1)
                    node.fillColor = SKColor(hex: "#ffe28a")
                    node.strokeColor = SKColor(hex: "#ffe28a")
                    node.glowWidth = 0
                    node.position = localPoint(x + GameConfig.cell / 2, y + GameConfig.cell / 2)
                    mazeContainer.addChild(node)
                    dotNodes[GameConfig.idx(c, r)] = node
                } else if v == 3 {
                    let node = SKShapeNode(circleOfRadius: 5.5)
                    node.fillColor = SKColor(hex: "#ffe28a")
                    node.strokeColor = SKColor(hex: "#ffe28a")
                    node.glowWidth = 4
                    node.position = localPoint(x + GameConfig.cell / 2, y + GameConfig.cell / 2)
                    let pulse = SKAction.repeatForever(.sequence([
                        .scale(to: 1.28, duration: 0.28), .scale(to: 0.85, duration: 0.28),
                    ]))
                    node.run(pulse)
                    mazeContainer.addChild(node)
                    powerNodes[GameConfig.idx(c, r)] = node
                }
            }
        }

        for (width, color) in [(5.0, "#1637b7"), (1.5, "#557dff")] {
            let node = SKShapeNode(path: wallPath)
            node.strokeColor = SKColor(hex: color)
            node.lineWidth = width
            wallLayer.addChild(node)
        }
        let door = SKShapeNode(rectOf: CGSize(width: 40, height: 3))
        door.fillColor = SKColor(hex: "#ffb8de")
        door.strokeColor = .clear
        door.position = localPoint(280, 224.5)
        wallLayer.addChild(door)
        mazeContainer.addChild(wallLayer)
        let frame = wallLayer.calculateAccumulatedFrame()
        if let view, frame.width > 0, frame.height > 0, let texture = view.texture(from: wallLayer) {
            wallLayer.removeFromParent()
            let sprite = SKSpriteNode(texture: texture)
            sprite.position = CGPoint(x: frame.midX, y: frame.midY)
            mazeContainer.addChild(sprite)
        }
        // If the view/texture snapshot isn't available yet, fall back to
        // leaving the individual nodes in the tree rather than losing walls.
    }

    func buildEntityNodes() {
        pacmanNode.fillColor = SKColor(hex: "#ffd400")
        pacmanNode.strokeColor = SKColor(hex: "#ffd400")
        pacmanNode.lineWidth = 0.5
        pacmanNode.glowWidth = 0.5
        pacmanNode.zPosition = 10
        mazeContainer.addChild(pacmanNode)

        for def in GameConfig.ghostDefs {
            let gn = GhostNode(colorHex: def.colorHex)
            gn.zPosition = 9
            mazeContainer.addChild(gn)
            ghostNodes[def.name] = gn
        }
    }

    func resetCollectibles() {
        collect = GameConfig.maze.map { $0 == 0 ? 1 : ($0 == 3 ? 2 : 0) }
        remaining = collect.filter { $0 > 0 }.count
        for (i, node) in dotNodes { node.isHidden = collect[i] != 1 }
        for (i, node) in powerNodes { node.isHidden = collect[i] != 2 }
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

        if dying {
            dyingTimer += dt

            if dyingTimer >= GameConfig.deathAnimMs { finishDeathSequence() }
            return
        }

        if !running || transitioning {

            return
        }

        stepEntity(pacman, speed: GameConfig.basePacSpeed * cfg.pacSpeedMul, dt: dt, pickDir: { [weak self] e, c, r in
            self?.pickPacDir(e, c, r) ?? .zero
        }, onEnter: { [weak self] c, r in
            self?.handleDotConsumption(c, r)
        })
        if transitioning { return }
        if pacman.turnBufferMs > 0 {
            pacman.turnBufferMs = max(0, pacman.turnBufferMs - dt)
            if pacman.turnBufferMs == 0 { pacman.queuedDir = .zero }
        }
        pacman.mouthPhase += (pacman.dir.x != 0 || pacman.dir.y != 0) ? dt * 0.012 : 0

        for g in ghosts { updateGhost(g, dt: dt) }

        updatePhase(dt)
        updateFrightened(dt)

        if invulnerableTimer > 0 { invulnerableTimer -= dt }

        checkGhostCollisions()
    }

    // MARK: Render (mirrors draw() in script.js)

    func render() {
        if dying {
            renderPacmanDying()
            for g in ghosts { renderGhost(g) }
        } else {
            for g in ghosts { renderGhost(g) }
            renderPacman()
        }
    }

    func renderPacman() {
        pacmanNode.alpha = 1
        let blinking = invulnerableTimer > 0 && Int(CACurrentMediaTime() * 10) % 2 == 0
        pacmanNode.isHidden = blinking
        if blinking { return }
        pacmanNode.position = localPoint(pacman.x + GameConfig.cell / 2, pacman.y + GameConfig.cell / 2)
        let r = CGFloat(GameConfig.cell) * 0.46
        let d = (pacman.dir.x != 0 || pacman.dir.y != 0) ? pacman.dir : pacman.lastDir
        let sv = screenVector(d)
        let angle = atan2(sv.dy, sv.dx)
        let mouth = abs(sin(pacman.mouthPhase)) * 0.26 * .pi + 0.02
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addArc(center: .zero, radius: r, startAngle: mouth, endAngle: .pi * 2 - mouth, clockwise: false)
        path.closeSubpath()
        pacmanNode.path = path
        pacmanNode.zRotation = angle
    }

    func renderPacmanDying() {
        pacmanNode.isHidden = false
        pacmanNode.position = localPoint(pacman.x + GameConfig.cell / 2, pacman.y + GameConfig.cell / 2)
        let progress = min(1, dyingTimer / GameConfig.deathAnimMs)
        let r = CGFloat(GameConfig.cell) * 0.46 * (1 - max(0, progress - 0.75) / 0.25)
        let mouth = progress * .pi * 0.97
        let spin = progress * .pi * 1.4
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addArc(center: .zero, radius: max(0, r), startAngle: mouth, endAngle: .pi * 2 - mouth, clockwise: false)
        path.closeSubpath()
        pacmanNode.path = path
        pacmanNode.zRotation = spin
        pacmanNode.alpha = 1 - max(0, progress - 0.8) / 0.2
    }

    func renderGhost(_ g: Ghost) {
        guard let node = ghostNodes[g.name] else { return }
        node.isHidden = false
        node.position = localPoint(g.x + GameConfig.cell / 2, g.y + GameConfig.cell / 2)
        let dir = (g.dir.x != 0 || g.dir.y != 0) ? g.dir : Dir(x: 0, y: 1)
        node.updateAppearance(state: g.state, dir: screenVector(dir), frightenedTimer: frightenedTimer)
    }

    // MARK: Score popups

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

}
