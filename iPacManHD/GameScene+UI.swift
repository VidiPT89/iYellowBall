import SpriteKit
#if canImport(UIKit)
import UIKit
#endif

/// A tappable region tracked outside the node tree's hit-testing so touch
/// handling can stay a simple linear scan instead of juggling SKNode names.
struct UIButton {
    let node: SKNode
    let id: String
}

extension GameScene {

    // MARK: HUD

    func buildHUD() {
        for label in [hud.scoreValue, hud.levelValue, hud.bestValue] {
            label.fontSize = 15
            label.fontColor = SKColor(hex: "#ffe28a")
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .center
            hud.container.addChild(label)
        }
        hud.langButton.fontSize = 16
        hud.langButton.fontColor = .white
        hud.langButton.verticalAlignmentMode = .center
        hud.langHit.fillColor = .clear
        hud.langHit.strokeColor = .clear
        hud.soundButton.fontSize = 16
        hud.soundButton.fontColor = .white
        hud.soundButton.verticalAlignmentMode = .center
        hud.soundHit.fillColor = .clear
        hud.soundHit.strokeColor = .clear
        hud.pauseButton.fillColor = SKColor(white: 1, alpha: 0.08)
        hud.pauseButton.strokeColor = SKColor(hex: "#4d78ff")
        hud.pauseLabel.fontSize = 14
        hud.pauseLabel.fontColor = .white
        hud.pauseLabel.verticalAlignmentMode = .center
        hud.pauseLabel.horizontalAlignmentMode = .center
        hud.pauseLabel.text = "II"
        for n in [hud.langButton, hud.langHit, hud.soundButton, hud.soundHit, hud.pauseButton, hud.pauseLabel, hud.livesTrack] {
            hud.container.addChild(n)
        }
        addChild(hud.container)

        buttons.append(UIButton(node: hud.langHit, id: "btn-lang"))
        buttons.append(UIButton(node: hud.soundHit, id: "btn-sound"))
        buttons.append(UIButton(node: hud.pauseButton, id: "btn-pause"))
        buttons.append(UIButton(node: hud.pauseLabel, id: "btn-pause"))
    }

    func layoutHUD(size: CGSize) {
        let topBarY = size.height - 24
        let statsY = size.height - 54
        let livesY = size.height - 94
        hud.langButton.position = CGPoint(x: 26, y: topBarY)
        hud.langHit.position = hud.langButton.position
        hud.soundButton.position = CGPoint(x: 62, y: topBarY)
        hud.soundHit.position = hud.soundButton.position
        hud.pauseButton.position = CGPoint(x: size.width - 34, y: topBarY)
        hud.pauseLabel.position = hud.pauseButton.position
        hud.scoreValue.position = CGPoint(x: size.width * 0.2, y: statsY)
        hud.levelValue.position = CGPoint(x: size.width * 0.5, y: statsY)
        hud.bestValue.position = CGPoint(x: size.width * 0.8, y: statsY)
        hud.livesTrack.position = CGPoint(x: size.width / 2, y: livesY)
    }

    func updateScoreLabel() { hud.scoreValue.text = "\(L.t("scoreLabel")): \(score)" }
    func updateLevelLabel() { hud.levelValue.text = "\(L.t("levelLabel")): \(level)" }
    func updateBestLabel() {
        let best = UserDefaults.standard.integer(forKey: "pacmanhd.best.\(difficulty.rawValue)")
        hud.bestValue.text = "\(L.t("bestLabel")): \(best)"
    }
    func updateLivesHUD() {
        hud.livesTrack.removeAllChildren()
        for i in 0..<max(0, lives) {
            let dot = SKShapeNode(circleOfRadius: 6)
            dot.fillColor = SKColor(hex: "#ffd400")
            dot.strokeColor = SKColor(hex: "#ffd400")
            dot.glowWidth = 2
            dot.position = CGPoint(x: CGFloat(i) * 18 - CGFloat(max(0, lives - 1)) * 9, y: 0)
            hud.livesTrack.addChild(dot)
        }
    }

