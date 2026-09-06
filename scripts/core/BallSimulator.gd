# BallSimulator.gd — Master simulation pipeline.
# Calls each deep logic module sequentially to produce a BallOutcome.
# SHOT RISK HIERARCHY: Leave < Block < Drive < Pull/Sweep < Slog
extends Node
class_name BallSimulator

var form_fatigue := FormFatigueSystem.new()
var weather_pitch := WeatherPitchSystem.new()
var pressure_morale := PressureMoraleSystem.new()
var drs := DRSSystem.new()
var batting_depth := BattingDepthSystem.new()
var bowling_depth := BowlingDepthSystem.new()
var ai_controller := AIController.new()
var atmosphere := AtmosphereSystem.new()
var _rng := RandomNumberGenerator.new()
var recent_dots: int = 0

func _ready() -> void:
	_rng.randomize()
	ai_controller.set_difficulty(GameManager.difficulty)

func simulate_ball(batsman: PlayerData, bowler: PlayerData,
		shot_type: int, delivery_type: int, game_state: Dictionary,
		fielding_team: TeamData = null) -> Dictionary:
	# 1. Weather & Pitch modifiers
	var weather_mods = weather_pitch.update(game_state)
	
	# 2. Pressure calculation
	var pressure = pressure_morale.calculate_pressure(game_state, recent_dots)
	GameManager.batting_pressure = pressure
	
	# 3. Batting timing
	var timing = batting_depth.calculate_timing(batsman, pressure)
	var timing_mods = batting_depth.get_timing_modifier(timing)
	
	# 4. Bowling accuracy & swing
	var accuracy = bowling_depth.calculate_accuracy(bowler)
	var swing = bowling_depth.calculate_swing(bowler, game_state.get("current_over", 0), weather_mods, game_state.get("format", 0))
	var speed = bowling_depth.get_ball_speed(bowler)
	
	# 5. Spin variation
	var variation = bowling_depth.get_spin_variation(bowler, delivery_type)
	var read_spin = bowling_depth.can_batsman_read_variation(batsman, variation)
	
	# 6. Matchup matrix
	var matchup = Constants.get_matchup(delivery_type, shot_type)
	
	# 7. Calculate base outcome probabilities
	var prev_runs = batsman.match_runs
	var prev_wickets = bowler.match_wickets
	var outcome = _resolve_outcome(batsman, bowler, shot_type, delivery_type,
		matchup, timing_mods, weather_mods, accuracy, swing, variation,
		read_spin, pressure, game_state, fielding_team)
	
	# 8. Update form & fatigue
	form_fatigue.update_batsman(batsman, outcome, game_state)
	form_fatigue.update_bowler(bowler, outcome, game_state)
	
	# 9. Update bowling rhythm
	bowling_depth.update_rhythm(bowler, outcome)
	
	# 10. Update batting confidence
	var runs = outcome.get("runs", 0)
	if runs == 4: batting_depth.update_confidence(batsman, "FOUR")
	elif runs == 6: batting_depth.update_confidence(batsman, "SIX")
	elif runs == 0 and not outcome.get("is_wide", false):
		batting_depth.update_confidence(batsman, "BEATEN")
	
	# 11. Atmosphere
	if runs == 6: GameManager.momentum = atmosphere.update_momentum(GameManager.momentum, "SIX")
	elif runs == 4: GameManager.momentum = atmosphere.update_momentum(GameManager.momentum, "FOUR")
	elif outcome.get("is_wicket", false): GameManager.momentum = atmosphere.update_momentum(GameManager.momentum, "WICKET")
	elif runs == 0: recent_dots += 1
	if runs > 0: recent_dots = 0
	
	# 12. Milestones
	var milestone = atmosphere.check_milestone(batsman, prev_runs)
	var bowl_milestone = atmosphere.check_bowling_milestone(bowler, prev_wickets)
	outcome["milestone"] = milestone
	outcome["bowl_milestone"] = bowl_milestone
	outcome["timing"] = timing
	outcome["timing_name"] = batting_depth.get_timing_name(timing)
	outcome["ball_speed"] = speed
	outcome["variation"] = variation.get("type", "STANDARD")
	outcome["pressure"] = pressure
	outcome["in_the_zone"] = batting_depth.is_in_the_zone(batsman)
	outcome["close_finish"] = atmosphere.is_close_finish(game_state)
	
	# 13. Pitch wear
	GameManager.pitch_wear += Constants.PITCH_WEAR_PER_BALL
	game_state["pitch_wear"] = GameManager.pitch_wear
	
	return outcome

