import SpriteKit

// Order matters for tie-breaks: matches the original arcade priority (up, left, down, right).
private let allDirs = [Dir(x: 0, y: -1), Dir(x: -1, y: 0), Dir(x: 0, y: 1), Dir(x: 1, y: 0)]

extension GameScene {

    // MARK: Pac-Man direction

    func pacBlocked(_ col: Int, _ row: Int) -> Bool {
        let v = GameConfig.rawTile(col, row)
        return v == 1 || v == 2
    }

    func pickPacDir(_ e: PacMan, _ col: Int, _ row: Int) -> Dir {
        let q = pacman.queuedDir
        if (q.x != 0 || q.y != 0), !pacBlocked(col + q.x, row + q.y) {
            pacman.lastDir = q
            if heldDirs.isEmpty { pacman.queuedDir = .zero; pacman.turnBufferMs = 0 }
            return q
        }
        if (e.dir.x != 0 || e.dir.y != 0), !pacBlocked(col + e.dir.x, row + e.dir.y) { return e.dir }
        // Pac-Man never idles through a plain corridor bend (exactly one non-reverse way
        // to continue: not a real choice, just the shape of the corridor). At a genuine
        // intersection (two or more non-reverse options) turning must be manual, so if
        // the player hasn't queued a valid direction there, he waits — same as a true
        // dead end, or before his very first move. This also avoids an infinite loop:
        // auto-picking a branch at a real intersection could otherwise trap him circling
        // the same handful of cells forever while a direction stays held.
        if e.dir.x != 0 || e.dir.y != 0 {
            let reverse = e.dir.reversed
            let options = allDirs.filter { !($0.x == reverse.x && $0.y == reverse.y) && !pacBlocked(col + $0.x, row + $0.y) }
            if options.count == 1 {
                pacman.lastDir = options[0]
                return options[0]
            }
            // A true dead end (no non-reverse way out): back out on his own instead of
            // freezing against the wall. Clearing the queued direction here is what keeps
            // this safe — without it, a direction still held on the D-pad would just walk
            // him straight back in next frame, producing the exact infinite bounce we
            // fixed before. A real intersection (2+ options) still needs a manual turn.
            if options.isEmpty, !pacBlocked(col + reverse.x, row + reverse.y) {
                pacman.queuedDir = .zero
                pacman.lastDir = reverse
                return reverse
            }
        }
        return .zero
    }

    // MARK: Ghost AI

    func ghostBlocked(_ ghost: Ghost, _ col: Int, _ row: Int) -> Bool {
        let v = GameConfig.rawTile(col, row)
        if v == 1 { return true }
        if v == 2 { return !(ghost.state == .leaving || ghost.state == .eaten || ghost.state == .house) }
        return false
    }

    func currentPhaseMode() -> GhostState {
        GameConfig.phases[phaseIndex].mode == .scatter ? .scatter : .chase
    }

    func getGhostTarget(_ ghost: Ghost) -> GridPoint {
        switch ghost.state {
        case .leaving: return GameConfig.doorExit
        case .eaten: return GameConfig.houseEntry
        case .scatter: return ghost.scatter
        default: break
        }
        let p = GridPoint(col: pacman.col, row: pacman.row)
        let pdir = (pacman.dir.x != 0 || pacman.dir.y != 0) ? pacman.dir : pacman.lastDir
        switch ghost.name {
        case "blinky":
            return p
        case "pinky":
            return GridPoint(col: p.col + pdir.x * 4, row: p.row + pdir.y * 4)
        case "inky":
            let pivot = GridPoint(col: p.col + pdir.x * 2, row: p.row + pdir.y * 2)
            let blinky = ghosts.first { $0.name == "blinky" }
            let bc = blinky?.col ?? p.col
            let br = blinky?.row ?? p.row
            return GridPoint(col: pivot.col + (pivot.col - bc), row: pivot.row + (pivot.row - br))
        case "clyde":
            let dist = hypot(Double(ghost.col - p.col), Double(ghost.row - p.row))
            return dist > 8 ? p : ghost.scatter
        default:
            return p
        }
    }

