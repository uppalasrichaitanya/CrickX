# CrickX — Implementation Plan (living document)

> Status: Phases 1, 3, 4, 6 and the authenticity pack are **implemented**.
> Phase 2 (hot-seat) and Phase 5 (LAN) are **in progress this milestone**.
> Last updated at the start of the finish-all milestone.

## Phase 1: Core Engine, UI & Deep Logic — DONE
Playable T20/ODI (human batting, AI bowling/fielding) via UI only, with the full
8-module `BallSimulator` pipeline wired up. Includes the HUD-ready handshake fix
(P0) and the match-generation token that kills zombie ball-flow coroutines (P2).

## Phase 2: Hot-Seat Multiplayer — IN PROGRESS
Two players on one device: masked bowl selection, pass-the-device turn
transition overlay, both innings human-played. See `MatchEngine` hot-seat mode.

## Phase 3: Advanced AI Logic — DONE
`AIController` batting/bowling with RRR thresholds, phase awareness, shot-history
pattern recognition (pull-heavy humans get yorkers), bowler rotation with
consecutive-over guard, and DRS review decisions.

## Phase 4: Tournament System & Persistence — DONE
`TournamentManager`: World Cup structure (2 groups of 4 → semis → final),
points → NRR → wins tie-breaks, autosave/resume via `SaveManager`, quick
statistical sim for AI fixtures, `TournamentHub` + `PointsTable` + `TossScreen` UI.
15-player squads with XI selection persisted in the save.

## Phase 5: LAN Multiplayer — IN PROGRESS
`NetworkManager` ENet host/join with an authoritative host sim: the host runs
`MatchEngine`, the client sends shot/bowl/DRS inputs via RPC and receives ball
outcomes. Verified with a headless host+client loopback test.

## Phase 6: Interactive 2D Graphics Engine — DONE
`scenes/match/FieldView.tscn`: top-down TV-style oval drawn with `_draw()`
(grass, rope, 30-yard circle, pitch, creases, stumps), 14 live markers, per-delivery
trajectories, outcome animations (rope bursts, six arcs, stump shatterings,
drops), wagon-wheel overlay, milestone fireworks. Phase-aware fielding
(powerplay ring → death boundary riders).

## Follow-ups (authenticity pack)
- XI selection from 15-man squads with validation + auto-repair
- Super overs: 1 over/side, 2-wicket cap, repeating rounds, NRR-safe recording
- Coin toss with bat/bowl choice (human can bat second via the `human_side` model)
- Phase-aware catch modifiers in the sim

## Conventions for future work
- New engine states go in `MatchEngine.State`; every `await` resume point must
  check the `_match_gen` token.
- New UI scenes follow the existing `Control` + `theme_override_*` pattern
  (no `.tres` sub-resources — they break the text scene parser).
- Every feature lands with headless coverage in `tests/smoke_test.gd`
  (exit 0 = green) and a README + history-doc update.
