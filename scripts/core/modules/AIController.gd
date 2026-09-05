# AIController.gd — AI decision-making for batting, bowling, and fielding (Module 7).
extends RefCounted
class_name AIController

var _rng := RandomNumberGenerator.new()
var _difficulty: int = Constants.Difficulty.MEDIUM

func _init() -> void:
	_rng.randomize()

func set_difficulty(diff: int) -> void:
	_difficulty = diff

func choose_bowling_delivery(bowler: PlayerData, batsman: PlayerData, game_state: Dictionary) -> int:
	var phase = game_state.get("phase", Constants.MatchPhase.MIDDLE)
	var random_factor = _get_random_factor()
	if _rng.randf() < random_factor:
		return _rng.randi_range(0, 5)
	# Death overs — 80% yorkers, 20% slower
	if phase == Constants.MatchPhase.DEATH:
		if _rng.randf() < 0.8: return Constants.DeliveryType.YORKER
		else: return Constants.DeliveryType.SLOWER
	# Pattern detection: if batsman plays pull 3+, bowl yorker
	var pull_count = batsman.shot_history.get(Constants.ShotType.PULL_SHOT, 0)
	if pull_count >= 3: return Constants.DeliveryType.YORKER
	# Spin-friendly
	if bowler.bowling_type == "SPIN":
		return [Constants.DeliveryType.OFF_SPIN, Constants.DeliveryType.LEG_SPIN][_rng.randi_range(0, 1)]
	# Default: mix of good deliveries
	var options = [Constants.DeliveryType.YORKER, Constants.DeliveryType.BOUNCER, Constants.DeliveryType.FULL_TOSS, Constants.DeliveryType.SLOWER]
	return options[_rng.randi_range(0, options.size() - 1)]

func choose_batting_shot(batsman: PlayerData, game_state: Dictionary) -> int:
	var phase = game_state.get("phase", Constants.MatchPhase.MIDDLE)
	var random_factor = _get_random_factor()
	if _rng.randf() < random_factor:
		return _rng.randi_range(0, 5)
	var rrr = _calculate_rrr(game_state)
	# Powerplay
	if phase == Constants.MatchPhase.POWERPLAY:
		var weights = [0.35, 0.15, 0.10, 0.25, 0.10, 0.05]
		return _weighted_pick(weights)
	# Death overs chase
	if phase == Constants.MatchPhase.DEATH:
		if rrr > 10.0:
			return [Constants.ShotType.LOFT_SLOG, Constants.ShotType.AGGRESSIVE_DRIVE, Constants.ShotType.PULL_SHOT][_rng.randi_range(0, 2)]
		elif rrr > 7.0:
			var weights = [0.30, 0.20, 0.15, 0.20, 0.10, 0.05]
			return _weighted_pick(weights)
		else:
			var weights = [0.20, 0.15, 0.15, 0.10, 0.25, 0.15]
			return _weighted_pick(weights)
	# Middle overs — balanced
	var weights = [0.20, 0.15, 0.15, 0.10, 0.25, 0.15]
	return _weighted_pick(weights)

func choose_bowler(bowling_team: TeamData, game_state: Dictionary, prev_bowler: PlayerData = null) -> PlayerData:
	var bowlers = bowling_team.get_bowlers()
	var max_overs = Constants.MAX_BOWLER_OVERS_T20 if game_state.get("format", 0) == Constants.MatchFormat.T20 else Constants.MAX_BOWLER_OVERS_ODI
	var available: Array[PlayerData] = []
	for b in bowlers:
		if b.match_overs_bowled < float(max_overs):
			# Can't bowl consecutive overs
			if prev_bowler == null or b != prev_bowler:
				available.append(b)
	# If everyone eligible just bowled the last over, allow the freshest arm
	if available.is_empty() and prev_bowler != null:
		for b in bowlers:
			if b.match_overs_bowled < float(max_overs):
				available.append(b)
	if available.is_empty():
		return bowlers[0]
	return available[_rng.randi_range(0, available.size() - 1)]

func should_review_drs(batsman: PlayerData, has_reviews: bool, wicket_type: String) -> bool:
	if not has_reviews: return false
	if batsman.batting_skill > 80 and batsman.match_runs < 20:
		return _rng.randf() < 0.6
	return false

func _get_random_factor() -> float:
	match _difficulty:
		Constants.Difficulty.EASY: return 0.30
		Constants.Difficulty.MEDIUM: return 0.15
		Constants.Difficulty.HARD: return 0.05
		_: return 0.15

func _weighted_pick(weights: Array) -> int:
	var total = 0.0
	for w in weights: total += w
	var roll = _rng.randf() * total
	var accum = 0.0
	for i in range(weights.size()):
		accum += weights[i]
		if roll <= accum:
			return i
	return 0

func _calculate_rrr(game_state: Dictionary) -> float:
	if game_state.get("is_first_innings", true): return 0.0
	var target = game_state.get("target", 0)
	var runs = game_state.get("total_runs", 0)
	var over = game_state.get("current_over", 0)
	var ball = game_state.get("current_ball", 0)
	var max_o = game_state.get("max_overs", 20)
	var rem = (max_o * 6) - (over * 6 + ball)
	if rem <= 0: return 999.0
	return (float(target - runs) / float(rem)) * 6.0
