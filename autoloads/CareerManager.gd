# CareerManager.gd — Persistent per-player career aggregates across all matches.
# Recorded at every match end (quick, tournament, hot-seat). Super-over
# shootouts are skipped (1-over figures would pollute career rates).
extends Node

signal career_updated()

var players: Dictionary = {}  # {player_name: {team, matches, runs, ...}}

func _ready() -> void:
	load_career()

func _blank() -> Dictionary:
	return {
		"team": "", "matches": 0,
		"runs": 0, "balls": 0, "fours": 0, "sixes": 0,
		"fifties": 0, "hundreds": 0, "ducks": 0,
		"wickets": 0, "catches": 0,
		"best_runs": 0, "best_wkts": 0, "best_bowl_runs": 0,
	}

func _entry_for(p: PlayerData, team_name: String) -> Dictionary:
	if not players.has(p.player_name):
		var b := _blank()
		b["team"] = team_name
		players[p.player_name] = b
	return players[p.player_name]

# Called by MatchEngine at every match end with both sides' live PlayerData.
func record_match() -> void:
	if GameManager.state.get("super_over", false):
		return  # Shootout figures stay out of career records
	for side in [GameManager.batting_team, GameManager.bowling_team]:
		if side == null:
			continue
		for p in side.playing_xi:
			var e: Dictionary = _entry_for(p, side.team_name)
			e["team"] = side.team_name
			e["matches"] = int(e["matches"]) + 1
			e["runs"] = int(e["runs"]) + p.match_runs
			e["balls"] = int(e["balls"]) + p.match_balls
			e["fours"] = int(e["fours"]) + p.match_fours
			e["sixes"] = int(e["sixes"]) + p.match_sixes
			if p.match_runs >= 100:
				e["hundreds"] = int(e["hundreds"]) + 1
			elif p.match_runs >= 50:
				e["fifties"] = int(e["fifties"]) + 1
			if p.is_out and p.match_runs == 0 and p.match_balls > 0:
				e["ducks"] = int(e["ducks"]) + 1
			e["wickets"] = int(e["wickets"]) + p.match_wickets
			e["catches"] = int(e["catches"]) + p.match_catches
			if p.match_runs > int(e["best_runs"]):
				e["best_runs"] = p.match_runs
			if p.match_wickets > int(e["best_wkts"]) or \
					(p.match_wickets == int(e["best_wkts"]) and p.match_runs_conceded < int(e["best_bowl_runs"])):
				e["best_wkts"] = p.match_wickets
				e["best_bowl_runs"] = p.match_runs_conceded
	save()
	career_updated.emit()

func batting_average(e: Dictionary) -> float:
	var inns := int(e.get("matches", 0))
	if inns <= 0:
		return 0.0
	return float(e.get("runs", 0)) / float(inns)

func strike_rate(e: Dictionary) -> float:
	var balls := int(e.get("balls", 0))
	if balls <= 0:
		return 0.0
	return float(e.get("runs", 0)) / float(balls) * 100.0

# Sorted tables for the Records screen (min 1 match played).
func batting_table(limit: int = 25) -> Array:
	var rows := []
	for name in players:
		var e: Dictionary = players[name]
		if int(e.get("matches", 0)) > 0 and int(e.get("balls", 0)) > 0:
			rows.append({"name": name, "data": e})
	rows.sort_custom(func(a, b): return int(a["data"]["runs"]) > int(b["data"]["runs"]))
	return rows.slice(0, mini(limit, rows.size()))

func bowling_table(limit: int = 25) -> Array:
	var rows := []
	for name in players:
		var e: Dictionary = players[name]
		if int(e.get("matches", 0)) > 0 and (int(e.get("wickets", 0)) > 0):
			rows.append({"name": name, "data": e})
	rows.sort_custom(func(a, b): return int(a["data"]["wickets"]) > int(b["data"]["wickets"]))
	return rows.slice(0, mini(limit, rows.size()))

func total_players() -> int:
	return players.size()

func save() -> void:
	SaveManager.save_career({"players": players})

func load_career() -> void:
	var data: Dictionary = SaveManager.load_career()
	# Merge onto blanks so older saves gain any new fields safely.
	players = {}
	for name in data.get("players", {}):
		var b := _blank()
		var saved: Dictionary = data["players"][name]
		for k in saved:
			b[k] = saved[k]
		players[name] = b

func has_save() -> bool:
	return players.size() > 0

func reset() -> void:
	players = {}
	SaveManager.save_career({"players": {}})
	career_updated.emit()