# ═══════════════════════════════════════
# SHOT-TYPE RISK/REWARD TABLE
# ═══════════════════════════════════════
# Returns { wicket_scale, boundary_scale, dot_bonus }
# wicket_scale < 1.0 means SAFER, > 1.0 means RISKIER
func _get_shot_profile(shot_type: int) -> Dictionary:
	match shot_type:
		Constants.ShotType.DEFENSIVE_BLOCK:
			# Very safe — almost never out, but rarely scores
			return { "wicket_scale": 0.15, "boundary_scale": 0.05, "dot_bonus": 0.35, "run_cap": 1 }
		Constants.ShotType.LEAVE_BALL:
			# Safest possible — only dangerous if on stumps
			return { "wicket_scale": 0.0, "boundary_scale": 0.0, "dot_bonus": 0.90, "run_cap": 0 }
		Constants.ShotType.AGGRESSIVE_DRIVE:
			# Moderate risk, good boundary chance
			return { "wicket_scale": 0.7, "boundary_scale": 1.2, "dot_bonus": 0.0, "run_cap": 6 }
		Constants.ShotType.PULL_SHOT:
			# Good risk/reward, especially vs short balls
			return { "wicket_scale": 0.85, "boundary_scale": 1.3, "dot_bonus": 0.0, "run_cap": 6 }
		Constants.ShotType.SWEEP_SHOT:
			# Moderate risk, good vs spin
			return { "wicket_scale": 0.8, "boundary_scale": 1.1, "dot_bonus": 0.0, "run_cap": 6 }
		Constants.ShotType.LOFT_SLOG:
			# Maximum risk, maximum reward
			return { "wicket_scale": 1.5, "boundary_scale": 1.8, "dot_bonus": -0.10, "run_cap": 6 }
		_:
			return { "wicket_scale": 1.0, "boundary_scale": 1.0, "dot_bonus": 0.0, "run_cap": 6 }