    func pickGhostDir(_ ghost: Ghost, _ col: Int, _ row: Int) -> Dir {
        let reverse = ghost.dir.reversed
        var options = allDirs.filter { !ghostBlocked(ghost, col + $0.x, row + $0.y) }
        if options.count > 1 {
            options = options.filter { !($0.x == reverse.x && $0.y == reverse.y) }
        }
        if options.isEmpty { return .zero }
        if ghost.state == .frightened {
            return options[Int.random(in: 0..<options.count)]
        }
        let target = getGhostTarget(ghost)
        var best = options[0]
        var bestDist = Double.infinity
        for d in options {
            let nc = col + d.x, nr = row + d.y
            let dist = Double((nc - target.col) * (nc - target.col) + (nr - target.row) * (nr - target.row))
            if dist < bestDist - 1e-6 { bestDist = dist; best = d }
        }
        return best
    }

    func ghostSpeedFor(_ ghost: Ghost) -> Double {
        let levelBonus = min(0.3, Double(level - 1) * 0.03)
        var mul = cfg.ghostSpeedMul * (1 + levelBonus)
        if ghost.state == .frightened { mul *= 0.55 }
        else if ghost.state == .eaten { mul *= 1.9 }
        if ghost.row == 13 && (ghost.x < 5 * GameConfig.cell || ghost.x > 22 * GameConfig.cell) && ghost.state != .eaten { mul *= 0.65 }
        return GameConfig.baseGhostSpeed * mul
    }

    func updateGhost(_ ghost: Ghost, dt: Double) {
        if ghost.state == .house {
            ghost.houseTimer += dt
            ghost.bouncePhase += dt * 0.006
            ghost.y = Double(ghost.home.row) * GameConfig.cell + sin(ghost.bouncePhase) * 8
            ghost.x = Double(ghost.home.col) * GameConfig.cell
            if ghost.houseTimer >= ghost.releaseDelay {
                ghost.state = .leaving
                ghost.col = ghost.home.col; ghost.row = ghost.home.row
                ghost.x = Double(ghost.col) * GameConfig.cell; ghost.y = Double(ghost.row) * GameConfig.cell
                ghost.dir = Dir(x: 0, y: -1)
            }
            return
        }
        stepEntity(ghost, speed: ghostSpeedFor(ghost), dt: dt, pickDir: { [weak self] _, c, r in
            self?.pickGhostDir(ghost, c, r) ?? .zero
        }, onEnter: { [weak self] c, r in
            guard let self else { return }
            if ghost.state == .leaving && r <= 10 {
                ghost.state = self.frightenedTimer > 0 ? .frightened : self.currentPhaseMode()
            }
            if ghost.state == .eaten && r >= 12 && r <= 13 && c >= 11 && c <= 16 {
                ghost.state = .house
                ghost.houseTimer = 0
                ghost.releaseDelay = 1200
            }
        })
    }

    // MARK: Gameplay events