    // MARK: Toast

    func showToast(_ text: String) {
        toastNode?.removeAllActions()
        toastNode?.removeFromParent()
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 16
        label.fontColor = SKColor(hex: "#ffd400")
        label.position = CGPoint(x: size.width / 2, y: size.height - 130)
        label.alpha = 0
        label.zPosition = 100
        addChild(label)
        toastNode = label
        label.run(.sequence([.fadeIn(withDuration: 0.15), .wait(forDuration: 1.1), .fadeOut(withDuration: 0.25), .removeFromParent()]))
    }

    // MARK: Overlays

    func buildOverlays() {
        // Start overlay
        let start = SKNode()
        start.zPosition = 50
        let startBg = SKShapeNode()
        startBg.name = "bg"
        startBg.fillColor = SKColor(white: 0, alpha: 0.72)
        startBg.strokeColor = .clear
        start.addChild(startBg)
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.fontSize = 30
        title.fontColor = SKColor(hex: "#ffd400")
        title.text = "PAC-MAN HD"
        start.addChild(title)
        startTitleLabel = title

        var diffButtons: [Difficulty: (bg: SKShapeNode, name: SKLabelNode, meta: SKLabelNode)] = [:]
        for diff in Difficulty.allCases {
            let bg = SKShapeNode(rectOf: CGSize(width: 150, height: 54), cornerRadius: 10)
            bg.fillColor = SKColor(white: 1, alpha: 0.06)
            bg.strokeColor = SKColor(hex: "#4d78ff")
            start.addChild(bg)
            let nameLabel = SKLabelNode(fontNamed: "Menlo-Bold")
            nameLabel.fontSize = 16
            nameLabel.fontColor = .white
            nameLabel.verticalAlignmentMode = .center
            nameLabel.position = CGPoint(x: 0, y: 8)
            bg.addChild(nameLabel)
            let metaLabel = SKLabelNode(fontNamed: "Menlo")
            metaLabel.fontSize = 12
            metaLabel.fontColor = SKColor(hex: "#9fb3ff")
            metaLabel.verticalAlignmentMode = .center
            metaLabel.position = CGPoint(x: 0, y: -12)
            bg.addChild(metaLabel)
            diffButtons[diff] = (bg, nameLabel, metaLabel)
            buttons.append(UIButton(node: bg, id: "diff-\(diff.rawValue)"))
        }
        self.diffButtons = diffButtons

        let hint = SKLabelNode(fontNamed: "Menlo-Bold")
        hint.fontSize = 14
        hint.fontColor = SKColor(white: 1, alpha: 0.8)
        start.addChild(hint)
        startHintLabel = hint

        let credit = SKLabelNode(fontNamed: "Menlo")
        credit.fontSize = 12
        credit.fontColor = SKColor(white: 1, alpha: 0.55)
        credit.text = "Developed by David Arsénio Martins"
        start.addChild(credit)
        creditLabel = credit

        let creditLink = SKLabelNode(fontNamed: "Menlo-Bold")
        creditLink.fontSize = 13
        creditLink.fontColor = SKColor(hex: "#33e0ff")
        creditLink.text = "ividi.dev"
        start.addChild(creditLink)
        creditLinkLabel = creditLink
        buttons.append(UIButton(node: creditLink, id: "open-website"))
        buttons.append(UIButton(node: startBg, id: "start-tap"))

        start.isHidden = true
        addChild(start)
        startOverlay = start

        // Pause overlay
        let pause = SKNode()
        pause.zPosition = 50
        let pauseBg = SKShapeNode()
        pauseBg.fillColor = SKColor(white: 0, alpha: 0.72)
        pauseBg.strokeColor = .clear
        pause.addChild(pauseBg)
        let pauseTitle = SKLabelNode(fontNamed: "Menlo-Bold")
        pauseTitle.fontSize = 28
        pauseTitle.fontColor = SKColor(hex: "#ffd400")
        pause.addChild(pauseTitle)
        pauseTitleLabel = pauseTitle
        let pauseSub = SKLabelNode(fontNamed: "Menlo")
        pauseSub.fontSize = 14
        pauseSub.fontColor = .white
        pauseSub.position = CGPoint(x: 0, y: -30)
        pause.addChild(pauseSub)
        pauseSubLabel = pauseSub
        buttons.append(UIButton(node: pauseBg, id: "pause-tap"))
        pause.isHidden = true
        addChild(pause)
        pauseOverlay = pause

        // Game over overlay
        let over = SKNode()
        over.zPosition = 50
        let overBg = SKShapeNode()
        overBg.fillColor = SKColor(white: 0, alpha: 0.78)
        overBg.strokeColor = .clear
        over.addChild(overBg)
        let overTitle = SKLabelNode(fontNamed: "Menlo-Bold")
        overTitle.fontSize = 26
        overTitle.fontColor = SKColor(hex: "#ff2e6c")
        overTitle.position = CGPoint(x: 0, y: 70)
        over.addChild(overTitle)
        gameOverTitleLabel = overTitle
        let statsLabel = SKLabelNode(fontNamed: "Menlo")
        statsLabel.fontSize = 15
        statsLabel.fontColor = .white
        statsLabel.numberOfLines = 0
        statsLabel.position = CGPoint(x: 0, y: 10)
        over.addChild(statsLabel)
        gameOverStatsLabel = statsLabel

        let replayBg = SKShapeNode(rectOf: CGSize(width: 170, height: 44), cornerRadius: 10)
        replayBg.fillColor = SKColor(hex: "#ffd400")
        replayBg.strokeColor = .clear
        replayBg.position = CGPoint(x: 0, y: -50)
        over.addChild(replayBg)
        let replayLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        replayLabel.fontSize = 15
        replayLabel.fontColor = .black
        replayLabel.verticalAlignmentMode = .center
        replayBg.addChild(replayLabel)
        gameOverReplayLabel = replayLabel
        gameOverReplayBg = replayBg
        buttons.append(UIButton(node: replayBg, id: "btn-replay"))

        let closeBg = SKShapeNode(rectOf: CGSize(width: 170, height: 40), cornerRadius: 10)
        closeBg.fillColor = SKColor(white: 1, alpha: 0.06)
        closeBg.strokeColor = SKColor(hex: "#4d78ff")
        closeBg.position = CGPoint(x: 0, y: -102)
        over.addChild(closeBg)
        let closeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        closeLabel.fontSize = 14
        closeLabel.fontColor = .white
        closeLabel.verticalAlignmentMode = .center
        closeBg.addChild(closeLabel)
        gameOverCloseLabel = closeLabel
        gameOverCloseBg = closeBg
        buttons.append(UIButton(node: closeBg, id: "btn-close"))

        over.isHidden = true
        addChild(over)
        gameOverOverlay = over
    }

