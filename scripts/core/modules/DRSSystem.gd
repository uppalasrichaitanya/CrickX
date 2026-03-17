# DRSSystem.gd — Decision Review System simulation (Module 4).
# Handles ball tracking, edge detection, umpire's call, and review outcomes.
extends RefCounted
class_name DRSSystem

var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.randomize()

# Returns: { "overturned": bool, "umpires_call": bool, "checks": Dictionary, "commentary": String }
func review_decision(wicket_type: String, batsman: PlayerData, bowler: PlayerData,
		original_decision_out: bool) -> Dictionary:
	var result = {
		"overturned": false,
		"umpires_call": false,
		"checks": {},
		"commentary": "",
	}
	
	match wicket_type:
		"LBW":
			result["checks"] = _simulate_ball_tracking(bowler)
			var bt = result["checks"]
			var all_pass = bt["pitched_in_line"] and bt["impact_in_line"] and bt["hitting_stumps"]
			
			if bt.get("umpires_call_zone", false):
				result["umpires_call"] = true
				result["overturned"] = false
				result["commentary"] = "Umpire's Call! Ball clipping the stumps. Review retained."
			elif original_decision_out and not all_pass:
				result["overturned"] = true
				result["commentary"] = "OVERTURNED! NOT OUT! Ball missing the stumps!"
			elif not original_decision_out and all_pass:
				result["overturned"] = true
				result["commentary"] = "OVERTURNED! OUT! That was hitting all three!"
			else:
				result["overturned"] = false
				result["commentary"] = "Decision UPHELD. Review lost."
		
		"CAUGHT", "CAUGHT_BEHIND":
			result["checks"] = _simulate_edge_detection(batsman)
			var ed = result["checks"]
			
			if original_decision_out and not ed["edge_detected"]:
				result["overturned"] = true
				result["commentary"] = "OVERTURNED! No edge detected! NOT OUT!"
			elif not original_decision_out and ed["edge_detected"] and ed["carry_clear"]:
				result["overturned"] = true
				result["commentary"] = "OVERTURNED! Clear edge! OUT!"
			else:
				result["overturned"] = false
				result["commentary"] = "Decision UPHELD."
		
		_:
			result["commentary"] = "Decision UPHELD. Not reviewable."
	
	return result

func _simulate_ball_tracking(bowler: PlayerData) -> Dictionary:
	var skill_factor = bowler.get_effective_bowling_skill() / 100.0
	var variance = _rng.randf_range(-0.15, 0.15)
	
	var pitched_in_line = _rng.randf() < (0.7 + variance)
	var impact_in_line = _rng.randf() < (0.65 + variance)
	var hitting_stumps = _rng.randf() < (0.6 + skill_factor * 0.2 + variance)
	var umpires_call = _rng.randf() < 0.15  # 15% chance of umpire's call zone
	
	return {
		"pitched_in_line": pitched_in_line,
		"impact_in_line": impact_in_line,
		"hitting_stumps": hitting_stumps,
		"umpires_call_zone": umpires_call and (pitched_in_line and impact_in_line),
	}

func _simulate_edge_detection(batsman: PlayerData) -> Dictionary:
	var edge_chance = 0.5
	if batsman.batting_skill < 60:
		edge_chance = 0.7
	
	var thick_edge = _rng.randf() < 0.3
	var feather_edge = _rng.randf() < 0.6
	var edge_detected = thick_edge or feather_edge
	var carry_clear = _rng.randf() < 0.8
	
	return {
		"edge_detected": edge_detected,
		"thick_edge": thick_edge,
		"feather_edge": feather_edge and not thick_edge,
		"carry_clear": carry_clear,
	}

func should_ai_review(batsman: PlayerData, has_reviews: bool, wicket_type: String) -> bool:
	if not has_reviews:
		return false
	# AI reviews if star player dismissed cheaply
	if batsman.batting_skill > 80 and batsman.match_runs < 20:
		return _rng.randf() < 0.6
	return false
