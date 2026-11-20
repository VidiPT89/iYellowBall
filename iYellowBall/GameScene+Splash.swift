import SpriteKit
import UIKit

/// A short, skippable intro: the title appears, the yellow ball rolls across
/// a row of gems, then the developer credit fades in before the menu.
extension GameScene {

    func buildSplash() {
        let splash = SKNode()
        splash.zPosition = 200
        let bg = SKShapeNode()
        bg.fillColor = SKColor(hex: "#05060c")
        bg.strokeColor = .clear
        splash.addChild(bg)
        splashBg = bg
        // The splash sits above every overlay, so its targets go first in the
        // linear hit-test; the link, inserted later, wins over the catch-all.
        buttons.insert(GameButton(node: bg, id: "splash-tap"), at: 0)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "iYellowBall"
        title.fontSize = 34
        title.fontColor = SKColor(hex: "#ffd21f")
        title.alpha = 0
        title.setScale(0.8)
        splash.addChild(title)
        splashTitle = title

        let ball = SKNode()
        let body = SKShapeNode(circleOfRadius: 16)
        body.fillColor = SKColor(hex: "#ffd21f")
        body.strokeColor = SKColor(hex: "#ffb300")
        body.lineWidth = 1.5
        ball.addChild(body)
        let shine = SKShapeNode(circleOfRadius: 4)
        shine.fillColor = SKColor(white: 1, alpha: 0.75)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -6, y: 7)
        ball.addChild(shine)
        for side: CGFloat in [-1, 1] {
            let eye = SKShapeNode(ellipseOf: CGSize(width: 4, height: 6))
            eye.fillColor = SKColor(hex: "#1a1300")
            eye.strokeColor = .clear
            eye.position = CGPoint(x: 4 + side * 4, y: 2)
            ball.addChild(eye)
        }
        ball.alpha = 0
        splash.addChild(ball)
        splashBall = ball

        var gems: [SKShapeNode] = []
        for _ in 0..<7 {
            let gem = SKShapeNode(rectOf: CGSize(width: 7, height: 7))
            gem.zRotation = .pi / 4
            gem.fillColor = SKColor(hex: "#d8f6ff")
            gem.strokeColor = .clear
            gem.alpha = 0
            splash.addChild(gem)
            gems.append(gem)
        }
        splashGems = gems

        let credit = SKLabelNode(fontNamed: "Menlo")
        credit.fontSize = 13
        credit.fontColor = SKColor(white: 1, alpha: 0.75)
        credit.alpha = 0
        splash.addChild(credit)
        splashCredit = credit

        let link = SKLabelNode(fontNamed: "Menlo-Bold")
        link.fontSize = 14
        link.fontColor = SKColor(hex: "#5cc8ff")
        link.text = "ividi.dev"
        link.alpha = 0
        splash.addChild(link)
        splashLink = link
        buttons.insert(GameButton(node: link, id: "open-website"), at: 0)

        let skip = SKLabelNode(fontNamed: "Menlo")
        skip.fontSize = 12
        skip.fontColor = SKColor(white: 1, alpha: 0.4)
        skip.alpha = 0
        splash.addChild(skip)
        splashSkipLabel = skip

        addChild(splash)
        splashOverlay = splash
    }

    func layoutSplash(size: CGSize) {
        guard let bg = splashBg else { return }
        bg.path = CGPath(rect: CGRect(x: 0, y: 0, width: size.width, height: size.height), transform: nil)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        splashTitle?.position = CGPoint(x: center.x, y: center.y + 40)
        let rowY = center.y - 20
        if splashBall?.hasActions() != true { splashBall?.position = CGPoint(x: 40, y: rowY) }
        let spacing = (size.width - 80) / CGFloat(max(1, splashGems.count - 1))
        for (i, gem) in splashGems.enumerated() {
            gem.position = CGPoint(x: 40 + CGFloat(i) * spacing, y: rowY)
        }
        splashCredit?.position = CGPoint(x: center.x, y: center.y - 100)
        splashLink?.position = CGPoint(x: center.x, y: center.y - 124)
        splashSkipLabel?.position = CGPoint(x: center.x, y: 40)
    }

    func playSplash() {
        guard let overlay = splashOverlay else { return }
        splashTitle?.run(.group([.fadeIn(withDuration: 0.5), .scale(to: 1.0, duration: 0.5)]))

        if let ball = splashBall, let startX = splashGems.first?.position.x, let endX = splashGems.last?.position.x {
            ball.alpha = 1
            let travelDuration = 1.8
            let distance = endX + 30 - ball.position.x
            ball.run(.sequence([.wait(forDuration: 0.4), .moveTo(x: endX + 30, duration: travelDuration)]))
            // Roll: one turn per circumference travelled.
            ball.run(.sequence([.wait(forDuration: 0.4), .rotate(byAngle: -distance / 16, duration: travelDuration)]))
            for gem in splashGems {
                gem.alpha = 1
                let fraction = (gem.position.x - startX) / max(1, endX - startX)
                let delay = 0.4 + Double(fraction) * travelDuration
                gem.run(.sequence([.wait(forDuration: delay), .group([.scale(to: 1.8, duration: 0.12), .fadeOut(withDuration: 0.12)])]))
            }
        }

        let creditDelay = 2.5
        splashCredit?.text = L.t("credit")
        splashCredit?.run(.sequence([.wait(forDuration: creditDelay), .fadeAlpha(to: 0.75, duration: 0.5)]))
        splashLink?.run(.sequence([.wait(forDuration: creditDelay), .fadeAlpha(to: 1, duration: 0.5)]))
        splashSkipLabel?.text = L.t("skip")
        splashSkipLabel?.run(.sequence([.wait(forDuration: 0.6), .fadeAlpha(to: 0.4, duration: 0.4)]))

        overlay.run(.sequence([.wait(forDuration: 4.2), .run { [weak self] in self?.closeSplash() }]))
    }

    func closeSplash() {
        guard let overlay = splashOverlay, !overlay.isHidden else { return }
        overlay.removeAllActions()
        overlay.run(.sequence([.fadeOut(withDuration: 0.25), .run { overlay.isHidden = true }]))
    }
}
