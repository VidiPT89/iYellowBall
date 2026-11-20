import Foundation

enum Lang: String {
    case pt, en
}

/// In-game language choice (PT-PT / EN), independent of the system locale.
enum L {
    static var current: Lang = {
        if let saved = UserDefaults.standard.string(forKey: "iyellowball.lang"), let l = Lang(rawValue: saved) {
            return l
        }
        return Locale.preferredLanguages.first?.hasPrefix("pt") == true ? .pt : .en
    }() {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "iyellowball.lang") }
    }

    static func toggle() { current = current == .pt ? .en : .pt }

    static let strings: [Lang: [String: String]] = [
        .pt: [
            "title": "iYellowBall",
            "diffEasy": "Fácil", "diffEasyMeta": "4 vidas",
            "diffNormal": "Normal", "diffNormalMeta": "3 vidas",
            "diffHard": "Difícil", "diffHardMeta": "2 vidas",
            "dailyBtn": "Desafio do dia", "dailyMeta": "labirinto novo hoje",
            "scoreLabel": "Pontos", "levelLabel": "Nível", "bestLabel": "Melhor",
            "pressStart": "ESCOLHE UM MODO",
            "pausedTitle": "PAUSA", "pausedSub": "Toca para retomar",
            "resumeBtn": "Retomar", "menuBtn": "Menu inicial",
            "playAgainBtn": "Jogar Novamente", "closeBtn": "Fechar",
            "lifeLostToast": "APANHADA!",
            "extraLifeToast": "VIDA EXTRA!",
            "freezeToast": "CONGELADOS!",
            "loseTitle": "Fim de Jogo",
            "statScore": "Pontos", "statLevel": "Nível", "statBest": "Recorde",
            "newBest": "Novo recorde!",
            "credit": "Desenvolvido por David Arsénio Martins",
            "skip": "toca para saltar",
        ],
        .en: [
            "title": "iYellowBall",
            "diffEasy": "Easy", "diffEasyMeta": "4 lives",
            "diffNormal": "Normal", "diffNormalMeta": "3 lives",
            "diffHard": "Hard", "diffHardMeta": "2 lives",
            "dailyBtn": "Daily maze", "dailyMeta": "a new maze today",
            "scoreLabel": "Score", "levelLabel": "Level", "bestLabel": "Best",
            "pressStart": "PICK A MODE",
            "pausedTitle": "PAUSED", "pausedSub": "Tap to resume",
            "resumeBtn": "Resume", "menuBtn": "Main Menu",
            "playAgainBtn": "Play Again", "closeBtn": "Close",
            "lifeLostToast": "CAUGHT!",
            "extraLifeToast": "EXTRA LIFE!",
            "freezeToast": "FROZEN!",
            "loseTitle": "Game Over",
            "statScore": "Score", "statLevel": "Level", "statBest": "Best",
            "newBest": "New record!",
            "credit": "Developed by David Arsénio Martins",
            "skip": "tap to skip",
        ],
    ]

    static func t(_ key: String) -> String {
        strings[current]?[key] ?? key
    }

    static func levelClear(_ n: Int) -> String { current == .pt ? "NÍVEL \(n) CONCLUÍDO" : "LEVEL \(n) CLEARED" }
    static func levelIncoming(_ n: Int) -> String { current == .pt ? "NÍVEL \(n)" : "LEVEL \(n)" }
}