func _resolve_outcome(batsman: PlayerData, bowler: PlayerData,
		shot_type: int, delivery_type: int,
		matchup: Dictionary, timing_mods: Dictionary,
		weather_mods: Dictionary, accuracy: Dictionary,
		swing: Dictionary, variation: Dictionary,
		read_spin: bool, pressure: float, game_state: Dictionary,
		fielding_team: TeamData = null) -> Dictionary:

	# Check for wide first
	if accuracy.get("is_wide", false):
		return { "runs": 1, "is_wicket": false, "is_wide": true, "is_no_ball": false,
			"wicket_type": "", "shot_type": shot_type, "delivery_type": delivery_type, "commentary_key": "WIDE" }

	# No ball chance scales with the bowler's inaccuracy (elite ~0.5%, wild ~10%)
	var no_ball_chance = clampf(
		Constants.NO_BALL_BASE * (1.0 + (1.0 - float(accuracy.get("accuracy", 0.8))) * 6.0),
		0.002, Constants.NO_BALL_MAX)
	if _rng.randf() < no_ball_chance:
		return { "runs": 1, "is_wicket": false, "is_wide": false, "is_no_ball": true,
			"wicket_type": "", "shot_type": shot_type, "delivery_type": delivery_type,
			"commentary_key": "NO_BALL", "zone": batting_depth.get_shot_zone(shot_type) }
	
	# ── Get shot risk profile ──
	var profile = _get_shot_profile(shot_type)
	
	# Leave ball — special handling
	if shot_type == Constants.ShotType.LEAVE_BALL:
		# Only bowled if yorker/stumps delivery AND bad luck
		if delivery_type == Constants.DeliveryType.YORKER and _rng.randf() < 0.06:
			return _wicket_outcome("BOWLED", shot_type, delivery_type, bowler)
		if delivery_type == Constants.DeliveryType.OFF_SPIN and _rng.randf() < 0.03:
			return _wicket_outcome("LBW", shot_type, delivery_type, bowler)
		return { "runs": 0, "is_wicket": false, "is_wide": false, "is_no_ball": false,
			"wicket_type": "", "shot_type": shot_type, "delivery_type": delivery_type,
			"commentary_key": "DOT", "zone": Constants.FieldZone.FINE_LEG }
	
	# Calculate probabilities
	var bat_eff = batsman.get_effective_batting_skill()
	var bowl_eff = bowler.get_effective_bowling_skill()
	var skill_diff = (bat_eff - bowl_eff) / 100.0
	
	# Base probabilities from matchup matrix
	var base_wicket = matchup.get("wicket_mod", 0.12) + timing_mods.get("wicket_mod", 0.0)
	var base_boundary = matchup.get("boundary_mod", 0.15) + timing_mods.get("boundary_mod", 0.0)
	var base_dot = matchup.get("dot_mod", 0.40)
	
	# ── APPLY SHOT PROFILE SCALING ──
	var wicket_chance = base_wicket * profile["wicket_scale"]
	var boundary_chance = base_boundary * profile["boundary_scale"]
	var dot_chance = base_dot + profile["dot_bonus"]
	
	# Skill differential adjustments
	wicket_chance -= skill_diff * 0.12
	boundary_chance += skill_diff * 0.08
	
	# Swing bonus for bowler (reduced impact on defensive)
	wicket_chance += swing.get("swing_amount", 0.0) * 0.2 * profile["wicket_scale"]
	
	# Spin variation penalty if not read
	if not read_spin and variation.get("hidden", false):
		wicket_chance += 0.10 * profile["wicket_scale"]
		boundary_chance -= 0.08
	
	# Fatigue effects (less impact on defensive batting)
	if batsman.fatigue > Constants.HIGH_FATIGUE_THRESHOLD:
		wicket_chance += 0.05 * profile["wicket_scale"]
		boundary_chance -= 0.04
	
	# Pressure effects (defensive shots handle pressure better)
	if pressure > Constants.HIGH_PRESSURE_THRESHOLD:
		wicket_chance += 0.06 * profile["wicket_scale"]
		boundary_chance -= 0.03
	
	# Confidence bonus
	if batting_depth.is_in_the_zone(batsman):
		boundary_chance += 0.10 * profile["boundary_scale"]
		wicket_chance -= 0.05
	
	# Weather boundary modifier
	boundary_chance += weather_mods.get("boundary_mod", 0.0)
	boundary_chance += weather_mods.get("six_chance_mod", 0.0)
	
	# ── CLAMP with shot-specific limits ──
	# Defensive block: max 3% wicket chance, nearly 0 boundary
	if shot_type == Constants.ShotType.DEFENSIVE_BLOCK:
		wicket_chance = clampf(wicket_chance, 0.005, 0.03)
		boundary_chance = clampf(boundary_chance, 0.0, 0.02)
		dot_chance = clampf(dot_chance, 0.50, 0.85)
	else:
		wicket_chance = clampf(wicket_chance, 0.02, 0.55)
		boundary_chance = clampf(boundary_chance, 0.03, 0.50)
		dot_chance = clampf(dot_chance, 0.10, 0.65)
	
	# ── ROLL ──
	var roll = _rng.randf()
	var accum = 0.0

	accum += wicket_chance
	if roll < accum:
		var wtype = _determine_wicket_type(delivery_type, shot_type)
		# Caught chances are contested by a real fielder — can be dropped.
		if wtype in ["CAUGHT", "CAUGHT_BEHIND"]:
			var fielded = _resolve_catch(wtype, batsman, bowler, shot_type, delivery_type,
				fielding_team, game_state.get("phase", 1))
			if not fielded.is_empty():
				return fielded
			# Dropped! Safe runs instead — costly miss.
			return { "runs": 1, "is_wicket": false, "is_wide": false, "is_no_ball": false,
				"wicket_type": "", "shot_type": shot_type, "delivery_type": delivery_type,
				"commentary_key": "DROPPED_CATCH", "dropped_by": _last_fielder_name }
		return _wicket_outcome(wtype, shot_type, delivery_type, bowler)

	# Sixes (40% of boundary for aggressive, 0% for defensive)
	var six_ratio = 0.4 if shot_type != Constants.ShotType.DEFENSIVE_BLOCK else 0.0
	accum += boundary_chance * six_ratio
	if roll < accum and profile["run_cap"] >= 6:
		return { "runs": 6, "is_wicket": false, "is_wide": false, "is_no_ball": false,
			"wicket_type": "", "shot_type": shot_type, "delivery_type": delivery_type,
			"commentary_key": "SIX", "zone": batting_depth.get_shot_zone(shot_type) }

	# Fours
	accum += boundary_chance * (1.0 - six_ratio)
	if roll < accum and profile["run_cap"] >= 4:
		return { "runs": 4, "is_wicket": false, "is_wide": false, "is_no_ball": false,
			"wicket_type": "", "shot_type": shot_type, "delivery_type": delivery_type,
			"commentary_key": "FOUR", "zone": batting_depth.get_shot_zone(shot_type) }
	
	accum += dot_chance
	if roll < accum:
		return { "runs": 0, "is_wicket": false, "is_wide": false, "is_no_ball": false,
			"wicket_type": "", "shot_type": shot_type, "delivery_type": delivery_type,
			"commentary_key": "DOT", "zone": batting_depth.get_shot_zone(shot_type) }
	
	# Remaining = 1, 2, or 3 runs (capped by shot profile)
	var run_roll = _rng.randf()
	var runs_scored = 1
	if profile["run_cap"] >= 3 and run_roll < 0.15: runs_scored = 3
	elif profile["run_cap"] >= 2 and run_roll < 0.40: runs_scored = 2
	
	# Defensive block can only push for 1 run
	if shot_type == Constants.ShotType.DEFENSIVE_BLOCK:
		runs_scored = 1
	
	var key = "SINGLE" if runs_scored == 1 else ("TWO" if runs_scored == 2 else "THREE")
	
	return { "runs": runs_scored, "is_wicket": false, "is_wide": false, "is_no_ball": false,
		"wicket_type": "", "shot_type": shot_type, "delivery_type": delivery_type,
		"commentary_key": key, "zone": batting_depth.get_shot_zone(shot_type) }

