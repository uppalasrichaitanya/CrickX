# BattingDepthSystem.gd — Shot timing, footwork, wagon wheel, and confidence (Module 5).
extends RefCounted
class_name BattingDepthSystem

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

# ─── Shot Timing ───
func calculate_timing(batsman: PlayerData, pressure: float) -> int:
	var base_timing = float(batsman.batting_skill) / 100.0
	var timing_roll = _rng.randf()
	var threshold = base_timing * batsman.form * (1.0 - pressure * 0.3)
	
	if timing_roll < threshold:
		return Constants.Timing.PERFECT
	elif timing_roll < threshold * 1.4:
		return [Constants.Timing.EARLY, Constants.Timing.LATE][_rng.randi_range(0, 1)]
	else:
		return Constants.Timing.MISTIMED

func get_timing_modifier(timing: int) -> Dictionary:
	match timing:
		Constants.Timing.PERFECT:
			return { "boundary_mod": 0.15, "wicket_mod": -0.10 }
		Constants.Timing.EARLY:
			return { "boundary_mod": -0.10, "wicket_mod": 0.15 }
		Constants.Timing.LATE:
			return { "boundary_mod": -0.05, "wicket_mod": 0.08 }
		Constants.Timing.MISTIMED:
			return { "boundary_mod": -0.15, "wicket_mod": 0.25 }
		_:
			return { "boundary_mod": 0.0, "wicket_mod": 0.0 }

# ─── Footwork ───
func check_footwork(footwork: int, delivery_length: int) -> Dictionary:
	var correct = false
	match delivery_length:
		Constants.BowlLength.YORKER, Constants.BowlLength.FULL:
			correct = (footwork == Constants.Footwork.FRONT_FOOT)
		Constants.BowlLength.SHORT:
			correct = (footwork == Constants.Footwork.BACK_FOOT)
		Constants.BowlLength.GOOD_LENGTH:
			correct = true  # Both viable
	
	if correct:
		return { "wicket_mod": 0.0, "boundary_mod": 0.0 }
	else:
		# Wrong footwork — severe penalty
		if delivery_length == Constants.BowlLength.SHORT and footwork == Constants.Footwork.FRONT_FOOT:
			return { "wicket_mod": 0.20, "boundary_mod": -0.15 }
		else:
			return { "wicket_mod": 0.15, "boundary_mod": -0.10 }

# ─── Wagon Wheel Zone ───
func get_shot_zone(shot_type: int) -> int:
	var zones = Constants.SHOT_ZONES.get(shot_type, [Constants.FieldZone.MID_OFF])
	if zones.is_empty():
		return Constants.FieldZone.MID_OFF
	return zones[_rng.randi_range(0, zones.size() - 1)]

func check_fielder_in_zone(zone: int, _field_placement: Array = []) -> bool:
	# Simplified: 30% chance by default, field placement can override
	return _rng.randf() < 0.30

# ─── Confidence ───
func update_confidence(player: PlayerData, event: String) -> void:
	match event:
		"FOUR":
			player.confidence = clampi(player.confidence + 8, 0, 100)
		"SIX":
			player.confidence = clampi(player.confidence + 12, 0, 100)
		"GOOD_RUNNING":
			player.confidence = clampi(player.confidence + 5, 0, 100)
		"SURVIVED_TOUGH":
			player.confidence = clampi(player.confidence + 15, 0, 100)
		"MILESTONE_50":
			player.confidence = clampi(player.confidence + 20, 0, 100)
		"BEATEN":
			player.confidence = clampi(player.confidence - 10, 0, 100)
		"MISTIMED_AIR":
			player.confidence = clampi(player.confidence - 8, 0, 100)
		"MAIDEN_FACED":
			player.confidence = clampi(player.confidence - 12, 0, 100)
		"DRS_FAILED":
			player.confidence = clampi(player.confidence - 5, 0, 100)

func is_in_the_zone(player: PlayerData) -> bool:
	return player.confidence >= Constants.IN_THE_ZONE_CONFIDENCE

func get_confidence_modifier(player: PlayerData) -> float:
	return (float(player.confidence) - 50.0) / 200.0

func get_timing_name(timing: int) -> String:
	match timing:
		Constants.Timing.PERFECT: return "Perfect"
		Constants.Timing.EARLY: return "Early"
		Constants.Timing.LATE: return "Late"
		Constants.Timing.MISTIMED: return "Mistimed"
		_: return "Unknown"
