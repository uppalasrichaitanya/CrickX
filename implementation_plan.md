# Cricket Master - Godot 4 Deep Implementation Plan

This is a highly detailed architectural step-by-step plan for building the entire game, heavily expanding on the technical implementation of each phase.

## Phase 1: Core Engine, UI & Deep Logic Stubs
*Goal: Playable T20 Match (Human Batting vs AI Bowling/Fielding) operating via UI only, with the entire highly-scalable simulator pipeline wired up.*

### Step 1.1: Project Setup & Constants
- Initialize a Godot 4.x project. Setup resolution (1280x720, canvas_items).
- Create standard directories (`autoloads`, `scripts/core`, `scenes/ui`, etc).
- Create `res://autoloads/Constants.gd` for magic numbers (`MAX_OVERS_T20 = 20`, timing thresholds, etc).
- Create Godot `Theme` resource (`CricketTheme.tres`) defining the dark gray (`#0D1117`), panels (`#161B22`), and green/gold highlights.

### Step 1.2: Core Data Architecture
- Create `PlayerData.gd` extending `Resource`. Give it all exports (skill, form, fatigue, stats).
- Create `TeamData.gd` extending `Resource` holding arrays of `PlayerData`.
- Write a quick `res://scripts/core/Database.gd` or similar to hardcode the 8 starting teams into memory on boot.

### Step 1.3: Game State Management 
- Create `res://autoloads/GameManager.gd`. 
- Define the dictionary: `var state = { batting_team, bowling_team, current_over, current_ball, target, format, phase, pitch_type }`.
- Create Signal declarations: `ball_bowled`, `wicket_fallen`, etc.

### Step 1.4: The Deep Logic Simulation Pipeline (`BallSimulator.gd`)
- Create `res://scripts/core/BallSimulator.gd` to handle RNG outcomes.
- Create 8 individual module files in `res://scripts/core/modules/`:
  - `FormFatigueSystem.gd`
  - `WeatherPitchSystem.gd`
  - `PressureMoraleSystem.gd`
  - `DRSSystem.gd`
  - `BattingDepthSystem.gd`
  - `BowlingDepthSystem.gd`
  - `AIController.gd`
  - `AtmosphereSystem.gd`
- In `BallSimulator.gd`, instance these modules. Write a master `simulate_ball()` function that passes the current Match State through these systems sequentially to calculate a `BallOutcome` dictionary (`runs`, `is_wicket`, `commentary_key`, etc). 
- *Note for Phase 1*: These modules will just be basic stubs containing their base variables, returning standard mathematical RNG, to be filled with the complex physics later.

### Step 1.5: UI Scenes Construction
- **MainMenu.tscn**: Center Polygon2D logo, Subtitle, Version number at bottom. VBoxContainer for Quick Match, Tournaments, Multiplayer, Settings, Quit. Glowing buttons on hover (`_on_mouse_entered`). Subtle ball rolling animation loop.
- **Settings.tscn**: Master Volume, SFX Volume, Difficulty selector, Fullscreen toggle. Save logic to `user://settings.cfg`.
- **HUD.tscn**: 
  - Top Bar: MarginContainer with labels for Teams, Score, Overs, Format badge.
  - Center Box: Semi-transparent lower third for batter/bowler/partnership stats.
  - Interaction Panel: Popup Selection (1-6) for Shot and Bowl selection. Keyboard input reading. 8-second timer bar that selects random if expired. Hover tooltips implemented.
  - Over Timeline: Dynamic HBoxContainer generating colored dots (● ● ④ ● ⑥ W).
  - Commentary Box: ScrollContainer with typewriter animation (Tweening `visible_characters`). Generates from pool of 40+ unique lines depending on wicket type or milestone.
- **Audio & Polish**: Add `AudioStreamPlayer` placeholders (hit, cheer, wicket, ambient loop). Implement 0.3s fade in/out transitions between all scenes. Ensure every script starts with a brief explanatory comment.

### Step 1.6: Match Loop Integration (`MatchEngine.gd`)
- Create `res://autoloads/MatchEngine.gd`.
- Manage the state machine: `WAITING_FOR_INPUT` -> `SIMULATING` -> `SHOWING_RESULT` -> `END_OF_OVER` -> `END_OF_INNINGS`.
- Connect the HUD inputs to the Engine. Trigger the `BallSimulator`, await a timeout, then update the UI and push commentary.

---

## Phase 2: Hot-Seat Multiplayer
*Goal: Local PVP.*
### Step 2.1: Input Masking
- Modify `HUD.tscn`. When human vs human, prompt Player 1 (Bowl Selection) on numpad. Hide their choice behind a '*' UI mask. Then prompt Player 2 (Bat Selection). 
### Step 2.2: Turn Transitions
- Build a generic `TurnTransitionPopup.tscn`. A 3-second overlay blocking the screen prompting the active player to pass the device before clicking "Ready".

---

## Phase 3: Advanced AI Logic
*Goal: Implement Module #7 and the "intelligence" of the game.*
### Step 3.1: Batting AI
- Update `AIController.gd`. Feed it the `GameManager.state.target` and `RRR`. Build threshold logic (If RRR > 10, pick Aggressive Loft). Create random deviation so the AI isn't perfect.
### Step 3.2: Bowling AI & Pattern Recognition
- Create memory variables inside `TeamData` for the AI to track human shot history. If human `PULL` > 3, weight AI bowling to `YORKER`.

---

## Phase 4: Tournament System & Persistence
### Step 4.1: Save System
- `SaveManager.gd`: Write `var_to_str` and `str_to_var` functions targeting `user://tournament.json`. Trigger auto-saves on `innings_ended`.
### Step 4.2: Tournament Visuals
- Create `Bracket.tscn` (Tree/Graph structure updating dynamically).
- Create `PointsTable.tscn` (Live NRR calculators, sorting algorithms updating a VBoxContainer of rows).

---

## Phase 5: LAN Multiplayer
### Step 5.1: ENet Core
- Instantiate `ENetMultiplayerPeer`. Tie Host logic to port `54000`. Manage RPCs.
### Step 5.2: State Syncing
- Set `MatchEngine` to Authoritative Mode on Host. Client only sends `rpc("receive_player_input", shot_choice)`. Host calculates `BallSimulator`, pushes `rpc("update_game_state", match_dict)` back to client. Handle dropouts with `peer_disconnected` signal.

---

## Phase 6: Interactive 2D Graphics Engine
*Goal: Visual physics representing the math.*
### Step 6.1: Node Layout
- Create `res://scenes/match/Ground.tscn`. Draw a visual oval. Add a Node2D camera.
### Step 6.2: Entity Animations
- Create `Batsman.tscn` and `Bowler.tscn`. Trigger `Callable` Tweens to swing the bat based on `BallSimulator`'s `timing` output (EARLY, LATE, PERFECT). 
- Move a `Sprite2D` Ball along a Bezier curve representing the generated boundaries or wickets.

## Next Steps
With your approval on this newly detailed plan and the [game_specifications.md](file:///C:/Users/srich/.gemini/antigravity/brain/0b65897b-abdf-4211-9c77-7692b4be318b/game_specifications.md) document, I will lay down the project folders safely and begin scripting **Phase 1: Step 1.1 through 1.3** and output the Godot folder structure.
