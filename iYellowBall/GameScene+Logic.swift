import SpriteKit

extension GameScene {

    // MARK: Ball steering

    func ballBlocked(_ col: Int, _ row: Int) -> Bool { maze.isWall(col, row) }

    func pickBallDir(_ e: Ball, _ col: Int, _ row: Int) -> Dir {
        #if DEBUG
        if autopilot { return autopilotDir(col, row) }
        #endif
        let q = ball.queuedDir
        if !q.isZero, !ballBlocked(col + q.x, row + q.y) {
            ball.lastDir = q
            if heldDirs.isEmpty { ball.queuedDir = .zero; ball.turnBufferMs = 0 }
            return q
        }
        if !e.dir.isZero, !ballBlocked(col + e.dir.x, row + e.dir.y) { return e.dir }
        // Follow a plain bend on its own (only one way on); at a real junction
        // the player chooses, so the ball waits there.
        if !e.dir.isZero {
            let reverse = e.dir.reversed
            let options = Dir.all.filter { $0 != reverse && !ballBlocked(col + $0.x, row + $0.y) }
            if options.count == 1 {
                ball.lastDir = options[0]
                return options[0]
            }
        }
        return .zero
    }

    // MARK: Enemy AI

    func enemyBlocked(_ col: Int, _ row: Int) -> Bool { maze.isWall(col, row) }

    /// Where an enemy wants to go, or nil to wander at random.
    func enemyTarget(_ enemy: Enemy) -> GridPoint? {
        if calmTimer > 0 { return nil }
        let b = GridPoint(col: ball.col, row: ball.row)
        switch enemy.kind {
        case .hunter:
            return b
        case .cutter:
            return nextJunctionAhead() ?? b
        case .drifter:
            return hypot(Double(enemy.col - b.col), Double(enemy.row - b.row)) <= 7 ? b : nil
        case .guard:
            let orbs = collect.indices.filter { collect[$0] == 2 }
                .map { GridPoint(col: $0 % GameConfig.cols, row: $0 / GameConfig.cols) }
            return orbs.min { distSq($0, b) < distSq($1, b) } ?? b
        }
    }

    func distSq(_ a: GridPoint, _ b: GridPoint) -> Int {
        (a.col - b.col) * (a.col - b.col) + (a.row - b.row) * (a.row - b.row)
    }

    /// Walks forward from the ball along its heading until a junction.
    func nextJunctionAhead() -> GridPoint? {
        let d = ball.dir.isZero ? ball.lastDir : ball.dir
        var c = ball.col, r = ball.row
        for _ in 0..<10 {
            guard !maze.isWall(c + d.x, r + d.y) else { return GridPoint(col: c, row: r) }
            c = (c + d.x + GameConfig.cols) % GameConfig.cols
            r += d.y
            if maze.openNeighbours(c, r) >= 3 { return GridPoint(col: c, row: r) }
        }
        return GridPoint(col: c, row: r)
    }

    func pickEnemyDir(_ enemy: Enemy, _ col: Int, _ row: Int) -> Dir {
        var options = Dir.all.filter { !enemyBlocked(col + $0.x, row + $0.y) }
        if options.count > 1 { options.removeAll { $0 == enemy.dir.reversed } }
        guard !options.isEmpty else { return .zero }
        guard let target = enemyTarget(enemy) else { return options.randomElement()! }
        return options.min { a, b in
            distSq(GridPoint(col: col + a.x, row: row + a.y), target) < distSq(GridPoint(col: col + b.x, row: row + b.y), target)
        }!
    }

    func enemySpeed() -> Double {
        let levelBonus = min(0.3, Double(level - 1) * 0.03)
        let calm = calmTimer > 0 ? 0.75 : 1
        return GameConfig.baseEnemySpeed * cfg.enemySpeedMul * (1 + levelBonus) * calm
    }

