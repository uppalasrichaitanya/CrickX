# GameManager.gd — Global game state singleton (Autoload).
# Single source of truth for the current match state, teams, and signals.
extends Node

# ═══════════════════════════════════════
# SIGNALS — Decoupled event system
# ═══════════════════════════════════════
signal ball_bowled(outcome: Dictionary)
signal wicket_fallen(player: PlayerData, wicket_type: String)
signal boundary_hit(runs: int)
signal over_completed(over_number: int, runs_this_over: int, wickets_this_over: int)
signal innings_ended(scorecard: Dictionary)
signal match_ended(winner: String, scorecard: Dictionary)
signal drs_initiated(team_name: String, decision_type: String)
signal milestone_reached(player: PlayerData, milestone: String)
signal momentum_shifted(favoring_team: String, amount: float)

# ═══════════════════════════════════════
# MATCH STATE — The single source of truth
# ═══════════════════════════════════════
var state: Dictionary = {}
var all_teams: Array[TeamData] = []
var batting_team: TeamData = null
var bowling_team: TeamData = null

# ─── Innings tracking ───
var striker: PlayerData = null
var non_striker: PlayerData = null
var current_bowler: PlayerData = null
var batting_order_index: int = 0  # Next batsman to come in
var fall_of_wickets: Array[Dictionary] = []  # [{ "score": 23, "over": "3.2", "batsman": "name" }]
var this_over_balls: Array[Dictionary] = []  # Current over ball-by-ball
var all_overs: Array[Array] = []  # History of all overs
var extras: Dictionary = { "wides": 0, "no_balls": 0, "byes": 0, "leg_byes": 0 }

# ─── Second innings tracking ───
var first_innings_scorecard: Dictionary = {}

# ─── Settings ───
var difficulty: int = Constants.Difficulty.MEDIUM
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var is_fullscreen: bool = false

# ─── Deep Logic State ───
var weather: int = Constants.WeatherType.SUNNY
var pitch_type: int = Constants.PitchType.FLAT
var pitch_wear: float = 0.0
var batting_pressure: float = 0.0
var momentum: float = 0.0  # -1.0 to 1.0 (negative = bowling team, positive = batting team)

# ─── DRS ───
var drs_reviews_batting: int = 2
var drs_reviews_bowling: int = 2

func _ready() -> void:
	all_teams = TeamDatabase.create_all_teams()
	_load_settings()

# ═══════════════════════════════════════
# MATCH INITIALIZATION
# ═══════════════════════════════════════
func start_new_match(team_a: TeamData, team_b: TeamData, format: int) -> void:
	batting_team = team_a
	bowling_team = team_b
	batting_team.reset_match_stats()
	bowling_team.reset_match_stats()
	
	var max_overs = Constants.MAX_OVERS_T20 if format == Constants.MatchFormat.T20 else Constants.MAX_OVERS_ODI
	
	state = {
		"batting_team_name": batting_team.team_name,
		"bowling_team_name": bowling_team.team_name,
		"current_over": 0,
		"current_ball": 0,
		"total_runs": 0,
		"total_wickets": 0,
		"target": 0,
		"max_overs": max_overs,
		"format": format,
		"phase": Constants.MatchPhase.POWERPLAY,
		"is_first_innings": true,
		"pitch_type": pitch_type,
		"weather": weather,
	}
	
	# DRS reviews
	if format == Constants.MatchFormat.T20:
		drs_reviews_batting = Constants.DRS_REVIEWS_T20
		drs_reviews_bowling = Constants.DRS_REVIEWS_T20
	else:
		drs_reviews_batting = Constants.DRS_REVIEWS_ODI
		drs_reviews_bowling = Constants.DRS_REVIEWS_ODI
	
	# Initialize batting
	batting_order_index = 2
	striker = batting_team.playing_xi[0]
	non_striker = batting_team.playing_xi[1]
	striker.is_on_strike = true
	
	# Pick opening bowler
	var bowlers = bowling_team.get_bowlers()
	if bowlers.size() > 0:
		current_bowler = bowlers[0]
	
	# Reset tracking
	fall_of_wickets = []
	this_over_balls = []
	all_overs = []
	extras = { "wides": 0, "no_balls": 0, "byes": 0, "leg_byes": 0 }
	first_innings_scorecard = {}
	pitch_wear = 0.0
	batting_pressure = 0.0
	momentum = 0.0
	
	# Randomize weather and pitch
	weather = randi_range(0, 4)
	pitch_type = randi_range(0, 4)
	state["weather"] = weather
	state["pitch_type"] = pitch_type

func get_current_over_string() -> String:
	return str(state["current_over"]) + "." + str(state["current_ball"])

func get_required_run_rate() -> float:
	if state["is_first_innings"] or state["target"] == 0:
		return 0.0
	var runs_needed = state["target"] - state["total_runs"]
	var balls_remaining = (state["max_overs"] * 6) - (state["current_over"] * 6 + state["current_ball"])
	if balls_remaining <= 0:
		return 999.0
	return (float(runs_needed) / float(balls_remaining)) * 6.0

