import Foundation

enum Lang: String {
    case pt, en
}

/// Direct port of the `TRANSLATIONS` table from script.js.
enum L {
    static var current: Lang = {
        if let saved = UserDefaults.standard.string(forKey: "pacmanhd.lang"), let l = Lang(rawValue: saved) {
            return l
        }
        return Locale.preferredLanguages.first?.hasPrefix("pt") == true ? .pt : .en
    }() {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "pacmanhd.lang") }
    }

    static func toggle() { current = current == .pt ? .en : .pt }

    static let strings: [Lang: [String: String]] = [
        .pt: [
            "title": "Pac-Man HD",

            "diffEasy": "Fácil", "diffEasyMeta": "4 vidas",
            "diffNormal": "Normal", "diffNormalMeta": "3 vidas",
            "diffHard": "Difícil", "diffHardMeta": "2 vidas",
            "scoreLabel": "Pontos", "levelLabel": "Nível", "bestLabel": "Melhor",
            "pressStart": "TOCA PARA COMEÇAR",
            "pausedTitle": "PAUSA", "pausedSub": "Toca para retomar",
            "resumeBtn": "Retomar", "menuBtn": "Menu inicial",
            "playAgainBtn": "Jogar Novamente", "closeBtn": "Fechar",
            "lifeLostToast": "PAC-MAN APANHADO",
            "extraLifeToast": "VIDA EXTRA!",
            "loseTitle": "Fim de Jogo",
            "statScore": "Pontos", "statLevel": "Nível", "statBest": "Recorde",
            "newBest": "Novo recorde!",
        ],
        .en: [
            "title": "Pac-Man HD",

            "diffEasy": "Easy", "diffEasyMeta": "4 lives",
            "diffNormal": "Normal", "diffNormalMeta": "3 lives",
            "diffHard": "Hard", "diffHardMeta": "2 lives",
            "scoreLabel": "Score", "levelLabel": "Level", "bestLabel": "Best",
            "pressStart": "TAP TO START",
            "pausedTitle": "PAUSED", "pausedSub": "Tap to resume",
            "resumeBtn": "Resume", "menuBtn": "Main Menu",
            "playAgainBtn": "Play Again", "closeBtn": "Close",
            "lifeLostToast": "PAC-MAN CAUGHT",
            "extraLifeToast": "EXTRA LIFE!",
            "loseTitle": "Game Over",
            "statScore": "Score", "statLevel": "Level", "statBest": "Best",
            "newBest": "New record!",
        ],
    ]

    static func t(_ key: String) -> String {
        strings[current]?[key] ?? key
    }

    static func levelClear(_ n: Int) -> String { current == .pt ? "NÍVEL \(n) CONCLUÍDO" : "LEVEL \(n) CLEARED" }
    static func levelIncoming(_ n: Int) -> String { current == .pt ? "NÍVEL \(n)" : "LEVEL \(n)" }
    static func ghostEatToast(_ n: Int) -> String { "+\(n)" }
}
