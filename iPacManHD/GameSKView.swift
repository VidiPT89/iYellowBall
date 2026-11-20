import SpriteKit
import UIKit

/// Forwards hardware-keyboard presses (arrow keys, WASD, space, P) to the
/// current GameScene — handy for the Simulator and any iPad with a keyboard.
final class GameSKView: SKView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(self, selector: #selector(suspendGame), name: UIApplication.willResignActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func suspendGame() { (scene as? GameScene)?.pauseGame() }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        pressesEnded(presses, with: event)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let scene = scene as? GameScene, scene.size != bounds.size { scene.size = bounds.size }
    }

    override var canBecomeFirstResponder: Bool { true }

    /// `didMove(to:)` on the scene fires before this view is actually
    /// inserted into the window, so `safeAreaInsets` is still zero at that
    /// point. UIKit calls this once the real insets are known (and again on
    /// rotation), so re-run layout here to pull the HUD clear of the notch.
    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        (scene as? GameScene)?.layout(size: bounds.size)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let scene = scene as? GameScene else { return super.pressesBegan(presses, with: event) }
        var handled = false
        for press in presses {
            if let key = Self.token(for: press) {
                scene.handleKeyDown(key, isRepeat: false)
                handled = true
            }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let scene = scene as? GameScene else { return super.pressesEnded(presses, with: event) }
        var handled = false
        for press in presses {
            if let key = Self.token(for: press) {
                scene.handleKeyUp(key)
                handled = true
            }
        }
        if !handled { super.pressesEnded(presses, with: event) }
    }

    private static func token(for press: UIPress) -> String? {
        guard let key = press.key else { return nil }
        switch key.keyCode {
        case .keyboardUpArrow: return "ArrowUp"
        case .keyboardDownArrow: return "ArrowDown"
        case .keyboardLeftArrow: return "ArrowLeft"
        case .keyboardRightArrow: return "ArrowRight"
        case .keyboardW: return "w"
        case .keyboardA: return "a"
        case .keyboardS: return "s"
        case .keyboardD: return "d"
        case .keyboardSpacebar: return " "
        case .keyboardP: return "p"
        case .keyboardEscape: return "Escape"
        default: return nil
        }
    }
}
