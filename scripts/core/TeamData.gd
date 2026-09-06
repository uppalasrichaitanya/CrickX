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

# Sets a custom playing XI (e.g., from the squad picker). Returns the list of
# problems found; empty means valid. Order = batting order.
func set_playing_xi(players: Array[PlayerData]) -> Array[String]:
	var problems := validate_xi(players)
	if problems.is_empty():
		playing_xi = players.duplicate()
		reset_match_stats()
	return problems

# XI rules: exactly 11, unique squad members, at least one bowler.
static func validate_xi(players: Array[PlayerData]) -> Array[String]:
	var problems: Array[String] = []
	if players.size() != 11:
		problems.append("XI must have exactly 11 players (got %d)" % players.size())
	var seen := {}
	for p in players:
		if p in seen:
			problems.append("Duplicate player: %s" % p.player_name)
		seen[p] = true
	var has_bowler := false
	for p in players:
		if p.bowling_type != "NONE":
			has_bowler = true
			break
	if not has_bowler:
		problems.append("XI needs at least one bowler")
	return problems

# Repairs a broken XI by filling gaps from the squad: tops up to 11 in squad
# order, then guarantees a bowler by swapping the last non-bowler if needed.
func auto_repair_xi(players: Array[PlayerData]) -> Array[PlayerData]:
	var fixed: Array[PlayerData] = []
	var seen := {}
	for p in players:
		if p in squad and not (p in seen):
			fixed.append(p)
			seen[p] = true
	for p in squad:
		if fixed.size() >= 11:
			break
		if not (p in seen):
			fixed.append(p)
			seen[p] = true
	if fixed.size() > 11:
		fixed = fixed.slice(0, 11)
	var has_bowler := false
	for p in fixed:
		if p.bowling_type != "NONE":
			has_bowler = true
			break
	if not has_bowler:
		for p in squad:
			if p.bowling_type != "NONE" and p in fixed:
				continue
			if p.bowling_type != "NONE":
				fixed[fixed.size() - 1] = p
				break
	return fixed

func reset_match_stats() -> void:
	# Reset the FULL squad (not just the XI) so benched players never carry
	# stale per-match stats back into a later XI.
	for p in squad:
		p.reset_match_stats()

func calculate_nrr() -> void:
	if total_overs_faced_tournament > 0 and total_overs_bowled_tournament > 0:
		var scoring_rate = float(total_runs_scored_tournament) / total_overs_faced_tournament
		var conceding_rate = float(total_runs_conceded_tournament) / total_overs_bowled_tournament
		nrr = scoring_rate - conceding_rate
	else:
		nrr = 0.0
