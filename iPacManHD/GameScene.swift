import SpriteKit

/// A small particle used for the death explosion, ported from the JS
/// `particles` array (plain data, drawn each frame as a filled square).
struct Particle {
    var x: Double
    var y: Double
    var vx: Double
    var vy: Double
    var life: Double = 0
    var maxLife: Double
    var color: SKColor
    var size: CGFloat
    weak var node: SKShapeNode?
}

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
    var particles: [Particle] = []

    var collect: [Int] = []
    var remaining = 0

    // MARK: Rendering

    let simWidth = CGFloat(GameConfig.cols) * CGFloat(GameConfig.cell)
    let simHeight = CGFloat(GameConfig.rows) * CGFloat(GameConfig.cell)
    var renderScale: CGFloat = 1

    /// The hosting view fills the whole screen (`.ignoresSafeArea()`), so the
    /// scene has to inset itself manually to stay clear of the notch/Dynamic
    /// Island and the home indicator — otherwise the HUD renders straight
    /// under the sensor housing on notched devices.
    var topSafeInset: CGFloat = 0
    var bottomSafeInset: CGFloat = 0

    let mazeContainer = SKNode()
    var wallNodes: [SKShapeNode] = []
    var dotNodes: [Int: SKShapeNode] = [:]
    var powerNodes: [Int: SKShapeNode] = [:]
    let particlesContainer = SKNode()

    let pacmanNode = SKShapeNode()
    var ghostNodes: [String: GhostNode] = [:]

    var lastUpdateTime: TimeInterval = 0

    struct Mote { let node: SKShapeNode; let speed: CGFloat; var phase: CGFloat }
    var motes: [Mote] = []

    // MARK: UI (see GameScene+UI.swift)
    var hud = HUDNodes()
    var startOverlay: SKNode?
    var pauseOverlay: SKNode?
    var gameOverOverlay: SKNode?
    var toastNode: SKLabelNode?

    var buttons: [UIButton] = []
    var diffButtons: [Difficulty: (bg: SKShapeNode, name: SKLabelNode, meta: SKLabelNode)] = [:]
    var startTitleLabel: SKLabelNode?
    var startHintLabel: SKLabelNode?
    var pauseTitleLabel: SKLabelNode?
    var pauseSubLabel: SKLabelNode?
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

        buildAmbientBackground()
        addChild(mazeContainer)
        mazeContainer.addChild(particlesContainer)
        buildMaze()
        buildEntityNodes()
        buildHUD()
        buildOverlays()
        buildSplash()
        refreshTexts()
        layout(size: size)

        newGame(difficulty: .normal)
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
        let sideMargin: CGFloat = 16
        let availableW = size.width - sideMargin * 2
        let availableH = size.height - hudHeight - controlsHeight
        let s = max(1, min(availableW, availableH)) / simWidth
        renderScale = s
        mazeContainer.xScale = s
        mazeContainer.yScale = s
        let mazeScreenSize = simWidth * s
        let originX = (size.width - mazeScreenSize) / 2
        let bottomY = controlsHeight
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
        for r in 0..<GameConfig.rows {
            for c in 0..<GameConfig.cols {
                let v = GameConfig.maze[GameConfig.idx(c, r)]
                let x = Double(c) * GameConfig.cell
                let y = Double(r) * GameConfig.cell
                if v == 1 {
                    let node = SKShapeNode(rectOf: CGSize(width: GameConfig.cell - 2.4, height: GameConfig.cell - 2.4), cornerRadius: 4)
                    node.fillColor = SKColor(hex: "#152048")
                    node.strokeColor = SKColor(hex: "#4d78ff")
                    node.lineWidth = 1.3
                    node.glowWidth = 2.2
                    node.position = localPoint(x + GameConfig.cell / 2, y + GameConfig.cell / 2)
                    mazeContainer.addChild(node)
                    wallNodes.append(node)
                } else if v == 0 {
                    let node = SKShapeNode(circleOfRadius: 2.1)
                    node.fillColor = SKColor(hex: "#ffe28a")
                    node.strokeColor = SKColor(hex: "#ffe28a")
                    node.glowWidth = 1.5
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
    }

    func buildEntityNodes() {
        pacmanNode.fillColor = SKColor(hex: "#ffd400")
        pacmanNode.strokeColor = SKColor(hex: "#ffd400")
        pacmanNode.lineWidth = 0.5
        pacmanNode.glowWidth = 6
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

        updateAmbientBackground(dt: dt)
        tick(dt: dt)
        render()
    }

    // MARK: Ambient background (subtle drifting/twinkling dots, always animating)

    func buildAmbientBackground() {
        let count = 46
        for _ in 0..<count {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.6...1.8))
            dot.fillColor = SKColor(white: 0.96, alpha: 0.5)
            dot.strokeColor = .clear
            dot.zPosition = -10
            dot.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
            addChild(dot)
            motes.append(Mote(node: dot, speed: CGFloat.random(in: 4...16), phase: CGFloat.random(in: 0...(2 * .pi))))
        }
    }

    func updateAmbientBackground(dt: Double) {
        guard size.height > 0 else { return }
        for i in motes.indices {
            var mote = motes[i]
            mote.node.position.y -= mote.speed * CGFloat(dt / 1000)
            if mote.node.position.y < -5 {
                mote.node.position.y = size.height + 5
                mote.node.position.x = CGFloat.random(in: 0...size.width)
            }
            mote.phase += CGFloat(dt) * 0.002
            mote.node.alpha = 0.15 + (sin(mote.phase) * 0.5 + 0.5) * 0.35
            motes[i] = mote
        }
    }

    func tick(dt: Double) {
        if gamePaused || over { return }

        if dying {
            dyingTimer += dt
            updateParticles(dt)
            if dyingTimer >= GameConfig.deathAnimMs { finishDeathSequence() }
            return
        }

        if !running || transitioning {
            updateParticles(dt)
            return
        }

        stepEntity(pacman, speed: GameConfig.basePacSpeed, dt: dt, pickDir: { [weak self] e, c, r in
            self?.pickPacDir(e, c, r) ?? .zero
        }, onEnter: { [weak self] c, r in
            self?.handleDotConsumption(c, r)
        })
        pacman.mouthPhase += (pacman.dir.x != 0 || pacman.dir.y != 0) ? dt * 0.012 : 0

        for g in ghosts { updateGhost(g, dt: dt) }

        updatePhase(dt)
        updateFrightened(dt)
        updateParticles(dt)
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
        renderParticles()
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

    // MARK: Particles

    func spawnExplosion(x: Double, y: Double, color: SKColor, count: Int = 22) {
        for _ in 0..<count {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = 40.0 + Double.random(in: 0...160)
            let size = CGFloat(2 + Double.random(in: 0...2.5))
            let node = SKShapeNode(rectOf: CGSize(width: size, height: size))
            node.fillColor = color
            node.strokeColor = .clear
            node.position = localPoint(x, y)
            particlesContainer.addChild(node)
            let p = Particle(x: x, y: y, vx: cos(angle) * speed, vy: sin(angle) * speed,
                              maxLife: 350 + Double.random(in: 0...250), color: color, size: size, node: node)
            particles.append(p)
        }
    }

    func updateParticles(_ dt: Double) {
        for i in particles.indices.reversed() {
            particles[i].life += dt
            particles[i].x += particles[i].vx * (dt / 1000)
            // vy is in JS "down positive" convention; gravity adds to it.
            particles[i].y += particles[i].vy * (dt / 1000)
            particles[i].vy += 60 * (dt / 1000)
            if particles[i].life >= particles[i].maxLife {
                particles[i].node?.removeFromParent()
                particles.remove(at: i)
            }
        }
    }

    func shakeCamera() {
        let basePos = mazeContainer.position
        let shake = SKAction.sequence([
            .moveBy(x: 6, y: 0, duration: 0.04), .moveBy(x: -12, y: 0, duration: 0.08),
            .moveBy(x: 12, y: 0, duration: 0.08), .moveBy(x: -6, y: 0, duration: 0.04),
        ])
        mazeContainer.run(shake) { [weak self] in self?.mazeContainer.position = basePos }
    }

    func renderParticles() {
        for p in particles {
            guard let node = p.node else { continue }
            node.position = localPoint(p.x, p.y)
            node.alpha = max(0, 1 - p.life / p.maxLife)
        }
    }
}
