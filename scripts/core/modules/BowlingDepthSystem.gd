# BowlingDepthSystem.gd — Seam/swing, spin variations, line/length, rhythm (Module 6).
extends RefCounted
class_name BowlingDepthSystem

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

func calculate_swing(bowler: PlayerData, over: int, weather_mods: Dictionary, format: int) -> Dictionary:
	var result = { "swing_amount": 0.0, "reverse_swing": false, "seam_chance": 0.0 }
	if bowler.bowling_type == "FAST" or bowler.bowling_type == "MEDIUM":
		if over <= 10:
			result["swing_amount"] = 0.3 + float(bowler.bowling_skill) * 0.003 + weather_mods.get("swing_bonus", 0.0)
		else:
			result["swing_amount"] = maxf(0.0, 0.15 - float(over) * 0.005) + weather_mods.get("swing_bonus", 0.0)
		var threshold = 12 if format == Constants.MatchFormat.T20 else 30
		if over >= threshold and weather_mods.get("swing_bonus", 0.0) > 0.1:
			result["reverse_swing"] = true
			result["swing_amount"] = 0.25
		result["seam_chance"] = 0.15 + weather_mods.get("seam_bonus", 0.0)
	return result

func get_spin_variation(bowler: PlayerData, bowl_type: int) -> Dictionary:
	var variation = { "type": "STANDARD", "turn_amount": 0.0, "hidden": false, "read_difficulty": 0.0 }
	if bowler.bowling_type != "SPIN":
		return variation
	var roll = _rng.randf()
	if bowl_type == Constants.DeliveryType.OFF_SPIN:
		if roll < 0.5:
			variation = { "type": "OFF_BREAK", "turn_amount": 0.20, "hidden": false, "read_difficulty": 0.0 }
		elif roll < 0.7:
			variation = { "type": "DOOSRA", "turn_amount": 0.18, "hidden": true, "read_difficulty": 0.7 }
		elif roll < 0.85:
			variation = { "type": "ARM_BALL", "turn_amount": 0.0, "hidden": true, "read_difficulty": 0.5 }
		else:
			variation = { "type": "CARROM_BALL", "turn_amount": 0.15, "hidden": true, "read_difficulty": 0.8 }
	elif bowl_type == Constants.DeliveryType.LEG_SPIN:
		if roll < 0.4:
			variation = { "type": "LEG_BREAK", "turn_amount": 0.22, "hidden": false, "read_difficulty": 0.0 }
		elif roll < 0.6:
			variation = { "type": "GOOGLY", "turn_amount": 0.20, "hidden": true, "read_difficulty": 0.8 }
		elif roll < 0.75:
			variation = { "type": "FLIPPER", "turn_amount": 0.05, "hidden": true, "read_difficulty": 0.6 }
		elif roll < 0.9:
			variation = { "type": "TOP_SPINNER", "turn_amount": 0.10, "hidden": false, "read_difficulty": 0.4 }
		else:
			variation = { "type": "WRONG_UN", "turn_amount": 0.18, "hidden": true, "read_difficulty": 0.75 }
	return variation

func can_batsman_read_variation(batsman: PlayerData, variation: Dictionary) -> bool:
	if not variation.get("hidden", false):
		return true
	var read_chance = (float(batsman.batting_skill) * 0.6 + batsman.form * 40.0) / 100.0
	return _rng.randf() < read_chance

func calculate_accuracy(bowler: PlayerData) -> Dictionary:
	var accuracy = float(bowler.bowling_skill) / 100.0 * (0.7 + bowler.rhythm * 0.6)
	var miss = (1.0 - accuracy) * _rng.randf_range(-1.0, 1.0)
	# Wide is a small explicit probability scaled by inaccuracy (elite ~0.5%, weak ~10%)
	var wide_chance = clampf((1.0 - accuracy) * 0.15, 0.005, 0.10)
	return { "accuracy": accuracy, "miss_amount": miss, "is_wide": _rng.randf() < wide_chance }

func update_rhythm(bowler: PlayerData, outcome: Dictionary) -> void:
	var runs = outcome.get("runs", 0)
	if outcome.get("is_wicket", false): bowler.rhythm = clampf(bowler.rhythm + 0.12, 0.0, 1.0)
	elif runs == 0 and not outcome.get("is_wide", false): bowler.rhythm = clampf(bowler.rhythm + 0.08, 0.0, 1.0)
	if runs == 4: bowler.rhythm = clampf(bowler.rhythm - 0.10, 0.0, 1.0)
	if runs == 6: bowler.rhythm = clampf(bowler.rhythm - 0.15, 0.0, 1.0)
	if outcome.get("is_wide", false) or outcome.get("is_no_ball", false): bowler.rhythm = clampf(bowler.rhythm - 0.08, 0.0, 1.0)

func get_rhythm_label(bowler: PlayerData) -> String:
	if bowler.rhythm > Constants.HIGH_RHYTHM_THRESHOLD: return "IN_THE_GROOVE"
	elif bowler.rhythm < Constants.LOW_RHYTHM_THRESHOLD: return "LOSING_IT"
	else: return "STEADY"

func get_spell_modifier(bowler: PlayerData) -> Dictionary:
	var overs = bowler.current_spell_overs
	if overs < 1.0: return { "accuracy_mod": -0.05, "pace_mod": -2.0 }
	elif overs <= 2.5: return { "accuracy_mod": 0.0, "pace_mod": 0.0 }
	else:
		var extra = overs - 2.5
		return { "accuracy_mod": -0.05 * extra, "pace_mod": -1.0 * extra }

func get_ball_speed(bowler: PlayerData) -> float:
	if bowler.bowling_type == "FAST": return _rng.randf_range(135.0, 150.0) + get_spell_modifier(bowler)["pace_mod"]
	elif bowler.bowling_type == "MEDIUM": return _rng.randf_range(120.0, 135.0) + get_spell_modifier(bowler)["pace_mod"]
	elif bowler.bowling_type == "SPIN": return _rng.randf_range(80.0, 95.0)
	return 0.0
