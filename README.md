# 🟡 iYellowBall: Roll, Freeze, Smash

> A neon maze game for iPhone and iPad: roll the yellow ball through a brand-new maze every level, collect every gem, freeze the cubes and smash them.

iYellowBall is a native iPhone/iPad arcade game built with **Swift** and **SpriteKit**, no third-party engines or dependencies. Every maze is generated on the device from a seed, so each level is a new layout, and the **Daily maze** is the same for every player on the same day.

🌐 Web version (same mazes, same daily seed): [play in the browser](https://vidipt89.github.io/iYellowBallWeb/) · [source](https://github.com/VidiPT89/iYellowBallWeb)

## 📦 What's Inside

- 🧩 **Generated mazes:** a symmetric maze carved for each level, with every dead end opened into a loop so there is always a way out, a central plaza and a side tunnel that wraps across the board
- 📅 **Daily maze:** a sequence seeded by today's date, with its own best score per day
- 🟡 **The yellow ball:** smooth continuous movement with a rolling shine and eyes that look where it is heading
- 🟥 **Four cubes, four behaviours:**
  - the **hunter** heads straight for you
  - the **cutter** races to the next junction you are rolling towards
  - the **drifter** wanders until you come close, then pounces
  - the **guard** camps the ice orb nearest to you while any are left
- ❄️ **Ice orbs:** every cube on the board freezes solid; roll into a frozen cube to smash it (100 → 200 → 400 → 800). Smashed cubes rebuild in the plaza and come back dangerous. Freeze time shortens each level
- 🎯 Three difficulties: Easy (4 lives), Normal (3), Hard (2), plus one extra life per game
- 🏆 Best score per difficulty and per daily maze, saved on the device
- 🔊 Synthesised sound effects (custom `AVAudioEngine` synth, no audio files) and haptics
- 🇵🇹 🇬🇧 In-game language toggle between European Portuguese and English
- 🕹️ On-screen D-pad, swipe anywhere to steer, and hardware keyboard support (arrows/WASD, Space, P)
- 🔒 No account, no tracking, no network

## 🛠️ Tech Stack

![Swift](https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white)
![SpriteKit](https://img.shields.io/badge/SpriteKit-000000?style=flat&logo=apple&logoColor=white)

## 🏗️ Project Structure

```
iYellowBall/
├── project.yml                 # XcodeGen spec
└── iYellowBall/
    ├── Config.swift            # Grid types, difficulties, enemy definitions
    ├── MazeGenerator.swift     # Seeded, symmetric, dead-end-free maze generator
    ├── Entities.swift          # Ball, enemies and grid movement
    ├── GameScene.swift         # Scene, rendering and main loop
    ├── GameScene+Logic.swift   # Enemy AI, freeze, scoring, levels, debug smoke tests
    ├── GameScene+UI.swift      # HUD, menus, D-pad, swipe and keyboard input
    ├── GameScene+Splash.swift  # Intro
    ├── EnemyNode.swift         # Cube artwork and frozen/reforming states
    ├── SoundEngine.swift       # Real-time synth
    └── Localization.swift      # PT/EN strings
```

## 🚀 How to Run

```bash
brew install xcodegen
xcodegen generate
open iYellowBall.xcodeproj
```

### Checks

A Debug build launched with `--smoke-test` runs 170 checks inside the real scene: 30 generated mazes (deterministic, symmetric, no dead ends, fully reachable, four orbs), freeze and smash rules, lives, transitions, daily seeds, layout on iPhone and iPad sizes, and an autopilot that clears level 1.

```bash
xcrun simctl launch --console-pty booted dev.ividi.iyellowball --smoke-test
```

`--demo play|freeze|level3|menu` stages the frames used for the App Store screenshots.

## 🔒 Privacy

See [PRIVACY.md](PRIVACY.md). Nothing is collected.

---

Developed by **David Arsénio Martins**, *"Vidi"* · [ividi.dev](https://ividi.dev/)
