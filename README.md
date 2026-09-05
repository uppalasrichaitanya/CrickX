<div align="center">
  <img src="logo.png" alt="CrickX Logo" width="200" style="border-radius: 20%; margin-bottom: 20px; box-shadow: 0 4px 8px rgba(0,0,0,0.3);"/>
</div>

# CrickX 🏏

**CrickX** is a 2D professional cricket simulation game built entirely in Godot 4.2.2 (GDScript). It focuses on deep simulation mechanics, a high-quality dark UI, dynamic commentary, and realistic match flows.

## 🌟 Features

- **Deep Simulation Mechanics**: The game uses a sequential pipeline executed by `BallSimulator.gd` to simulate physics, psychology, and logic via 8 deep modules including:
  - **Form & Fatigue**: Accumulates fatigue per ball faced/bowled (with over-rest recovery and drinks breaks), affecting accuracy and timing.
  - **Match Pressure**: Calculates match pressure based on Required Run Rate, recent dot balls, and wickets fallen.
  - **Weather & Pitch**: Pitch types and weather conditions influence ball behavior (e.g., Reverse Swing, Spin); the pitch wears as the match progresses.
  - **Batting Depth**: Shot timing influenced by pressure, generating timing modifiers.
  - **Bowling Depth**: Calculates accuracy, swing, variations (Googly, Doosra), and bowler rhythm.
  - **Fielding**: Catches are contested by real fielders — they can be dropped, and every dismissal names the fielder.
- **Match Formats & Modes**: Play T20 or ODI, in "Bat vs AI" mode or **Full Match** mode — bat the first innings, then pick every delivery as you bowl the second.
- **DRS Reviews**: LBW/caught decisions can be reviewed (T20: 1, ODI: 2 per innings) with ball-tracking, edge detection, and umpire's call.
- **Dynamic Commentary**: Context-aware text generation based on outcomes, milestones, hat-tricks, dropped catches, maidens, weather changes, and close finishes.
- **High-Quality UI**: A cohesive dark UI using Accent Green and Accent Gold, complete with match HUD, team selection, and full scorecards for both innings.
- **Risk & Reward Batting**: Choose from various shot types (Defensive Block, Leave, Drive/Pull, Loft/Slog) with realistic risk profiles and boundary chances.
- **Visual Match View**: A live top-down field renders every delivery and result — yorkers and bouncers, boundary ropes with chasing fielders, sixes sailing over the top, stump shatterings, dropped catches, plus a toggleable wagon wheel and milestone fireworks.
- **Tournament Mode**: World Cup style — 2 groups of 4, a live points table with Net Run Rate tie-breaks, semi finals and a final. Play your team's fixtures (with a real coin toss — win it and choose to bat or bowl), and auto-sim the rest. Tournaments autosave and can be resumed. Squads of 15 per team.
- **Fast Forward**: Collapse the waits between balls to auto-sim quickly at any time.
- **Realistic Squads**: Fully fleshed-out T20 squads (8 international teams) with individual player stats for batting, bowling, fielding, and styles.

## 🛠️ Technology Stack

- **Game Engine**: Godot 4.2.2 stable
- **Language**: GDScript
- **Rendering**: 2D canvas_items stretch mode (Base Resolution: 1280x720)

## 🏗️ Architecture

The game's architecture heavily utilizes the **Autoload pattern** to manage state across scenes:
- `GameManager.gd`: Central state management for the match (runs, wickets, overs, current players, momentum).
- `MatchEngine.gd`: The core state machine driving the match loop.
- `AudioManager.gd`: SFX management (synthesized placeholder sounds — regenerate with `tools/gen_audio.ps1`).
- `CommentaryManager.gd`: Dynamic text generation.
- `SaveManager.gd` / `NetworkManager.gd`: Stub autoloads reserved for tournament and LAN multiplayer (planned).

## 🚀 Getting Started

### Prerequisites

- Download and install [Godot Engine 4.2.2](https://godotengine.org/download/archive/4.2.2-stable/) or newer.

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/uppalasrichaitanya/CrickX.git
   ```
2. Open the Godot Project Manager.
3. Click on **Import** and browse to the cloned `CrickX` directory to select the `project.godot` file.
4. Click **Import & Edit** to open the project.

### How to Play

1. Run the project from the Godot editor (`F5`).
2. Navigate through the **Main Menu** to select **Play Quick Match**.
3. Choose your teams, the match format (T20 or ODI), and the mode (Bat vs AI, or Full Match) in the **Team Select** screen.
4. During your batting innings, watch for the **Delivery Alert** (e.g., `"🏏 YORKER!"`).
5. You have a **4-second reaction window** to select your shot from the UI grid or keys **1-6**.
6. On a reviewable dismissal (LBW/caught), you get a **5-second window** to call for a **DRS review**.
7. In Full Match mode, pick each delivery (keys 1-4) as you bowl the second innings.
8. Watch the **field view** react to every ball — boundaries race to the rope, sixes clear it, and wickets shatter the stumps. Toggle **🧭** for the wagon wheel of every shot so far.
9. Use **⏩** in the status bar to fast-forward at any time.
10. For a campaign, start a **Tournament** from the main menu: pick your nation, win the toss, and chase the cup through groups, semis, and the final — the standings, NRR, and fixtures are tracked for you.
11. Manage your pressure, observe the pitch/weather conditions, and lead your team to victory!

## 🧪 Testing

A headless smoke test plays eight full matches through the real engine (T20/ODI, fast-forward, both toss orientations, human bowling) and runs a complete auto-simulated tournament with a save/load round-trip, plus DRS unit checks:

```bash
Godot_v4.2.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test.gd
```

Exit code 0 = all checks passed. This also runs in CI on every push.

## 📜 License

This project is open-source under the MIT License — see [LICENSE](LICENSE).
