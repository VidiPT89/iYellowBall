import SpriteKit

/// A grumpy rounded cube with slanted brows. Frozen enemies turn to ice and
/// shiver as the freeze runs out; reforming ones show as a dashed outline.
final class EnemyNode: SKNode {
    let baseColor: SKColor
    let size = CGFloat(GameConfig.cell) * 0.98

    private let body: SKShapeNode
    private let shade: SKShapeNode
    private let eyeL: SKShapeNode
    private let eyeR: SKShapeNode
    private let pupilL: SKShapeNode
    private let pupilR: SKShapeNode
    private let brows = SKShapeNode()
    private let crack = SKShapeNode()
    private let outline: SKShapeNode

    static let ice = SKColor(hex: "#bfefff")
    static let iceEdge = SKColor(hex: "#5cc8ff")

    init(colorHex: String) {
        baseColor = SKColor(hex: colorHex)
        let half = size / 2
        body = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.22)
        body.lineWidth = 1.2
        shade = SKShapeNode(rectOf: CGSize(width: size * 0.8, height: size * 0.22), cornerRadius: size * 0.1)
        shade.position = CGPoint(x: 0, y: -half * 0.62)
        shade.strokeColor = .clear
        shade.fillColor = SKColor(white: 0, alpha: 0.22)

        let eyeR = size * 0.15
        eyeL = SKShapeNode(circleOfRadius: eyeR)
        self.eyeR = SKShapeNode(circleOfRadius: eyeR)
        for eye in [eyeL, self.eyeR] {
            eye.fillColor = .white
            eye.strokeColor = .clear
        }
        eyeL.position = CGPoint(x: -size * 0.2, y: size * 0.04)
        self.eyeR.position = CGPoint(x: size * 0.2, y: size * 0.04)
        pupilL = SKShapeNode(circleOfRadius: eyeR * 0.55)
        pupilR = SKShapeNode(circleOfRadius: eyeR * 0.55)
        for p in [pupilL, pupilR] {
            p.fillColor = SKColor(hex: "#14101e")
            p.strokeColor = .clear
        }

        let browPath = CGMutablePath()
        browPath.move(to: CGPoint(x: -size * 0.36, y: size * 0.3))
        browPath.addLine(to: CGPoint(x: -size * 0.08, y: size * 0.2))
        browPath.move(to: CGPoint(x: size * 0.36, y: size * 0.3))
        browPath.addLine(to: CGPoint(x: size * 0.08, y: size * 0.2))
        brows.path = browPath
        brows.lineWidth = 2
        brows.lineCap = .round
        brows.strokeColor = SKColor(hex: "#14101e")

        let crackPath = CGMutablePath()
        crackPath.move(to: CGPoint(x: -size * 0.3, y: size * 0.32))
        crackPath.addLine(to: CGPoint(x: -size * 0.05, y: size * 0.05))
        crackPath.addLine(to: CGPoint(x: -size * 0.15, y: -size * 0.12))
        crackPath.addLine(to: CGPoint(x: size * 0.18, y: -size * 0.34))
        crack.path = crackPath
        crack.lineWidth = 1
        crack.strokeColor = .white

        outline = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.22)
        outline.fillColor = .clear
        outline.lineWidth = 1.2
        outline.strokeColor = baseColor.withAlphaComponent(0.7)
        let dashed = outline.path?.copy(dashingWithPhase: 0, lengths: [3, 3])
        outline.path = dashed

        super.init()
        for n in [body, shade, eyeL, self.eyeR, pupilL, pupilR, brows, crack, outline] { addChild(n) }
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    func update(state: EnemyState, frozen: Bool, freezeLeft: Double, dir: CGVector, reformProgress: Double) {
        let reforming = state == .reforming
        outline.isHidden = !reforming
        for n in [body, shade, eyeL, eyeR, pupilL, pupilR, brows] { n.isHidden = reforming }
        crack.isHidden = reforming || !frozen
        if reforming {
            outline.setScale(0.4 + 0.6 * CGFloat(reformProgress))
            outline.alpha = 0.3 + 0.7 * CGFloat(reformProgress)
            zRotation = 0
            alpha = 1
            return
        }
        outline.setScale(1)
        if frozen {
            let thawing = freezeLeft < 2000
            body.fillColor = thawing && Int(CACurrentMediaTime() / 0.15) % 2 == 0 ? baseColor.withAlphaComponent(0.6) : Self.ice
            body.strokeColor = Self.iceEdge
            brows.isHidden = true
            pupilL.position = eyeL.position
            pupilR.position = eyeR.position
            zRotation = thawing ? CGFloat(sin(CACurrentMediaTime() * 40)) * 0.08 : 0
        } else {
            body.fillColor = baseColor
            body.strokeColor = baseColor.withAlphaComponent(0.9)
            zRotation = 0
            let look = size * 0.15 * 0.5
            pupilL.position = CGPoint(x: eyeL.position.x + dir.dx * look, y: eyeL.position.y + dir.dy * look)
            pupilR.position = CGPoint(x: eyeR.position.x + dir.dx * look, y: eyeR.position.y + dir.dy * look)
        }
        alpha = state == .dormant && !frozen ? 0.85 : 1
    }
}