    func updateEnemy(_ enemy: Enemy, dt: Double) {
        enemy.wobble += dt * 0.006
        if enemy.frozen { return }
        switch enemy.state {
        case .dormant:
            enemy.timer += dt
            if enemy.timer >= enemy.releaseDelay {
                enemy.state = .roaming
                enemy.dir = Dir(x: 0, y: -1)
            }
        case .reforming:
            enemy.timer += dt
            if enemy.timer >= GameConfig.reformMs {
                enemy.state = .dormant
                enemy.timer = 0
                enemy.releaseDelay = 500
            }
        case .roaming:
            stepEntity(enemy, speed: enemySpeed(), dt: dt, pickDir: { [weak self] e, c, r in
                self?.pickEnemyDir(e, c, r) ?? .zero
            })
        }
    }

    // MARK: Collecting

    func collectTile(_ col: Int, _ row: Int) {
        let i = GameConfig.idx(col, row)
        switch collect[i] {
        case 1:
            collect[i] = 0; remaining -= 1
            gemNodes[i]?.isHidden = true
            score += 10
            updateScoreLabel()
            gemToggle.toggle()
            SoundEngine.shared.playGem(alt: gemToggle)
            checkExtraLife()
        case 2:
            collect[i] = 0; remaining -= 1
            orbNodes[i]?.isHidden = true
            score += 50
            updateScoreLabel()
            triggerFreeze()
            SoundEngine.shared.playFreeze()
            Haptics.impact(.medium)
            spawnScorePopup(x: Double(col) * GameConfig.cell + GameConfig.cell / 2, y: Double(row) * GameConfig.cell, text: "+50")
            checkExtraLife()
        default:
            break
        }
        if remaining <= 0 && !transitioning { levelComplete() }
    }

    func checkExtraLife() {
        if !extraLifeAwarded && score >= cfg.extraLifeScore {
            extraLifeAwarded = true
            lives += 1
            updateLivesHUD()
            showToast(L.t("extraLifeToast"))
            SoundEngine.shared.playExtraLife()
            Haptics.success()
        }
    }

    // MARK: Freeze

    /// Freeze time shortens 0.5 s per level, never below 40 % of the preset.
    func freezeDuration() -> Double {
        max(cfg.freezeMs * 0.4, cfg.freezeMs - Double(level - 1) * 500)
    }

    func triggerFreeze() {
        smashStreak = 0
        freezeTimer = freezeDuration()
        for e in enemies where e.state != .reforming { e.frozen = true }
        showToast(L.t("freezeToast"))
    }

    func updateFreeze(_ dt: Double) {
        guard freezeTimer > 0 else { return }
        freezeTimer -= dt
        if freezeTimer <= 0 {
            freezeTimer = 0
            for e in enemies { e.frozen = false }
        }
    }

    func smash(_ e: Enemy) {
        smashStreak += 1
        let value = GameConfig.smashValues[min(smashStreak - 1, GameConfig.smashValues.count - 1)]
        score += value
        updateScoreLabel()
        let center = localPoint(e.x + GameConfig.cell / 2, e.y + GameConfig.cell / 2)
        spawnShards(at: center, color: EnemyNode.ice)
        spawnScorePopup(x: e.x + GameConfig.cell / 2, y: e.y, text: "+\(value)")
        e.frozen = false
        e.state = .reforming
        e.timer = 0
        e.dir = .zero
        e.col = maze.plazaCenter.col; e.row = maze.plazaCenter.row
        e.x = Double(e.col) * GameConfig.cell; e.y = Double(e.row) * GameConfig.cell
        SoundEngine.shared.playSmash()
        Haptics.impact(.rigid)
        checkExtraLife()
    }

    // MARK: Lives

    func startPop() {
        popping = true
        popTimer = 0
        transitioning = true
        ball.dir = .zero
        ball.queuedDir = .zero
        spawnShards(at: localPoint(ball.x + GameConfig.cell / 2, ball.y + GameConfig.cell / 2), color: SKColor(hex: "#ffd21f"), count: 12)
        SoundEngine.shared.playPop()
        Haptics.error()
    }