    func layoutOverlays(size: CGSize) {
        let full = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        for overlay in [startOverlay, pauseOverlay, gameOverOverlay] {
            guard let bg = overlay?.children.first as? SKShapeNode else { continue }
            bg.path = CGPath(rect: full, transform: nil)
        }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        startTitleLabel?.position = CGPoint(x: center.x, y: center.y + 130)
        startHintLabel?.position = CGPoint(x: center.x, y: center.y - 160)
        creditLabel?.position = CGPoint(x: center.x, y: center.y - 205)
        creditLinkLabel?.position = CGPoint(x: center.x, y: center.y - 227)
        let order: [Difficulty] = [.easy, .normal, .hard]
        for (i, diff) in order.enumerated() {
            diffButtons[diff]?.bg.position = CGPoint(x: center.x, y: center.y + 30 - CGFloat(i) * 62)
        }
        pauseTitleLabel?.position = center
        pauseSubLabel?.position = CGPoint(x: center.x, y: center.y - 30)
        gameOverTitleLabel?.position = CGPoint(x: center.x, y: center.y + 90)
        gameOverStatsLabel?.position = CGPoint(x: center.x, y: center.y + 20)
        gameOverReplayBg?.position = CGPoint(x: center.x, y: center.y - 50)
        gameOverCloseBg?.position = CGPoint(x: center.x, y: center.y - 102)
    }

