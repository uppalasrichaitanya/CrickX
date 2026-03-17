<div align="center">
  <img src="logo.png" alt="CrickX Logo" width="200" style="border-radius: 20%; margin-bottom: 20px; box-shadow: 0 4px 8px rgba(0,0,0,0.3);"/>
</div>

# CrickX 🏏

**CrickX** is a 2D professional cricket simulation game built entirely in Godot 4.2.2 (GDScript). It focuses on deep simulation mechanics, a high-quality dark UI, dynamic commentary, and realistic match flows.

## 🌟 Features

- **Deep Simulation Mechanics**: The game uses a sequential pipeline executed by `BallSimulator.gd` to simulate physics, psychology, and logic via 8 deep modules including:
  - **Form & Fatigue**: Accumulates fatigue per ball faced/bowled, affecting accuracy and timing.
  - **Match Pressure**: Calculates match pressure based on Required Run Rate, recent dot balls, and wickets fallen.
  - **Weather & Pitch**: Pitch types and weather conditions influence ball behavior (e.g., Reverse Swing, Spin).
  - **Batting Depth**: Shot timing influenced by pressure, generating timing modifiers.
  - **Bowling Depth**: Calculates accuracy, swing, variations (Googly, Doosra), and bowler rhythm.
- **Dynamic Commentary**: Context-aware text generation based on outcomes, milestones, and close finishes.
- **High-Quality UI**: A cohesive dark UI using Accent Green and Accent Gold, complete with match HUD, team selection, and scorecards.
- **Risk & Reward Batting**: Choose from various shot types (Defensive Block, Leave, Drive/Pull, Loft/Slog) with realistic risk profiles and boundary chances.
- **Realistic Squads**: Features fully fleshed-out T20 squads (e.g., India, Australia) with individual player stats for batting, bowling skill, and styles.

## 🛠️ Technology Stack

- **Game Engine**: Godot 4.2.2 stable
- **Language**: GDScript
- **Rendering**: 2D canvas_items stretch mode (Base Resolution: 1280x720)

## 🏗️ Architecture

The game's architecture heavily utilizes the **Autoload pattern** to manage state across scenes:
- `GameManager.gd`: Central state management for the match (runs, wickets, overs, current players, momentum).
- `MatchEngine.gd`: The core State Machine driving the match loop.
- `AudioManager.gd`: SFX management.
- `CommentaryManager.gd`: Dynamic text generation.
- `NavigationManager.gd`: Clean scene transitions.

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
3. Choose your teams and the match format (e.g., T20) in the **Team Select** screen.
4. During the match, watch for the **Delivery Alert** (e.g., `"🏏 YORKER!"`).
5. You have a **4-second reaction window** to select your shot from the UI grid.
6. Manage your pressure, observe the pitch/weather conditions, and lead your team to victory!

## 📜 License

This project is open-source. Feel free to explore, clone, and modify!
