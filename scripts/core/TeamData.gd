# TeamData.gd — Resource representing a cricket team.
# Holds squad, playing XI, and team-level metadata.
extends Resource
class_name TeamData

@export var team_name: String = ""
@export var country_code: String = ""   # For flag display (e.g., "IND", "AUS")
@export var team_color: Color = Color.WHITE
@export var squad: Array[PlayerData] = []
@export var playing_xi: Array[PlayerData] = []

# ─── Tournament Stats (persistent across matches) ───
var matches_played: int = 0
var matches_won: int = 0
var matches_lost: int = 0
var points: int = 0
var nrr: float = 0.0  # Net Run Rate
var total_runs_scored_tournament: int = 0
var total_overs_faced_tournament: float = 0.0
var total_runs_conceded_tournament: int = 0
var total_overs_bowled_tournament: float = 0.0

func get_batting_order() -> Array[PlayerData]:
	return playing_xi

func get_bowlers() -> Array[PlayerData]:
	var bowlers: Array[PlayerData] = []
	for p in playing_xi:
		if p.bowling_type != "NONE":
			bowlers.append(p)
	return bowlers

func reset_match_stats() -> void:
	for p in playing_xi:
		p.reset_match_stats()

func calculate_nrr() -> void:
	if total_overs_faced_tournament > 0 and total_overs_bowled_tournament > 0:
		var scoring_rate = float(total_runs_scored_tournament) / total_overs_faced_tournament
		var conceding_rate = float(total_runs_conceded_tournament) / total_overs_bowled_tournament
		nrr = scoring_rate - conceding_rate
	else:
		nrr = 0.0