    func refreshTexts() {
        hud.langButton.text = L.current == .pt ? "PT" : "EN"
        hud.soundButton.text = SoundEngine.shared.isOn ? "\u{1F50A}" : "\u{1F507}"
        updateScoreLabel(); updateLevelLabel(); updateBestLabel()
        startTitleLabel?.text = L.t("title")
        startHintLabel?.text = L.t("pressStart")
        if let e = diffButtons[.easy] { e.name.text = L.t("diffEasy"); e.meta.text = L.t("diffEasyMeta") }
        if let n = diffButtons[.normal] { n.name.text = L.t("diffNormal"); n.meta.text = L.t("diffNormalMeta") }
        if let h = diffButtons[.hard] { h.name.text = L.t("diffHard"); h.meta.text = L.t("diffHardMeta") }
        pauseTitleLabel?.text = L.t("pausedTitle")
        pauseSubLabel?.text = L.t("pausedSub")
        gameOverReplayLabel?.text = L.t("playAgainBtn")
        gameOverCloseLabel?.text = L.t("closeBtn")
    }

    func showStartOverlay() { startOverlay?.isHidden = false; pauseOverlay?.isHidden = true }
    func hideStartOverlayNode() { startOverlay?.isHidden = true }

    func showGameOverOverlay(isNewBest: Bool, best: Int) {
        gameOverTitleLabel?.text = L.t("loseTitle")
        let bestText = isNewBest ? L.t("newBest") : "\(best)"
        gameOverStatsLabel?.text = "\(L.t("statScore")): \(score)    \(L.t("statLevel")): \(level)\n\(L.t("statBest")): \(bestText)"
        updateBestLabel()
        gameOverOverlay?.isHidden = false
    }
    func hideGameOverOverlay() { gameOverOverlay?.isHidden = true }

    // MARK: Controls (on-screen D-pad)

    func buildControls() {
        let names = ["up": "\u{25B2}", "down": "\u{25BC}", "left": "\u{25C0}", "right": "\u{25B6}"]
        for (key, glyph) in names {
            let btn = SKShapeNode(circleOfRadius: 26)
            btn.fillColor = SKColor(white: 1, alpha: 0.08)
            btn.strokeColor = SKColor(hex: "#4d78ff")
            btn.name = "dpad-\(key)"
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = glyph
            label.fontSize = 18
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            btn.addChild(label)
            addChild(btn)
            dpadNodes[key] = btn
            buttons.append(UIButton(node: btn, id: "dpad-\(key)"))
        }
    }

    func layoutControls(size: CGSize) {
        if dpadNodes.isEmpty { buildControls() }
        let cx = size.width / 2
        let cy: CGFloat = 96
        let gap: CGFloat = 52
        dpadNodes["up"]?.position = CGPoint(x: cx, y: cy + gap)
        dpadNodes["down"]?.position = CGPoint(x: cx, y: cy - gap)
        dpadNodes["left"]?.position = CGPoint(x: cx - gap, y: cy)
        dpadNodes["right"]?.position = CGPoint(x: cx + gap, y: cy)
    }

    // MARK: Direction press tracking (mirrors heldDirs in script.js)

    func pressDir(_ id: AnyHashable, _ dir: Dir) {
        if !heldDirs.contains(where: { $0.id == id }) { heldDirs.append((id: id, dir: dir)) }
        pacman.queuedDir = dir
        tryStart()
    }

