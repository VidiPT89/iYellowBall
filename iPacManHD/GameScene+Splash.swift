import SpriteKit
import UIKit

/// A short, skippable intro presentation shown once when the app launches:
/// the title reveals, a small Pac-Man chomps across a row of dots, then the
/// developer credit fades in before handing off to the main menu.
extension GameScene {

    func buildSplash() {
        let splash = SKNode()
        splash.zPosition = 200
        let bg = SKShapeNode()
        bg.fillColor = SKColor(hex: "#05060f")
        bg.strokeColor = .clear
        bg.name = "splash-bg"
        splash.addChild(bg)
        splashBg = bg
        // Inserted at the front now: the splash sits above every other
        // overlay, so its tap targets must win the linear hit-test while
        // it's shown. The link (inserted later, further down) ends up even
        // further front so it takes priority over this full-screen catch-all.
        buttons.insert(GameButton(node: bg, id: "splash-tap"), at: 0)

        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = "PAC-MAN HD"
        title.fontSize = 34
        title.fontColor = SKColor(hex: "#ffd400")
        title.alpha = 0
        title.setScale(0.8)
        splash.addChild(title)
        splashTitle = title

        let pac = SKShapeNode(circleOfRadius: 16)
        pac.fillColor = SKColor(hex: "#ffd400")
        pac.strokeColor = SKColor(hex: "#ffd400")
        pac.glowWidth = 8
        pac.alpha = 0
        splash.addChild(pac)
        splashPac = pac

        var dots: [SKShapeNode] = []
        for _ in 0..<7 {
            let dot = SKShapeNode(circleOfRadius: 4)
            dot.fillColor = SKColor(hex: "#ffe28a")
            dot.strokeColor = SKColor(hex: "#ffe28a")
            dot.glowWidth = 1.5
            dot.alpha = 0
            splash.addChild(dot)
            dots.append(dot)
        }
        splashDots = dots

        let credit = SKLabelNode(fontNamed: "Menlo")
        credit.fontSize = 13
        credit.fontColor = SKColor(white: 1, alpha: 0.75)
        credit.text = "Developed by David Arsénio Martins"
        credit.alpha = 0
        splash.addChild(credit)
        splashCredit = credit

        let link = SKLabelNode(fontNamed: "Menlo-Bold")
        link.fontSize = 14
        link.fontColor = SKColor(hex: "#33e0ff")
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
        splashPac?.position = CGPoint(x: 40, y: rowY)
        let spacing = (size.width - 80) / CGFloat(max(1, splashDots.count - 1))
        for (i, dot) in splashDots.enumerated() {
            dot.position = CGPoint(x: 40 + CGFloat(i) * spacing, y: rowY)
        }
        splashCredit?.position = CGPoint(x: center.x, y: center.y - 100)
        splashLink?.position = CGPoint(x: center.x, y: center.y - 124)
        splashSkipLabel?.position = CGPoint(x: center.x, y: 40)
    }

    func playSplash() {
        guard let overlay = splashOverlay else { return }
        let title = splashTitle, pac = splashPac, dots = splashDots
        let credit = splashCredit, link = splashLink, skip = splashSkipLabel

        title?.run(.group([.fadeIn(withDuration: 0.5), .scale(to: 1.0, duration: 0.5)]))

        guard let pac, let startX = dots.first?.position.x, let endX = dots.last?.position.x else { return }
        pac.alpha = 1
        let travelDuration = 1.8
        let travel = SKAction.moveTo(x: endX + 30, duration: travelDuration)
        pac.run(.sequence([.wait(forDuration: 0.4), travel]))

        for (i, dot) in dots.enumerated() {
            dot.alpha = 1
            let dotX = startX + (endX - startX) * CGFloat(i) / CGFloat(max(1, dots.count - 1))
            let arrivalFraction = (dotX - startX) / max(1, endX - startX)
            let delay = 0.4 + Double(arrivalFraction) * travelDuration
            dot.run(.sequence([.wait(forDuration: delay), .fadeOut(withDuration: 0.1)]))
        }

        let creditDelay = 2.5
        credit?.run(.sequence([.wait(forDuration: creditDelay), .fadeAlpha(to: 0.75, duration: 0.5)]))
        link?.run(.sequence([.wait(forDuration: creditDelay), .fadeAlpha(to: 1, duration: 0.5)]))
        skip?.text = L.current == .pt ? "toca para saltar" : "tap to skip"
        skip?.run(.sequence([.wait(forDuration: 0.6), .fadeAlpha(to: 0.4, duration: 0.4)]))

        overlay.run(.sequence([.wait(forDuration: 4.2), .run { [weak self] in self?.closeSplash() }]))
    }

    func closeSplash() {
        guard let overlay = splashOverlay, !overlay.isHidden else { return }
        overlay.removeAllActions()
        overlay.run(.sequence([.fadeOut(withDuration: 0.25), .run { overlay.isHidden = true }]))
    }
}
