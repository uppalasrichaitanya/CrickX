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
1. **`GameManager.gd`**: Holds global match state (`total_runs`, `wickets`, `current_over`), active teams, currently active striker/non-striker/bowler, momentum, pitch wear, weather. Handles strike rotation, next batsman generation, and partnership tracking.
2. **`MatchEngine.gd`**: The State Machine driving the match loop.
   - *Flow:* Bowler picks delivery -> Wait 0.6s -> Reveal Delivery -> Player has 4s to select shot (Reaction timer) -> Simulator resolves outcome -> Wait -> Next Ball.
   - *Also:* DRS review flow (5s window on reviewable dismissals), Full Match mode (human bowls the 2nd innings), fast-forward mode, hat-trick ledger, and a match-generation token that prevents zombie coroutines from old matches.
3. **`AudioManager.gd`**: Handles playback of SFX (`bat_hit`, `crowd_cheer`, `wicket`, `ui_click`, ambient crowd loop). Sounds are synthesized placeholders — regenerate with `tools/gen_audio.ps1`.
4. **`CommentaryManager.gd`**: Dynamic text generation based on outcomes, milestones, context, and close finishes.
5. **`SaveManager.gd` / `NetworkManager.gd`**: Stub autoloads reserved for tournament mode and LAN multiplayer (planned — see `implementation_plan.md`).

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

1. **`MainMenu.tscn`**: VBox container with title, Play Quick Match, Settings, Quit. Tournament/Multiplayer are visible but disabled ("coming soon").
2. **`TeamSelect.tscn`**: ItemLists to select Team A and Team B, plus a SetupRow with Format (T20/ODI) and Mode (Bat vs AI / Full Match) OptionButtons, and a same-team warning label.
3. **`MatchHUD.tscn`**: 
   - *TopBar*: Teams, score, format badge, overs, target info.
   - *CenterPanel*: `CenterVBox` holding BattingBox (Striker, Non-striker with Form icons), BowlingBox (Bowler with Rhythm icons), and InfoBox (CRR, RRR, Partnership).
   - *ShotSelectionPanel*: Anchored to the lower half. Contains a TimerBar and a 3-column Grid of 6 emoji-labeled shot buttons (keys 1-6).
   - *BowlSelectionPanel*: Mirrors the shot panel; shown when the human bowls (Full Match 2nd innings). Buttons are filtered by bowler type (spin vs pace).
   - *DRSPopup*: Full-screen dim overlay with review info, a 5s timer bar, and Review / No Review buttons.
   - *DeliveryAlert*: Pops up in center screen (also announces hat-trick balls).
   - *InningsBreakPopup*: Full-screen overlay triggered at 1st innings end.
   - *OverSummaryPopup*: Appears cleanly after 6 balls; includes maiden / big over / weather / drinks flavor.
   - *StatusBar*: Pitch, Weather, Pressure%, Momentum, live DRS pips, and the Fast-Forward toggle.
4. **`Scorecard.tscn`**: Final screen showing winner, Man of the Match, full batting/bowling tables for the second innings, and the complete first-innings tables.
5. **`Settings.tscn`**: Volume, difficulty, and fullscreen controls (persisted to `user://settings.cfg`).

---

## 5. Data Structures
Defined in `Constants.gd` and Resources (`PlayerData.gd`, `TeamData.gd`).
- **`Constants.gd`**: Holds enums for `ShotType`, `DeliveryType`, `WeatherType`, `PitchType`. Holds Hex Color codes. Holds the large `MATCHUP_MATRIX` determining base probabilities of Bowler vs Batsman matchups.
- **`PlayerData.gd`**: Stats (Batting skill, Bowling skill, bowling style - Fast/Spin). Match tracking (match_runs, match_balls, match_wickets).
- **`TeamData.gd`**: Squad (array of PlayerData), team name, color, tournament logic points.
- **`TeamDatabase.gd`**: Static hardcoded database holding 8 international squads (India, Australia, England, South Africa, New Zealand, Pakistan, West Indies, Sri Lanka) with realistic XIs.

---

## 6. Significant Fixes & Design Decisions Today
- **Godot Parse Errors**: Replaced broken `.tres` sub-resources for LabelSettings with inline `theme_override` styling across all `.tscn` files. This allows raw textual merging without breaking Godot's scene parser.
- **UI Node Overlap**: Reanchored `MatchHUD.tscn`. The shot grid and timer bar were collapsing inside a pure PanelContainer. Wrapped them in a `VBoxContainer` to stack correctly. Moved Shot UI to the bottom area of the screen.
- **Match Loop Syncing**: Added `await get_tree().create_timer()` yields across `MatchEngine.gd` to completely fix race conditions where signals fired before HUDs or Scorecards finished loading.
- **Second Innings**: Refactored `MatchEngine.gd` so `swap_innings()` triggers an `InningsBreakPopup` on the *same HUD* and starts auto-simulating the AI chase, rather than crashing or transitioning blindly to the Scorecard.
- **Risk System Rewrite**: Found that `BallSimulator` was indiscriminately applying high wicket chances (12-15%) to defensive blocks due to fatigue/pressure loops. Substituted this with a `shot_profile` multiplier (block = `wicket_scale: 0.15`).
- **HUD-Ready Handshake** (P0): `MatchHUD` reports `note_hud_ready()`/`note_hud_gone()` so the engine never starts ball flow into a HUD that isn't listening (previously a 0.8s race).
- **Match Generation Token** (P2): `MatchEngine.start_match()` bumps `_match_gen`; every suspended ball-flow coroutine aborts on resume if its generation is stale. This killed a zombie-coroutine overlap where a previous match's loop kept bowling into a new match's state.
- **Fielding** (P2): Caught dismissals are contested by a real fielder (catch chance from `fielding_skill`), with drops, morale events, `match_catches` tracking, and "c Fielder b Bowler" dismissal text.
- **Accounting** (P2): Exact invariants — batter runs + penalties = team total, and every run is charged to a bowler (wides/no-ball penalties included; partial final overs credited at innings/match end).
- **Regression Net**: `tests/smoke_test.gd` plays 6 full matches headlessly (T20/ODI, fast-forward, Full Match) plus a DRS unit loop; runs in GitHub Actions CI on every push.

