# CrickX - Project History & Architecture Documentation
*Generated on: 2026-03-17*

This document serves as the structural memory and history of the CrickX project built in Godot 4.2.2. It can be provided to any AI tool to instantly onboard it onto the project’s exact architecture, terminology, and mechanics.

---

## 1. Project Overview
**CrickX** is a 2D professional cricket simulation game built entirely in Godot 4.2.2 (GDScript) with a focus on deep simulation mechanics, high-quality dark UI, dynamic commentary, and realistic match flows.

- **Stack:** Godot 4.2.2 stable, GDScript
- **Rendering:** 2D canvas_items stretch mode
- **Base Resolution:** 1280x720
- **VCS:** Git (Repository: `https://github.com/uppalasrichaitanya/CrickX`)

---

## 2. Global Autoloads (Singletons)
The game relies heavily on the Autoload pattern to manage state across scenes.
1. **`GameManager.gd`**: Holds global match state (`total_runs`, `wickets`, `current_over`, `deliveries`), active teams, currently active striker/non-striker/bowler, momentum, pitch wear, weather. Handles strike rotation and next batsman generation.
2. **`MatchEngine.gd`**: The State Machine driving the match loop.
   - *Flow:* Bowler picks delivery -> Wait 0.6s -> Reveal Delivery -> Player has 4s to select shot (Reaction timer) -> Simulator resolves outcome -> Wait -> Next Ball.
3. **`AudioManager.gd`**: Handles playback of SFX (`bat_hit`, `crowd_cheer`, `wicket`, `ui_click`).
4. **`CommentaryManager.gd`**: Dynamic text generation based on outcomes, milestones, context, and close finishes.
5. **`NavigationManager.gd`**: Handles scene transitions cleanly.

---

## 3. Core Simulation Modules (`scripts/core/modules/`)
The game resolves balls using a sequential pipeline executed by `BallSimulator.gd`. The system simulates physics, psychology, and logic via 8 deep modules:

1. **`AIController.gd`**: Picks deliveries (for AI bowlers) and shots (for AI batsmen) based on difficulty overrides and player skill.
2. **`AtmosphereSystem.gd`**: Calculates momentum shifts based on boundaries/wickets. Tracks milestones (50s, 100s, 5-wicket hauls).
3. **`BattingDepthSystem.gd`**: Calculates shot timing (Perfect, Good, Late) influenced by pressure, generating "timing_modifiers".
4. **`BowlingDepthSystem.gd`**: Calculates accuracy, swing (based on weather/pitch/over), ball speed, spin variations (Googly, Doosra), and bowler rhythm.
5. **`DRSSystem.gd`**: Placeholder for future LBW/Caught Behind review logic.
6. **`FormFatigueSystem.gd`**: Accumulates fatigue per ball faced/bowled. High fatigue heavily drops bowler accuracy and batsman timing.
7. **`PressureMoraleSystem.gd`**: Calculates match pressure based on Required Run Rate, recent dot balls, and wickets fallen quickly.
8. **`WeatherPitchSystem.gd`**: Defines pitch types (Green Seamer, Spin Track, Flat) and weather (Overcast, Humid). E.g., Humid + Over 12 = Reverse Swing. Pitch wear increases spin continuously.

### Batting Mechanic & Shot Logic (`BallSimulator.gd`)
- The AI picks the delivery type first.
- A `DeliveryAlert` flashes on screen (e.g., `"🏏 YORKER!"`).
- The player gets a 4-second reaction window to select a shot. If timed out, it defaults to a Defensive Block.
- **Risk Profiles:**
  - `Defensive Block`: Maximum 3% wicket chance, scores 0-1 run. High dot ball rate.
  - `Leave`: 0% wicket chance (unless leaving a Yorker hitting the stumps).
  - `Drive/Pull/Sweep`: Standard risk, standard boundary chance.
  - `Loft/Slog`: 1.5x wicket scale risk, 1.8x boundary multiplier. High risk/reward.

---

## 4. UI Architecture (`scenes/ui/`)
All UI scenes are built strictly using Godot `Control` nodes with `theme_override_` properties (avoiding `LabelSettings` resources to prevent parse errors).
Theme is a cohesive dark UI using `Color(0.08, 0.09, 0.11)` for backgrounds, Accent Green (`#00C853`) and Accent Gold (`#FFD54F`).

1. **`MainMenu.tscn`**: VBox container with title, Play Quick Match, Settings, Quit buttons.
2. **`TeamSelect.tscn`**: OptionButtons to select Team A and Team B, plus format (T20/ODI).
3. **`MatchHUD.tscn`**: 
   - *TopBar*: Teams, score, format badge, overs.
   - *CenterPanel*: `CenterVBox` holding BattingBox (Striker, Non-striker with Form icons), BowlingBox (Bowler with Rhythm icons), and InfoBox (CRR, RRR, Partnership).
   - *ShotSelectionPanel*: Anchored to the lower half. Contains a TimerBar and a 3-column Grid of 6 emoji-labeled shot buttons.
   - *DeliveryAlert*: Pops up in center screen.
   - *InningsBreakPopup*: Full-screen overlay triggered at 1st innings end.
   - *OverSummaryPopup*: Appears cleanly after 6 balls.
   - *StatusBar*: Pitch, Weather, Pressure%, Momentum, DRS indicators.
4. **`Scorecard.tscn`**: Final screen showing the total breakdown and winner.
5. **`Settings.tscn`**: Volume and difficulty controls.

---

## 5. Data Structures
Defined in `Constants.gd` and Resources (`PlayerData.gd`, `TeamData.gd`).
- **`Constants.gd`**: Holds enums for `ShotType`, `DeliveryType`, `WeatherType`, `PitchType`. Holds Hex Color codes. Holds the large `MATCHUP_MATRIX` determining base probabilities of Bowler vs Batsman matchups.
- **`PlayerData.gd`**: Stats (Batting skill, Bowling skill, bowling style - Fast/Spin). Match tracking (match_runs, match_balls, match_wickets).
- **`TeamData.gd`**: Squad (array of PlayerData), team name, color, tournament logic points.
- **`TeamDatabase.gd`**: Static hardcoded database. Currently holds fully fleshed-out "India" and "Australia" T20 squads with realistic 11s.

---

## 6. Significant Fixes & Design Decisions Today
- **Godot Parse Errors**: Replaced broken `.tres` sub-resources for LabelSettings with inline `theme_override` styling across all 5 `.tscn` files. This allows raw textual merging without breaking Godot's scene parser.
- **UI Node Overlap**: Reanchored `MatchHUD.tscn`. The shot grid and timer bar were collapsing inside a pure PanelContainer. Wrapped them in a `VBoxContainer` to stack correctly. Moved Shot UI to the bottom area of the screen.
- **Match Loop Syncing**: Added `await get_tree().create_timer()` yields across `MatchEngine.gd` to completely fix race conditions where signals fired before HUDs or Scorecards finished loading.
- **Second Innings**: Refactored `MatchEngine.gd` so `swap_innings()` triggers an `InningsBreakPopup` on the *same HUD* and starts auto-simulating the AI chase, rather than crashing or transitioning blindly to the Scorecard.
- **Risk System Rewrite**: Found that `BallSimulator` was indiscriminately applying high wicket chances (12-15%) to defensive blocks due to fatigue/pressure loops. Substituted this with a `shot_profile` multiplier (block = `wicket_scale: 0.15`).

---

**End of Document**  
*Use this text file directly as a knowledge base prompt when expanding features next.*