    func releaseDir(_ id: AnyHashable) {
        heldDirs.removeAll { $0.id == id }
        if let last = heldDirs.last { pacman.queuedDir = last.dir }
    }

    // MARK: Game flow helpers

    func tryStart() {
        if over { return }
        if !running {
            running = true
            hideStartOverlayNode()
        } else if gamePaused {
            resumeGame()
        }
    }
    func pauseGame() {
        guard running, !over else { return }
        gamePaused = true
        pauseOverlay?.isHidden = false
    }
    func resumeGame() {
        gamePaused = false
        pauseOverlay?.isHidden = true
    }
    func togglePause() {
        guard running, !over else { return }
        if gamePaused { resumeGame() } else { pauseGame() }
    }

    func handleButtonTap(_ id: String) {
        switch id {
        case "btn-lang": L.toggle(); refreshTexts()
        case "btn-sound": _ = SoundEngine.shared.toggleSound(); refreshTexts()
        case "btn-pause": togglePause()
        case "start-tap": tryStart()
        case "pause-tap": resumeGame()
        case "btn-replay": newGame(difficulty: difficulty)
        case "btn-close": hideGameOverOverlay()
        case "diff-easy": newGame(difficulty: .easy)
        case "diff-normal": newGame(difficulty: .normal)
        case "diff-hard": newGame(difficulty: .hard)
        case "open-website":
            if let url = URL(string: "https://ividi.dev/") { UIApplication.shared.open(url) }
        case "splash-tap": closeSplash()
        default: break
        }
    }

    static let dirKeys: [String: Dir] = [
        "up": Dir(x: 0, y: -1), "down": Dir(x: 0, y: 1), "left": Dir(x: -1, y: 0), "right": Dir(x: 1, y: 0),
    ]

    // MARK: Touch handling

    /// Hidden overlays keep their (often full-screen) hit-boxes in `buttons`
    /// forever, so a plain frame check would let a dismissed overlay's
    /// background keep swallowing every later touch. Walk the parent chain
    /// to make sure the whole ancestor chain is actually visible.
    func isEffectivelyVisible(_ node: SKNode) -> Bool {
        var n: SKNode? = node
        while let cur = n {
            if cur.isHidden { return false }
            n = cur.parent
        }
        return true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let loc = touch.location(in: self)
            guard let hit = buttons.first(where: { isEffectivelyVisible($0.node) && $0.node.calculateAccumulatedFrame().contains(loc) }) else { continue }
            if hit.id.hasPrefix("dpad-"), let key = Self.dirKeys[String(hit.id.dropFirst(5))] {
                activeTouchIds[ObjectIdentifier(touch)] = hit.id
                pressDir(hit.id, key)
            } else {
                handleButtonTap(hit.id)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let id = activeTouchIds.removeValue(forKey: ObjectIdentifier(touch)) {
                releaseDir(id)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: Keyboard handling (see GameSKView for the UIPress forwarding)

    func handleKeyDown(_ key: String, isRepeat: Bool) {
        if let dir = Self.keyToDir(key), !isRepeat {
            pressDir(key, dir)
        } else if key == " " {
            tryStart()
        }
        if key == "p" || key == "P" || key == "Escape" { togglePause() }
    }

    func handleKeyUp(_ key: String) {
        if Self.keyToDir(key) != nil { releaseDir(key) }
    }

    static func keyToDir(_ key: String) -> Dir? {
        switch key {
        case "ArrowLeft", "a", "A": return Dir(x: -1, y: 0)
        case "ArrowRight", "d", "D": return Dir(x: 1, y: 0)
        case "ArrowUp", "w", "W": return Dir(x: 0, y: -1)
        case "ArrowDown", "s", "S": return Dir(x: 0, y: 1)
        default: return nil
        }
    }
}