    func finishPop() {
        popping = false
        lives -= 1
        updateLivesHUD()
        if lives <= 0 {
            transitioning = false
            endGame()
            return
        }
        respawnPositions()
        showToast(L.t("lifeLostToast"))
        scheduleTransition(GameConfig.readyPauseMs) { [weak self] in
            self?.transitioning = false
            self?.invulnerableTimer = 1600
        }
    }

    func respawnPositions() {
        ball.reset(to: maze.ballHome)
        heldDirs.removeAll()
        activeTouchIds.removeAll()
        swipeStarts.removeAll()
        for (i, e) in enemies.enumerated() { e.reset(releaseDelay: cfg.releaseDelays[i]) }
        freezeTimer = 0
        calmTimer = GameConfig.calmMs
    }

    func levelComplete() {
        transitioning = true
        showToast(L.levelClear(level))
        SoundEngine.shared.playLevelClear()
        Haptics.success()
        scheduleTransition(1600) { [weak self] in
            guard let self else { return }
            self.level += 1
            self.updateLevelLabel()
            self.loadLevelMaze()
            self.respawnPositions()
            self.transitioning = false
            self.showToast(L.levelIncoming(self.level))
        }
    }

    var bestKey: String {
        switch mode {
        case .classic: return "iyellowball.best.\(difficulty.rawValue)"
        case .daily(_, let key): return "iyellowball.best.daily.\(key)"
        }
    }

    func endGame() {
        over = true
        running = false
        let best = UserDefaults.standard.integer(forKey: bestKey)
        let isNewBest = score > best
        if isNewBest { UserDefaults.standard.set(score, forKey: bestKey) }
        lastResult = (isNewBest, max(best, score))
        showGameOverOverlay()
    }

    // MARK: Collisions

    func checkEnemyCollisions() {
        for e in enemies where e.state != .reforming {
            let dx = abs(e.x - ball.x)
            let dist = hypot(min(dx, Double(simWidth) - dx), e.y - ball.y)
            guard dist < GameConfig.cell * 0.6 else { continue }
            if e.frozen {
                smash(e)
            } else if invulnerableTimer <= 0 {
                #if DEBUG
                if autopilot { continue }
                #endif
                startPop()
                break
            }
        }
    }

    // MARK: New game

    static func dailyMode(for date: Date = Date()) -> GameMode {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let key = String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return .daily(seed: UInt64(key) ?? 1, key: key)
    }

    func newGame(difficulty: Difficulty, mode: GameMode = .classic) {
        toastNode?.removeFromParent()
        toastNode = nil
        transitionAction = nil
        transitionRemaining = 0
        popping = false
        popTimer = 0
        pauseOverlay?.isHidden = true
        cfg = GameConfig.difficulties[difficulty]!
        self.difficulty = difficulty
        self.mode = mode
        score = 0
        level = 1
        lives = cfg.lives
        running = false
        gamePaused = false
        over = false
        transitioning = false
        invulnerableTimer = 0
        smashStreak = 0
        extraLifeAwarded = false

        loadLevelMaze()
        ball = Ball(home: maze.ballHome)
        enemies = GameConfig.enemyDefs.enumerated().map { i, def in
            Enemy(def: def, releaseDelay: cfg.releaseDelays[i])
        }
        respawnPositions()

        updateScoreLabel()
        updateLevelLabel()
        updateLivesHUD()
        updateBestLabel()
        hideGameOverOverlay()
        showStartOverlay()
    }
}

#if DEBUG
extension GameScene {
    /// Debug autopilot: heads for the nearest gem by breadth-first search.
    func autopilotDir(_ col: Int, _ row: Int) -> Dir {
        var prev: [GridPoint: GridPoint] = [:]
        let start = GridPoint(col: col, row: row)
        var queue = [start]
        var head = 0
        var goal: GridPoint?
        while head < queue.count {
            let p = queue[head]; head += 1
            if p != start && collect[GameConfig.idx(p.col, p.row)] > 0 { goal = p; break }
            for d in Dir.all where !maze.isWall(p.col + d.x, p.row + d.y) {
                let n = GridPoint(col: (p.col + d.x + GameConfig.cols) % GameConfig.cols, row: p.row + d.y)
                if prev[n] == nil && n != start { prev[n] = p; queue.append(n) }
            }
        }
        guard var step = goal else { return .zero }
        while let p = prev[step], p != start { step = p }
        var dx = step.col - col
        if dx > 1 { dx = -1 } else if dx < -1 { dx = 1 }
        let d = Dir(x: dx, y: step.row - row)
        ball.lastDir = d
        return d
    }

