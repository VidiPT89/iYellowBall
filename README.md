# 🟡 Pac-Man HD — Run, Chase, Eat It All (iOS)

> A native iOS remake of the 1980 arcade classic, built with Swift and SpriteKit — a crisp blue arcade maze, four ghosts with real personalities, and a chase that never lets up.

Pac-Man HD is a native iPhone/iPad game built with **Swift** and **SpriteKit** — no third-party engines, no external dependencies. Guide Pac-Man through a 28×28 blue-outlined maze, gobble every dot and power pellet, and outrun four ghosts before they corner you. Each ghost hunts differently — Blinky chases directly, Pinky ambushes ahead of you, Inky flanks unpredictably, and Clyde loses interest up close — and a power pellet flips the hunt for a few precious seconds, turning every ghost into prey.

## 📦 What's Inside

- 🧩 A full 28×28 classic-style maze rendered with SpriteKit nodes, continuous blue wall outlines, pulsing pac-dots and animated power pellets
- 🟡 Smooth, continuously-animated Pac-Man movement (not grid-snapped) with a rotating, chomping mouth that follows the travel direction
- 👻 Four ghosts — Blinky, Pinky, Inky, Clyde — each with authentic chase logic (direct pursuit, ambush, flank, and distance-based shyness) plus scatter/chase phases that alternate over time
- 😱 Power pellets trigger a frightened state — ghosts turn blue and flee, with an escalating 200 → 400 → 800 → 1600 combo for eating them in a row, plus floating score popups
- 👀 Eaten ghosts race home as a pair of eyes and re-emerge from the ghost house after a short respawn
- 🌀 Classic tunnel wraparound on the side corridor, exactly like the arcade original
- ♾️ Endless level progression — clear the maze and the next one begins with faster ghosts, same lives and score
- 🎯 Three difficulty levels — Easy (4 lives), Normal (3 lives), Hard (2 lives) — each tuning ghost speed, frightened duration and release timing
- 🏆 Best score tracked per difficulty, saved on-device
- 🔊 Fully synthesized retro sound effects via a custom `AVAudioEngine` synth — chomping, power-up siren, ghost-eaten blips, death sequence, level fanfare — no audio files
- 📳 Haptic feedback on power pellets, eating ghosts, dying and clearing a level
- 🇵🇹 🇬🇧 One-tap language toggle between European Portuguese and English
- ⌨️ 📱 On-screen D-pad plus full hardware keyboard support (arrows/WASD, Space, P) for Simulator and keyboard-connected iPads
- ⏸️ Pause/resume at any time, with a dimmed overlay and its own translated hint text
- 🎬 An animated intro presentation on launch — Pac-Man chomps across the title screen before handing off to the main menu
- 🌌 Quiet black arcade backdrop that keeps the maze readable
- 🖥️ Neon glow styling throughout for an authentic arcade-cabinet feel

## 🛠️ Tech Stack