---

## 7. Visual Match View (`scenes/match/FieldView.tscn`)
- **`FieldView.gd`** (Node2D): top-down TV-style oval drawn entirely with `_draw()` — mown-stripe grass, boundary rope, 30-yard circle, pitch strip with creases and stumps. No image assets.
- **Markers**: striker/non-striker (green), bowler (gold), keeper (blue), 9 outfield fielders (white), all as self-drawing `MarkerDot` Node2Ds placed via the `ZONE_ANGLES` mapping from `Constants.FieldZone`.
- **Delivery animation**: `play_delivery(type)` — per-type trajectory timing (bouncer fast/kicks up, yorker full, spin drifts, slower ball loopy), driven by the engine's `delivery_thrown` signal fired before the shot resolves.
- **Outcome animation**: `play_outcome(outcome)` — reads the real outcome dict: 4 (races to the rope with a chasing fielder + burst), 6 (over-the-top arc with scale/shadow + gold burst), 1-3 (fielder intercept + batsmen crossing), dot (soft push back), wide (past the keeper), DROPPED (bounces off the fielder), and all wicket types (BOWLED/STUMPED/RUN_OUT shatter the stumps via CPUParticles2D, CAUGHT tracks the fielder, CAUGHT_BEHIND to the keeper, LBW pad-impact flash). Dismissed batter marker fades off.
- **Wagon wheel**: every scoring shot records a line from the striker's end to the zone's boundary point, colored by runs (1-3 green / 4 cyan / 6 gold). Toggled by the 🧭 button in the HUD StatusBar; cleared at the innings break.
- **Milestone fireworks**: golden particle fanfares on FIFTY, HUNDRED, FIFER, hat-trick, and 50/100 partnerships (tracked in the HUD, reset per wicket).
- **Pacing**: the engine gives boundary/wicket/drop/milestone balls a longer 1.4s beat (`_result_wait`) so animations breathe; ordinary balls keep 0.8s. All animation timings are scaled by `_speed_scale()` so fast-forward collapses them to 0.04s.
- **Integration**: `MatchHUD` instantiates the FieldView at `Vector2(140, 332)` (the free band between the over dots and commentary), wires `delivery_thrown`/`ball_result_ready`/`second_innings_starting`, and the DeliveryAlert overlays it translucently.

---

## 8. Tournament Mode (`autoloads/TournamentManager.gd` + UI)
- **`TournamentManager.gd`**: World Cup structure — 2 seeded groups of 4, per-group round-robin (12 fixtures), standings with points → NRR → wins tie-breaks, semis (A1 v B2, B1 v A2), and a final. Autosaves after every result via `SaveManager` (JSON under `user://saves/tournament.json`) and rehydrates TeamData references on load. NRR uses the `total_runs/overs_tournament` fields on `TeamData` via `calculate_nrr()`.
- **Toss refactor**: `MatchEngine.start_match` now takes the human's *team* (not booleans) and derives `is_human_batting`/`is_human_bowling` from `human_side == batting_team` at each innings start — the human can now bat second. `GameManager.return_scene` routes the Scorecard's Continue to the TournamentHub mid-tournament (MainMenu otherwise).
- **UI**: `TournamentHub.tscn` (team picker for new tournaments, both group tables via `PointsTable.gd`, fixture list with results, Play Next Fixture → `TossScreen.tscn` → MatchHUD, Sim Other Matches via a quick statistical sim for AI fixtures, abandon/resume), `TossScreen.tscn` (heads/tails call, coin animation, bat/bowl choice — the human's result of the toss decides who chooses).
- **Result recording**: `TossScreen` stashes `pending_fixture_result` meta; on return, the Hub records it into standings and advances the stage when a round completes.
- **Squads**: every team now has 15 players (XI auto-selected as the first 11) matching `SQUAD_SIZE`.
- **Verified headlessly**: the smoke test runs an entire 15-match tournament through the real engine (fast-forward), asserting stage transitions, standings math, champion, and a save/load round-trip.

---

**End of Document**  
*Use this text file directly as a knowledge base prompt when expanding features next.*
