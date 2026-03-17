# AtmosphereSystem.gd — Momentum tracking, crowd reactions, milestones (Module 8).
extends RefCounted
class_name AtmosphereSystem

func update_momentum(current: float, event: String) -> float:
	match event:
		"WICKET": current -= 0.25
		"SIX": current += 0.20
		"FOUR": current += 0.10
		"MAIDEN": current -= 0.15
		"BIG_OVER": current += 0.15
		"DOT_SEQUENCE": current -= 0.08
	return clampf(current, -1.0, 1.0)

func get_crowd_reaction(event: String) -> String:
	match event:
		"SIX": return "THE CROWD IS ON ITS FEET! 🎉"
		"WICKET": return "SILENCE... then a roar from the bowling side!"
		"FIFTY": return "Warm applause from the stands!"
		"HUNDRED": return "Standing ovation! Hat off moment!"
		"CLOSE_FINISH": return "ABSOLUTE PANDEMONIUM IN THE STADIUM!"
		_: return ""

func check_milestone(player: PlayerData, prev_runs: int) -> String:
	if prev_runs < 50 and player.match_runs >= 50: return "FIFTY"
	if prev_runs < 100 and player.match_runs >= 100: return "HUNDRED"
	return ""

func check_bowling_milestone(player: PlayerData, prev_wickets: int) -> String:
	if prev_wickets < 5 and player.match_wickets >= 5: return "FIFER"
	return ""

func is_close_finish(game_state: Dictionary) -> bool:
	if game_state.get("is_first_innings", true): return false
	var needed = game_state.get("target", 0) - game_state.get("total_runs", 0)
	var wickets = game_state.get("total_wickets", 0)
	return needed <= 10 and wickets == 9

func calculate_impact_score(player: PlayerData) -> float:
	var score = float(player.match_runs) * 1.0
	score += float(player.match_wickets) * 25.0
	score += float(player.match_sixes) * 5.0
	score += float(player.match_fours) * 2.0
	score += float(player.match_catches) * 10.0
	if player.get_strike_rate() > 150.0: score += 15.0
	if player.get_economy() > 0.0 and player.get_economy() < 6.0: score += 20.0
	return score

func get_man_of_match(team_a: TeamData, team_b: TeamData) -> PlayerData:
	var best: PlayerData = null
	var best_score: float = -1.0
	for p in team_a.playing_xi:
		var s = calculate_impact_score(p)
		if s > best_score:
			best_score = s
			best = p
	for p in team_b.playing_xi:
		var s = calculate_impact_score(p)
		if s > best_score:
			best_score = s
			best = p
	return best