![Swift](https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white)
![SpriteKit](https://img.shields.io/badge/SpriteKit-000000?style=flat&logo=apple&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-16%2B-black?style=flat&logo=ios&logoColor=white)
![Xcode](https://img.shields.io/badge/Xcode-147EFB?style=flat&logo=xcode&logoColor=white)

## 🏗️ Project Structure

```
iPacManHD/
├── project.yml               # XcodeGen project spec (source of truth for the .xcodeproj)
├── iPacManHD.xcodeproj        # Generated Xcode project — open this in Xcode
└── iPacManHD/
    ├── iPacManHDApp.swift      # SwiftUI app entry point
    ├── GameView.swift          # UIViewRepresentable hosting the SpriteKit view
    ├── GameSKView.swift         # SKView subclass, forwards hardware keyboard input
    ├── GameScene.swift          # Scene setup, render loop, maze/entity rendering
    ├── GameScene+AI.swift       # Ghost AI, movement rules, gameplay events
    ├── GameScene+UI.swift       # HUD, overlays, touch/keyboard input
    ├── GameScene+Splash.swift   # Intro presentation
    ├── Entities.swift           # Pac-Man/Ghost models and the shared movement engine
    ├── GhostNode.swift          # Ghost body/eyes rendering
    ├── Maze.swift               # Maze layout, difficulty presets, ghost definitions
    ├── SoundEngine.swift        # Synthesized chiptune sound effects
    ├── Haptics.swift            # Haptic feedback helpers
    ├── Localization.swift       # PT/EN strings
    └── Assets.xcassets          # App icon
```

## ⚙️ Game Mechanics

```
New Game (per difficulty):
  lives, ghost speed multiplier, frightened duration = difficulty preset
  maze dots and pellets fully restocked, score = 0, level = 1

Each Frame:
  1. Move Pac-Man along the grid, turning at tile centers when a direction is queued
  2. Move each ghost according to its current state:
       house      → bobs in the ghost house until its release timer fires
       leaving    → paths to the door and out into the maze
       scatter    → retreats toward its own maze corner
       chase      → hunts Pac-Man using its own personality logic
       frightened → flees on random turns while power pellet is active
       eaten      → races home as eyes, then re-enters the house
  3. Eating a dot scores 10pts; a power pellet scores 50pts and frightens every active ghost
  4. Colliding with a frightened ghost eats it (200/400/800/1600 combo); colliding with
     a normal ghost costs a life, unless Pac-Man just respawned (brief invulnerability)
  5. Maze fully cleared → next level, faster ghosts, dots and pellets reset
  6. Lives exhausted → game over, compare score to the saved per-difficulty best
```

## 👻 Ghost Personalities

```
Blinky (red)   — always targets Pac-Man's current tile: a direct, relentless chase
Pinky  (pink)  — targets four tiles ahead of Pac-Man's facing direction: an ambusher
Inky   (cyan)  — targets a point mirrored through Blinky's position: an unpredictable flanker
Clyde  (orange)— chases directly when far away, but retreats to his corner up close
```

## 🚀 How to Run

```bash
# 1. Clone the repository
git clone https://github.com/VidiPT89/iPacManHD.git
cd iPacManHD

# 2. Open the Xcode project
open iPacManHD.xcodeproj

# 3. Pick an iPhone/iPad simulator (or a real device), press ⌘R
```

Requires Xcode 16+ and iOS 16+. No third-party dependencies or package managers involved.

If you add or remove Swift files and use [XcodeGen](https://github.com/yonaskolb/XcodeGen), regenerate the project from `project.yml`:

```bash
xcodegen generate
```

## 📝 Notes

- This is the native iOS port of [pacmanHD](https://github.com/VidiPT89/pacmanHD), the browser-based Canvas/JavaScript version of the game — same maze, ghost AI and rules, rebuilt from scratch on SpriteKit for a native, touch-first experience
- Best-score preferences are stored with `UserDefaults`, so they persist between launches

---

Developed by **David Arsénio Martins**
🌐 [ividi.dev](https://ividi.dev/)


## Arcade refinement (2026-11-20)

- Connected blue wall outlines, pink ghost-house door and restrained character glow.
- Readable frightened faces, including contrasting eyes and mouth during the warning flash.
- Immediate direction reversal between tiles; existing corner controls preserved.
- Ghosts slow in the side tunnel; collisions work across its wraparound seam.
- Frightened mode suspends the chase/scatter clock and applies to ghosts leaving the house.
- Level/death transitions use simulation time: pausing freezes them and restarting cancels them.
- Losing focus pauses the game and clears held controls.
- Original maze, four ghost personalities, difficulty presets and scoring retained.

Launch a Debug build with `--smoke-test` to run 19 scene regressions and display a paused playfield for visual inspection. The checks use the actual SpriteKit scene; the flag is excluded from Release builds.


## General review (2026-11-20)

- Short tap buffering, finger sliding between direction buttons and independent multi-touch identities.
- Modal hit-testing blocks underlying controls; closing game over returns to the menu.
- HUD labels fit their allotted width and the scene follows view resizing.
- Audio attempts to recover after its engine stops, and muting clears pending notes.
- Removed the unused particle/starfield/camera-shake systems, unused state and unused translations.
- Debug smoke checks cover movement, death, combos, overlays and iPhone/iPad layout sizes. Release excludes these checks.
