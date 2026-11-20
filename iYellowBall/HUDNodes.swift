import SpriteKit

/// Groups the always-visible score/level/lives/best readouts.
final class HUDNodes {
    let container = SKNode()
    let scoreValue = SKLabelNode(fontNamed: "Menlo-Bold")
    let levelValue = SKLabelNode(fontNamed: "Menlo-Bold")
    let bestValue = SKLabelNode(fontNamed: "Menlo-Bold")
    let livesTrack = SKNode()
    let langButton = SKLabelNode(fontNamed: "Menlo-Bold")
    let langHit = SKShapeNode(rectOf: CGSize(width: 40, height: 40))
    let soundButton = SKLabelNode(fontNamed: "Menlo-Bold")
    let soundHit = SKShapeNode(rectOf: CGSize(width: 40, height: 40))
    let pauseButton = SKShapeNode(rectOf: CGSize(width: 48, height: 40), cornerRadius: 8)
    let pauseLabel = SKLabelNode(fontNamed: "Menlo-Bold")
}