    func handleDotConsumption(_ col: Int, _ row: Int) {
        let i = GameConfig.idx(col, row)
        let v = collect[i]
        if v == 1 {
            collect[i] = 0; remaining -= 1
            dotNodes[i]?.isHidden = true
            score += 10
            updateScoreLabel()
            chompToggle.toggle()
            SoundEngine.shared.playChomp(alt: chompToggle)
            checkExtraLife()
        } else if v == 2 {
            collect[i] = 0; remaining -= 1
            powerNodes[i]?.isHidden = true
            score += 50
            updateScoreLabel()
            triggerFrightened()
            SoundEngine.shared.playPower()
            Haptics.impact(.medium)
            spawnScorePopup(x: Double(col) * GameConfig.cell + GameConfig.cell / 2, y: Double(row) * GameConfig.cell, text: "+50")
            checkExtraLife()
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

    func triggerFrightened() {
        ghostEatStreak = 0
        frightenedTimer = cfg.frightenedMs
        for g in ghosts where g.state == .scatter || g.state == .chase || g.state == .frightened {
            if g.state != .frightened { g.dir = g.dir.reversed }
            g.state = .frightened
        }
    }

    func eatGhost(_ g: Ghost) {
        ghostEatStreak += 1
        let values = [200, 400, 800, 1600]
        let value = values[min(ghostEatStreak - 1, 3)]
        score += value
        updateScoreLabel()
        showToast(L.ghostEatToast(value))
        spawnScorePopup(x: g.x + GameConfig.cell / 2, y: g.y, text: "+\(value)")
        g.state = .eaten
        SoundEngine.shared.playEatGhost()
        Haptics.impact(.rigid)
        checkExtraLife()
    }

    func startDeathSequence() {
        dying = true
        dyingTimer = 0
        transitioning = true
        pacman.dir = .zero
        pacman.queuedDir = .zero
        SoundEngine.shared.playDeath()
        Haptics.error()

    }

    func finishDeathSequence() {
        dying = false
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
        phaseIndex = 0
        phaseTimer = 0
        pacman.resetToHome()
        heldDirs.removeAll()
        activeTouchIds.removeAll()
        for g in ghosts {
            let delay = cfg.releaseDelays[GameConfig.ghostDefs.firstIndex { $0.name == g.name } ?? 0]
            g.resetToHome(releaseDelay: delay)
        }
        frightenedTimer = 0
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
            self.resetCollectibles()
            self.respawnPositions()
            self.transitioning = false
            self.showToast(L.levelIncoming(self.level))
        }
    }

    func endGame() {
        over = true
        running = false
        let key = "pacmanhd.best.\(difficulty.rawValue)"
        let best = UserDefaults.standard.integer(forKey: key)
        var isNewBest = false
        if score > best {
            UserDefaults.standard.set(score, forKey: key)
            isNewBest = true
        }
        showGameOverOverlay(isNewBest: isNewBest, best: max(best, score))
    }

    // MARK: Phase / frightened timers

    func updatePhase(_ dt: Double) {
        guard frightenedTimer <= 0 else { return }
        phaseTimer += dt
        let phase = GameConfig.phases[phaseIndex]
        if phaseTimer >= phase.dur && phaseIndex < GameConfig.phases.count - 1 {
            phaseIndex += 1
            phaseTimer = 0
            for g in ghosts where g.state == .scatter || g.state == .chase {
                g.dir = g.dir.reversed
                g.state = currentPhaseMode()
            }
        }
    }

    func updateFrightened(_ dt: Double) {
        if frightenedTimer > 0 {
            frightenedTimer -= dt
            if frightenedTimer <= 0 {
                frightenedTimer = 0
                for g in ghosts where g.state == .frightened { g.state = currentPhaseMode() }
            }
        }
    }

    // MARK: Collisions

    func checkGhostCollisions() {
        for g in ghosts {
            if g.state == .house { continue }
            let dx = abs(g.x - pacman.x)
            let dist = hypot(min(dx, Double(simWidth) - dx), g.y - pacman.y)
            if dist < GameConfig.cell * 0.55 {
                if g.state == .frightened {
                    eatGhost(g)
                } else if g.state != .eaten {
                    if invulnerableTimer > 0 { continue }
                    startDeathSequence()
                    break
                }
            }
        }
    }

    // MARK: New game

    func newGame(difficulty: Difficulty) {
        toastNode?.removeFromParent()
        toastNode = nil
        transitionAction = nil
        transitionRemaining = 0
        dying = false
        dyingTimer = 0
        heldDirs.removeAll()
        activeTouchIds.removeAll()
        pauseOverlay?.isHidden = true
        cfg = GameConfig.difficulties[difficulty]!
        self.difficulty = difficulty
        score = 0
        level = 1
        lives = cfg.lives
        running = false
        gamePaused = false
        over = false
        transitioning = false
        invulnerableTimer = 0
        frightenedTimer = 0
        ghostEatStreak = 0
        extraLifeAwarded = false
        phaseIndex = 0
        phaseTimer = 0

        resetCollectibles()
        pacman = PacMan()
        ghosts = GameConfig.ghostDefs.enumerated().map { i, def in
            Ghost(def: def, releaseDelay: cfg.releaseDelays[i])
        }

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
    /// Exercise the real scene with deterministic frame advances on the simulator.
    /// Launch a Debug build with --smoke-test; no test state is persisted.
    func runGameplaySmokeTests() {
        var checks = 0
        func check(_ value: Bool, _ name: String) {
            precondition(value, name)
            checks += 1
            print("PASS \(name)")
        }
        newGame(difficulty: .normal)
        splashOverlay?.isHidden = true
        pacman.x = 287
        pacman.dir = Dir(x: 1, y: 0)
        pressDir("test", Dir(x: -1, y: 0))
        check(pacman.dir.x == -1 && pacman.x == 287, "Immediate reversal")
        phaseTimer = 6990
        triggerFrightened()
        updatePhase(40)
        check(phaseIndex == 0 && phaseTimer == 6990, "Frightened phase freeze")
        frightenedTimer = 0
        updatePhase(40)
        check(phaseIndex == 1, "Phase resumes")
        dying = true
        levelComplete()
        newGame(difficulty: .normal)
        tick(dt: 2000)
        check(!dying && level == 1 && lives == 3 && transitionAction == nil, "Clean restart")
        running = true
        levelComplete()
        pauseGame()
        tick(dt: 2000)
        check(level == 1 && transitionRemaining == 1600, "Paused transition")
        resumeGame()
        tick(dt: 1600)
        check(level == 2 && transitionAction == nil && !transitioning, "Resumed transition")
        phaseIndex = 4
        respawnPositions()
        check(phaseIndex == 0 && phaseTimer == 0, "Respawn phase reset")
        pacman.x = 0; pacman.y = 260
        ghosts = [ghosts[0]]
        ghosts[0].x = 559; ghosts[0].y = 260; ghosts[0].state = .chase
        checkGhostCollisions()
        check(dying, "Tunnel seam collision")
        newGame(difficulty: .normal)
        let ghost = ghosts[0]
        ghost.state = .leaving; ghost.x = 260; ghost.y = 200
        frightenedTimer = 1000
        updateGhost(ghost, dt: 16)
        check(ghost.state == .frightened, "Power pellet on house exit")
        newGame(difficulty: .normal)
        pacman.x = 230; pacman.y = 100; pacman.dir = Dir(x: 1, y: 0)
        pressDir("up", Dir(x: 0, y: -1)); releaseDir("up")
        stepEntity(pacman, speed: 0.13, dt: 100, pickDir: pickPacDir)
        check(pacman.dir.y == -1 && pacman.queuedDir == .zero, "Buffered tap consumed")
        newGame(difficulty: .normal)
        running = true
        startDeathSequence()
        for _ in 0..<100 { tick(dt: 16) }
        check(lives == 2 && !dying && !transitioning, "Death and respawn")
        score = 9900
        for ghost in ghosts { ghost.state = .frightened; eatGhost(ghost) }
        checkExtraLife()
        check(score == 12900 && lives == 3, "Combo and single extra life")
        newGame(difficulty: .normal)
        over = true
        showGameOverOverlay(isNewBest: false, best: 0)
        handleButtonTap("btn-close")
        check(!over && !running && startOverlay?.isHidden == false, "Close game over returns to menu")
        check(button(at: hud.pauseButton.position)?.id != "btn-pause", "Overlay blocks underlying HUD")
        let initialSize = size
        for viewport in [CGSize(width: 320, height: 568), CGSize(width: 390, height: 844), CGSize(width: 768, height: 1024), CGSize(width: 1024, height: 768)] {
            size = viewport
            layout(size: viewport)
            let board = CGRect(origin: mazeContainer.position, size: CGSize(width: simWidth * mazeContainer.xScale, height: simHeight * mazeContainer.yScale))
            check(board.minX >= 0 && board.maxX <= viewport.width && board.minY >= 0 && board.maxY <= viewport.height, "Maze fits \(viewport)")
        }
        size = initialSize
        layout(size: initialSize)
        newGame(difficulty: .normal)
        var staysOnPaths = true
        for _ in 0..<10000 {
            for ghost in ghosts {
                updateGhost(ghost, dt: 16)
                if GameConfig.rawTile(ghost.col, ghost.row) == 1 { staysOnPaths = false }
            }
        }
        check(staysOnPaths, "Long ghost simulation")
        FileHandle.standardError.write(Data("PACMAN SMOKE: \(checks) checks passed\n".utf8))
        newGame(difficulty: .normal)
        hideStartOverlayNode()
        splashOverlay?.isHidden = true
        running = true
        gamePaused = true
        pacman.mouthPhase = 1
    }
}
#endif