    /// `--demo <scene>` stages a frame for App Store screenshots:
    /// menu, play, freeze or level3.
    func prepareDemo(_ scene: String) {
        splashOverlay?.isHidden = true
        if scene == "menu" { return }
        if scene == "daily" {
            newGame(difficulty: .normal, mode: Self.dailyMode())
        }
        hideStartOverlayNode()
        running = true
        autopilot = true
        if scene == "level3" {
            level = 3
            updateLevelLabel()
            loadLevelMaze()
            respawnPositions()
        }
        let seconds: Double = scene == "freeze" ? 9 : 14
        for _ in 0..<Int(seconds * 1000 / 16) { tick(dt: 16) }
        freezeTimer = 0
        enemies.forEach { $0.frozen = false }
        if scene == "freeze" {
            triggerFreeze()
            for _ in 0..<20 { tick(dt: 16) }
            toastNode?.removeFromParent()
        }
        invulnerableTimer = 0
        autopilot = false
        gamePaused = true // halts the simulation without showing the pause overlay
        render()
    }

    /// Launch a Debug build with --smoke-test; nothing is persisted.
    func runGameplaySmokeTests() {
        var checks = 0
        func check(_ value: Bool, _ name: String) {
            precondition(value, name)
            checks += 1
            print("PASS \(name)")
        }
        splashOverlay?.isHidden = true

        // Generator: deterministic, symmetric, fully connected, no dead ends.
        for level in 1...30 {
            let a = MazeGenerator.make(seed: MazeGenerator.seed(forLevel: level))
            let b = MazeGenerator.make(seed: MazeGenerator.seed(forLevel: level))
            check(a.tiles == b.tiles, "Maze \(level) deterministic")
            var symmetric = true
            for r in 0..<GameConfig.rows { for c in 0..<GameConfig.cols where a.tile(c, r) != a.tile(GameConfig.cols - 1 - c, r) { symmetric = false } }
            check(symmetric, "Maze \(level) symmetric")
            var deadEnds = 0
            for r in 0..<GameConfig.rows { for c in 0..<GameConfig.cols where !a.isWall(c, r) && a.openNeighbours(c, r) < 2 { deadEnds += 1 } }
            check(deadEnds == 0, "Maze \(level) has no dead ends")
            var seen: Set<GridPoint> = [a.ballHome]
            var queue = [a.ballHome]
            while let p = queue.popLast() {
                for d in Dir.all where !a.isWall(p.col + d.x, p.row + d.y) {
                    let n = GridPoint(col: (p.col + d.x + GameConfig.cols) % GameConfig.cols, row: p.row + d.y)
                    if seen.insert(n).inserted { queue.append(n) }
                }
            }
            let reachable = a.tiles.indices.allSatisfy { a.tiles[$0] == 1 || seen.contains(GridPoint(col: $0 % GameConfig.cols, row: $0 / GameConfig.cols)) }
            check(reachable, "Maze \(level) fully reachable")
            check(a.orbs.count == 4, "Maze \(level) has four ice orbs")
        }
        check(MazeGenerator.make(seed: MazeGenerator.seed(forLevel: 1)).tiles != MazeGenerator.make(seed: MazeGenerator.seed(forLevel: 2)).tiles, "Levels differ")

        newGame(difficulty: .normal)
        ball.x = Double(maze.ballHome.col) * GameConfig.cell + 7
        ball.dir = Dir(x: 1, y: 0)
        pressDir("test", Dir(x: -1, y: 0))
        check(ball.dir.x == -1, "Immediate reversal")

        newGame(difficulty: .normal)
        running = true
        enemies[0].state = .roaming
        triggerFreeze()
        check(enemies.allSatisfy { $0.frozen }, "Freeze reaches every enemy, including dormant ones")
        enemies[0].x = ball.x; enemies[0].y = ball.y
        checkEnemyCollisions()
        check(enemies[0].state == .reforming && !popping && score == 100, "Frozen enemy is smashed")
        freezeTimer = 1
        updateFreeze(16)
        check(enemies.allSatisfy { !$0.frozen }, "Freeze wears off")
        for _ in 0..<Int(GameConfig.reformMs / 16) + 2 { updateEnemy(enemies[0], dt: 16) }
        check(enemies[0].state == .dormant && !enemies[0].frozen, "Smashed enemy reforms unfrozen")

        newGame(difficulty: .normal)
        running = true
        calmTimer = 0
        let hunter = enemies[0]
        hunter.state = .roaming
        hunter.x = ball.x; hunter.y = ball.y
        checkEnemyCollisions()
        check(popping, "Roaming enemy pops the ball")
        for _ in 0..<100 { tick(dt: 16) }
        check(lives == 2 && !popping && !transitioning, "Pop and respawn")

        newGame(difficulty: .normal)
        running = true
        levelComplete()
        pauseGame()
        tick(dt: 2000)
        check(level == 1 && transitionRemaining == 1600, "Paused transition")
        resumeGame()
        tick(dt: 1600)
        check(level == 2 && transitionAction == nil && !transitioning, "Next level loads a new maze")

        newGame(difficulty: .normal)
        score = 7900
        enemies.forEach { $0.frozen = true; smash($0) }
        check(score == 7900 + 1500 && lives == 4, "Smash combo and single extra life")

        newGame(difficulty: .normal)
        level = 50
        check(freezeDuration() == cfg.freezeMs * 0.4, "Freeze time floor")

        let daily = Self.dailyMode(for: Date(timeIntervalSince1970: 1_800_000_000))
        newGame(difficulty: .normal, mode: daily)
        let dailyTiles = maze.tiles
        newGame(difficulty: .normal, mode: daily)
        check(maze.tiles == dailyTiles && bestKey.contains("daily"), "Daily maze is the same for everyone that day")

        newGame(difficulty: .normal)
        over = true
        lastResult = (false, 0)
        showGameOverOverlay()
        handleButtonTap("btn-close")
        check(!over && !running && startOverlay?.isHidden == false, "Close game over returns to menu")
        check(button(at: hud.pauseButton.position)?.id != "btn-pause", "Overlay blocks underlying HUD")

        let initialSize = size
        for viewport in [CGSize(width: 320, height: 568), CGSize(width: 402, height: 874), CGSize(width: 1032, height: 1376), CGSize(width: 1376, height: 1032)] {
            size = viewport
            layout(size: viewport)
            let board = CGRect(origin: mazeContainer.position, size: CGSize(width: simWidth * mazeContainer.xScale, height: simHeight * mazeContainer.yScale))
            check(board.minX >= 0 && board.maxX <= viewport.width && board.minY >= 0 && board.maxY <= viewport.height, "Maze fits \(viewport)")
        }
        size = initialSize
        layout(size: initialSize)

        // Autopilot clears a whole level without walls being crossed.
        newGame(difficulty: .normal)
        hideStartOverlayNode()
        running = true
        autopilot = true
        var frames = 0
        var onPaths = true
        while level == 1 && frames < 60 * 300 {
            tick(dt: 16)
            frames += 1
            if maze.isWall(ball.col, ball.row) || enemies.contains(where: { maze.isWall($0.col, $0.row) }) { onPaths = false }
        }
        check(level == 2 && onPaths, "Level 1 can be cleared, nobody walks through walls")
        autopilot = false

        FileHandle.standardError.write(Data("IYELLOWBALL SMOKE: \(checks) checks passed\n".utf8))
        newGame(difficulty: .normal)
    }
}
#endif
