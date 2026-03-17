# PressureMoraleSystem.gd — Calculates batting pressure and player morale (Module 3).
extends RefCounted
class_name PressureMoraleSystem

func calculate_pressure(game_state: Dictionary, recent_dots: int) -> float:
	var pressure: float = 0.0
	
	if not game_state.get("is_first_innings", true):
		var target = game_state.get("target", 0)
		var runs = game_state.get("total_runs", 0)
		var overs = game_state.get("current_over", 0)
		var balls = game_state.get("current_ball", 0)
		var max_overs = game_state.get("max_overs", 20)
		var remaining_balls = (max_overs * 6) - (overs * 6 + balls)
		var runs_needed = target - runs
		
		if remaining_balls > 0:
			var rrr = (float(runs_needed) / float(remaining_balls)) * 6.0
			if rrr > 12.0:
				pressure += 0.30
			elif rrr > 10.0:
				pressure += 0.20
			elif rrr > 8.0:
				pressure += 0.10
			
			if remaining_balls <= 30 and runs_needed > 60:
				pressure += 0.25
	
	var wickets = game_state.get("total_wickets", 0)
	if wickets >= 7:
		pressure += 0.20
	
	# Dot ball pressure
	if recent_dots >= 4:
		pressure += 0.05 * (recent_dots - 3)
	
	return clampf(pressure, 0.0, 1.0)

func apply_pressure_event(current_pressure: float, event: String) -> float:
	match event:
		"WICKET":
			current_pressure += 0.25
		"BOUNDARY":
			current_pressure -= 0.10
		"SIX":
			current_pressure -= 0.15
		"BIG_OVER":
			current_pressure -= 0.12
		"PARTNERSHIP_100":
			current_pressure -= 0.20
		"DRS_FAILED":
			current_pressure += 0.10
	return clampf(current_pressure, 0.0, 1.0)

func update_morale(player: PlayerData, event: String) -> void:
	match event:
		"SCORED_30":
			player.morale = clampf(player.morale + 0.10, 0.0, 1.0)
		"SCORED_50":
			player.morale = clampf(player.morale + 0.15, 0.0, 1.0)
		"HIT_TWO_SIXES":
			player.morale = clampf(player.morale + 0.08, 0.0, 1.0)
		"TOOK_WICKET":
			player.morale = clampf(player.morale + 0.12, 0.0, 1.0)
		"DIVING_CATCH":
			player.morale = clampf(player.morale + 0.10, 0.0, 1.0)
		"TEAM_WON_LAST":
			player.morale = clampf(player.morale + 0.05, 0.0, 1.0)
		"CHEAP_DISMISSAL":
			player.morale = clampf(player.morale - 0.10, 0.0, 1.0)
		"DROPPED_CATCH":
			player.morale = clampf(player.morale - 0.08, 0.0, 1.0)
		"HIT_THREE_SIXES":
			player.morale = clampf(player.morale - 0.12, 0.0, 1.0)
		"BOWLED_WIDE_PRESSURE":
			player.morale = clampf(player.morale - 0.06, 0.0, 1.0)
		"TEAM_LOST_LAST":
			player.morale = clampf(player.morale - 0.05, 0.0, 1.0)

func get_morale_label(player: PlayerData) -> String:
	if player.morale > Constants.HIGH_MORALE_THRESHOLD:
		return "CONFIDENT"
	elif player.morale < Constants.LOW_MORALE_THRESHOLD:
		return "STRUGGLING"
	else:
		return "STEADY"
