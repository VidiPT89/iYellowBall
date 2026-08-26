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
            return q
        }
        if (e.dir.x != 0 || e.dir.y != 0), !pacBlocked(col + e.dir.x, row + e.dir.y) { return e.dir }
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
                ghost.state = self.currentPhaseMode()
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
        spawnExplosion(x: pacman.x + GameConfig.cell / 2, y: pacman.y + GameConfig.cell / 2, color: SKColor(hex: "#ffd400"))
        shakeCamera()
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
        run(.wait(forDuration: GameConfig.readyPauseMs / 1000)) { [weak self] in
            self?.transitioning = false
            self?.invulnerableTimer = 1600
        }
    }

    func respawnPositions() {
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
        run(.wait(forDuration: 1.6)) { [weak self] in
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
            let dist = hypot(g.x - pacman.x, g.y - pacman.y)
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
        for p in particles { p.node?.removeFromParent() }
        particles = []

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