func get_current_run_rate() -> float:
	var total_balls = state["current_over"] * 6 + state["current_ball"]
	if total_balls == 0:
		return 0.0
	return (float(state["total_runs"]) / float(total_balls)) * 6.0

func get_partnership_runs() -> int:
	if striker == null or non_striker == null:
		return 0
	# Simple approximation — sum of both current batsmen runs since last wicket
	return striker.match_runs + non_striker.match_runs

func update_phase() -> void:
	var overs = state["current_over"]
	if state["format"] == Constants.MatchFormat.T20:
		if overs < 6:
			state["phase"] = Constants.MatchPhase.POWERPLAY
		elif overs < 16:
			state["phase"] = Constants.MatchPhase.MIDDLE
		else:
			state["phase"] = Constants.MatchPhase.DEATH
	else:
		if overs < 10:
			state["phase"] = Constants.MatchPhase.POWERPLAY
		elif overs < 40:
			state["phase"] = Constants.MatchPhase.MIDDLE
		else:
			state["phase"] = Constants.MatchPhase.DEATH

func rotate_strike() -> void:
	if striker and non_striker:
		striker.is_on_strike = false
		non_striker.is_on_strike = true
		var temp = striker
		striker = non_striker
		non_striker = temp

func next_batsman() -> PlayerData:
	if batting_order_index >= batting_team.playing_xi.size():
		return null
	var next = batting_team.playing_xi[batting_order_index]
	batting_order_index += 1
	return next

func swap_innings() -> void:
	# Store first innings scorecard
	first_innings_scorecard = _build_scorecard()
	
	# Set target
	state["target"] = state["total_runs"] + 1
	
	# Swap teams
	var temp_team = batting_team
	batting_team = bowling_team
	bowling_team = temp_team
	
	batting_team.reset_match_stats()
	
	# Reset state for second innings
	state["batting_team_name"] = batting_team.team_name
	state["bowling_team_name"] = bowling_team.team_name
	state["current_over"] = 0
	state["current_ball"] = 0
	state["total_runs"] = 0
	state["total_wickets"] = 0
	state["is_first_innings"] = false
	state["phase"] = Constants.MatchPhase.POWERPLAY
	
	# DRS reset
	if state["format"] == Constants.MatchFormat.T20:
		drs_reviews_batting = Constants.DRS_REVIEWS_T20
		drs_reviews_bowling = Constants.DRS_REVIEWS_T20
	else:
		drs_reviews_batting = Constants.DRS_REVIEWS_ODI
		drs_reviews_bowling = Constants.DRS_REVIEWS_ODI
	
	batting_order_index = 2
	striker = batting_team.playing_xi[0]
	non_striker = batting_team.playing_xi[1]
	striker.is_on_strike = true
	
	var bowlers = bowling_team.get_bowlers()
	if bowlers.size() > 0:
		current_bowler = bowlers[0]
	
	fall_of_wickets = []
	this_over_balls = []
	all_overs = []
	extras = { "wides": 0, "no_balls": 0, "byes": 0, "leg_byes": 0 }
	pitch_wear = 0.0
	batting_pressure = 0.0

func _build_scorecard() -> Dictionary:
	return {
		"team_name": batting_team.team_name,
		"total_runs": state["total_runs"],
		"total_wickets": state["total_wickets"],
		"total_overs": get_current_over_string(),
		"extras": extras.duplicate(),
		"batsmen": _get_batsmen_stats(),
		"bowlers": _get_bowler_stats(),
		"fall_of_wickets": fall_of_wickets.duplicate(),
	}

func _get_batsmen_stats() -> Array:
	var stats = []
	for p in batting_team.playing_xi:
		stats.append({
			"name": p.player_name,
			"runs": p.match_runs,
			"balls": p.match_balls,
			"fours": p.match_fours,
			"sixes": p.match_sixes,
			"sr": p.get_strike_rate(),
			"dismissal": p.dismissal_text,
			"is_out": p.is_out,
		})
	return stats

func _get_bowler_stats() -> Array:
	var stats = []
	for p in bowling_team.playing_xi:
		if p.match_overs_bowled > 0:
			stats.append({
				"name": p.player_name,
				"overs": p.match_overs_bowled,
				"maidens": p.match_maidens,
				"runs": p.match_runs_conceded,
				"wickets": p.match_wickets,
				"economy": p.get_economy(),
			})
	return stats

# ═══════════════════════════════════════
# SETTINGS PERSISTENCE
# ═══════════════════════════════════════
func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		difficulty = config.get_value("game", "difficulty", Constants.Difficulty.MEDIUM)
		master_volume = config.get_value("audio", "master_volume", 1.0)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
		is_fullscreen = config.get_value("display", "fullscreen", false)
		if is_fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("game", "difficulty", difficulty)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "fullscreen", is_fullscreen)
	config.save("user://settings.cfg")
