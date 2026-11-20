import SpriteKit

/// Visual node for a ghost: a dome+wavy-skirt body plus eyes, redrawn once
/// (the path never changes) and recolored/repositioned per frame.
/// Note: shape offsets here mirror script.js's `drawGhostShape`/`drawEyes`
/// with the y-axis negated, since this node lives in a y-up (SpriteKit)
/// local space while the original canvas math is y-down.
final class GhostNode: SKNode {
    let baseColor: SKColor
    let size = CGFloat(GameConfig.cell) * 1.05

    private let body: SKShapeNode
    private let eyeWhiteL: SKShapeNode
    private let eyeWhiteR: SKShapeNode
    private let pupilL: SKShapeNode
    private let pupilR: SKShapeNode
    private let scaredMouth = SKShapeNode()
    private let scaredEyeL: SKShapeNode
    private let scaredEyeR: SKShapeNode

    init(colorHex: String) {
        baseColor = SKColor(hex: colorHex)
        let r = size / 2
        body = SKShapeNode(path: GhostNode.bodyPath(r: r))
        body.fillColor = baseColor
        body.strokeColor = baseColor
        body.lineWidth = 0.5
        body.glowWidth = 0.5

        let eyeR = size * 0.15
        let offsetX = size * 0.19
        let offsetY = size * 0.08 // -(-0.08*size) from JS: flipped for y-up space
        eyeWhiteL = SKShapeNode(circleOfRadius: eyeR)
        eyeWhiteR = SKShapeNode(circleOfRadius: eyeR)
        for eye in [eyeWhiteL, eyeWhiteR] {
            eye.fillColor = SKColor(hex: "#f4f8ff")
            eye.strokeColor = .clear
        }
        eyeWhiteL.position = CGPoint(x: -offsetX, y: offsetY)
        eyeWhiteR.position = CGPoint(x: offsetX, y: offsetY)

        let pupilR_ = eyeR * 0.55
        pupilL = SKShapeNode(circleOfRadius: pupilR_)
        pupilR = SKShapeNode(circleOfRadius: pupilR_)
        for p in [pupilL, pupilR] {
            p.fillColor = SKColor(hex: "#141428")
            p.strokeColor = .clear
        }
        pupilL.position = eyeWhiteL.position
        pupilR.position = eyeWhiteR.position

        scaredEyeL = SKShapeNode(circleOfRadius: size * 0.07)
        scaredEyeR = SKShapeNode(circleOfRadius: size * 0.07)
        for se in [scaredEyeL, scaredEyeR] {
            se.fillColor = .clear
            se.strokeColor = SKColor(hex: "#eef2ff")
            se.lineWidth = 1.4
        }
        scaredEyeL.position = CGPoint(x: -size * 0.16, y: -size * 0.05)
        scaredEyeR.position = CGPoint(x: size * 0.16, y: -size * 0.05)

        super.init()
        addChild(body)
        addChild(eyeWhiteL)
        addChild(eyeWhiteR)
        addChild(pupilL)
        addChild(pupilR)
        addChild(scaredEyeL)
        addChild(scaredEyeR)
        let mouth = CGMutablePath()
        for i in 0..<7 {
            let point = CGPoint(x: -size * 0.3 + CGFloat(i) * size * 0.1, y: -size * (i % 2 == 0 ? 0.22 : 0.3))
            if i == 0 { mouth.move(to: point) } else { mouth.addLine(to: point) }
        }
        scaredMouth.path = mouth
        scaredMouth.lineWidth = 1.4
        addChild(scaredMouth)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    private static func bodyPath(r: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -r, y: -r * 0.9))
        path.addArc(center: .zero, radius: r, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: r, y: -r * 0.9))
        let waves = 4
        let waveW = (2 * r) / CGFloat(waves)
        for i in 0..<waves {
            let sx = r - waveW * CGFloat(i)
            let mx = sx - waveW / 2
            let ex = sx - waveW
            let dip: CGFloat = (i % 2 == 0) ? r * 0.55 : r * 0.9
            path.addQuadCurve(to: CGPoint(x: ex, y: -r * 0.9), control: CGPoint(x: mx, y: -dip))
        }
        path.closeSubpath()
        return path
    }

    func updateAppearance(state: GhostState, dir: CGVector, frightenedTimer: Double) {
        scaredMouth.isHidden = state != .frightened
        let faceColor = frightenedTimer < 2000 && Int(CACurrentMediaTime() / 0.15) % 2 == 0 ? SKColor(hex: "#d92e38") : SKColor(hex: "#eef2ff")
        scaredMouth.strokeColor = faceColor
        scaredEyeL.strokeColor = faceColor
        scaredEyeR.strokeColor = faceColor
        switch state {
        case .eaten:
            body.isHidden = true
            eyeWhiteL.isHidden = false; eyeWhiteR.isHidden = false
            pupilL.isHidden = false; pupilR.isHidden = false
            scaredEyeL.isHidden = true; scaredEyeR.isHidden = true
        case .frightened:
            body.isHidden = false
            let flashing = frightenedTimer < 2000 && Int(CACurrentMediaTime() / 0.15) % 2 == 0
            let c = flashing ? SKColor(hex: "#eef2ff") : SKColor(hex: "#2b3fe0")
            body.fillColor = c
            body.strokeColor = c
            eyeWhiteL.isHidden = true; eyeWhiteR.isHidden = true
            pupilL.isHidden = true; pupilR.isHidden = true
            scaredEyeL.isHidden = false; scaredEyeR.isHidden = false
        default:
            body.isHidden = false
            body.fillColor = baseColor
            body.strokeColor = baseColor
            eyeWhiteL.isHidden = false; eyeWhiteR.isHidden = false
            pupilL.isHidden = false; pupilR.isHidden = false
            scaredEyeL.isHidden = true; scaredEyeR.isHidden = true
        }
        let eyeR = size * 0.15
        pupilL.position = CGPoint(x: eyeWhiteL.position.x + dir.dx * eyeR * 0.55, y: eyeWhiteL.position.y + dir.dy * eyeR * 0.55)
        pupilR.position = CGPoint(x: eyeWhiteR.position.x + dir.dx * eyeR * 0.55, y: eyeWhiteR.position.y + dir.dy * eyeR * 0.55)
    }
}