func _determine_wicket_type(delivery: int, shot: int) -> String:
	var roll = _rng.randf()
	if delivery == Constants.DeliveryType.YORKER: return "BOWLED"
	if shot == Constants.ShotType.LOFT_SLOG:
		if roll < 0.65: return "CAUGHT"
		else: return "BOWLED"
	if shot == Constants.ShotType.PULL_SHOT:
		if roll < 0.5: return "CAUGHT"
		elif roll < 0.7: return "CAUGHT_BEHIND"
		else: return "BOWLED"
	if delivery in [Constants.DeliveryType.OFF_SPIN, Constants.DeliveryType.LEG_SPIN]:
		if roll < 0.35: return "LBW"
		elif roll < 0.65: return "BOWLED"
		else: return "STUMPED"
	if roll < 0.30: return "CAUGHT"
	elif roll < 0.55: return "BOWLED"
	elif roll < 0.75: return "LBW"
	elif roll < 0.88: return "CAUGHT_BEHIND"
	else: return "RUN_OUT"

var _last_fielder_name: String = ""

# Resolves a "caught" dismissal against a real fielder from the bowling XI.
# Returns a wicket outcome Dictionary if the catch is held; an EMPTY Dictionary
# means dropped (the caller converts it into safe runs).
func _resolve_catch(wtype: String, batsman: PlayerData, bowler: PlayerData,
		shot: int, delivery: int, fielding_team: TeamData, phase: int = 1) -> Dictionary:
	# Pick a fielder (exclude the bowler — he already did his job)
	var fielder: PlayerData = null
	if fielding_team != null and fielding_team.playing_xi.size() > 1:
		var candidates: Array[PlayerData] = []
		for p in fielding_team.playing_xi:
			if p != bowler:
				candidates.append(p)
		if candidates.size() > 0:
			fielder = candidates[_rng.randi_range(0, candidates.size() - 1)]

	# Catch probability from the fielder's skill (and the take has to be clean).
	# Field settings matter: the ring is up in the powerplay, spread at the death.
	var hold_chance = Constants.CATCH_BASE_CHANCE
	hold_chance += float(Constants.CATCH_PHASE_MOD.get(phase, 0.0))
	if fielder != null:
		hold_chance += (float(fielder.fielding_skill) - 60.0) * Constants.CATCH_SKILL_WEIGHT
		_last_fielder_name = fielder.player_name
	else:
		_last_fielder_name = ""
	hold_chance = clampf(hold_chance, 0.45, 0.97) * Constants.CARRY_BASE_CHANCE

	if _rng.randf() >= hold_chance:
		# Dropped!
		if fielder != null:
			pressure_morale.update_morale(fielder, "DROPPED_CATCH")
		return {}

	# Held — credit the catch and build the dismissal text.
	var display := ""
	if fielder != null:
		fielder.match_catches += 1
		pressure_morale.update_morale(fielder, "DIVING_CATCH")
		var prefix := "st" if wtype == "STUMPED" else "c"
		display = prefix + " " + fielder.player_name + " b "
	else:
		display = "b "
	var o = _wicket_outcome(wtype, shot, delivery)
	o["fielder_name"] = fielder.player_name if fielder != null else ""
	o["dismissal_display"] = display + bowler.player_name
	return o

func _wicket_outcome(wtype: String, shot: int, delivery: int, bowler: PlayerData = null) -> Dictionary:
	var display := wtype
	if bowler != null:
		match wtype:
			"BOWLED": display = "b " + bowler.player_name
			"LBW": display = "lbw b " + bowler.player_name
			"RUN_OUT": display = "run out"
			"STUMPED": display = "st b " + bowler.player_name
			_: display = wtype
	return { "runs": 0, "is_wicket": true, "is_wide": false, "is_no_ball": false,
		"wicket_type": wtype, "shot_type": shot, "delivery_type": delivery,
		"commentary_key": "WICKET", "dismissal_display": display,
		"zone": batting_depth.get_shot_zone(shot) }
