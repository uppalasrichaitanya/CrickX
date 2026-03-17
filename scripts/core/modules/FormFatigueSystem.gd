# FormFatigueSystem.gd — Tracks player form and fatigue (Module 1).
# Form (0.0-1.0): how "in touch" a player is. Fatigue (0.0-1.0): physical tiredness.
extends RefCounted
class_name FormFatigueSystem

func update_batsman(player: PlayerData, outcome: Dictionary, _game_state: Dictionary) -> void:
	var runs = outcome.get("runs", 0)
	var is_wicket = outcome.get("is_wicket", false)
	var is_dot = (runs == 0 and not outcome.get("is_wide", false) and not outcome.get("is_no_ball", false))
	
	# ─── Form Updates ───
	if runs == 4:
		player.form = clampf(player.form + 0.05, 0.0, 1.0)
	elif runs == 6:
		player.form = clampf(player.form + 0.08, 0.0, 1.0)
	elif runs > 0 and runs < 4:
		player.form = clampf(player.form + 0.03, 0.0, 1.0)
	
	if is_dot:
		player.form = clampf(player.form - 0.06, 0.0, 1.0)
	
	# Milestone bonuses
	if player.match_runs >= 25 and player.match_runs - runs < 25:
		player.form = clampf(player.form + 0.06, 0.0, 1.0)
	if player.match_runs >= 50 and player.match_runs - runs < 50:
		player.form = clampf(player.form + 0.06, 0.0, 1.0)
	if player.match_runs >= 100 and player.match_runs - runs < 100:
		player.form = clampf(player.form + 0.06, 0.0, 1.0)
	
	# ─── Fatigue Updates ───
	player.fatigue = clampf(player.fatigue + 0.01, 0.0, 1.0)  # per ball faced
	if runs >= 1 and runs <= 3:
		player.fatigue = clampf(player.fatigue + 0.02, 0.0, 1.0)  # running
	if outcome.get("shot_type", -1) in [Constants.ShotType.AGGRESSIVE_DRIVE, Constants.ShotType.LOFT_SLOG, Constants.ShotType.PULL_SHOT]:
		player.fatigue = clampf(player.fatigue + 0.015, 0.0, 1.0)

func update_bowler(player: PlayerData, outcome: Dictionary, game_state: Dictionary) -> void:
	var runs = outcome.get("runs", 0)
	var is_wicket = outcome.get("is_wicket", false)
	var is_dot = (runs == 0 and not outcome.get("is_wide", false))
	
	# ─── Form Updates ───
	if is_wicket:
		player.form = clampf(player.form + 0.04, 0.0, 1.0)
	if is_dot:
		player.form = clampf(player.form + 0.02, 0.0, 1.0)
	if runs == 4:
		player.form = clampf(player.form - 0.05, 0.0, 1.0)
	if runs == 6:
		player.form = clampf(player.form - 0.08, 0.0, 1.0)
	
	# ─── Fatigue Updates ───
	player.fatigue = clampf(player.fatigue + 0.04, 0.0, 1.0)  # per ball bowled
	if game_state.get("weather", 0) == Constants.WeatherType.SUNNY:
		player.fatigue = clampf(player.fatigue + 0.012, 0.0, 1.0)  # heat penalty

func recover_rest(player: PlayerData, overs_rested: float) -> void:
	player.fatigue = clampf(player.fatigue - 0.03 * overs_rested, 0.0, 1.0)

func apply_drinks_break(team: TeamData) -> void:
	for p in team.playing_xi:
		p.fatigue = clampf(p.fatigue - 0.05, 0.0, 1.0)

func get_form_label(player: PlayerData) -> String:
	if player.form > Constants.HOT_FORM_THRESHOLD:
		return "RED_HOT"
	elif player.form < Constants.COLD_FORM_THRESHOLD:
		return "STRUGGLING"
	else:
		return "NORMAL"
