# TournamentManager.gd — World Cup style tournament: 2 groups of 4, semis, final.
# Pure data + logic (fully headless-testable). The UI scenes read from this.
extends Node

signal tournament_started()
signal fixture_completed(result: Dictionary)   # {home, away, winner, loser, margin_text}
signal stage_changed(stage: String)             # GROUPS -> SEMIS -> FINAL -> DONE
signal champion_crowned(winner: String)

enum Stage { GROUPS, SEMIS, FINAL, DONE }

const TEAMS_PER_GROUP: int = 4
const POINTS_PER_WIN: int = 2

var stage: int = Stage.GROUPS
var human_team_name: String = ""
var groups: Array = []               # [[TeamA, TeamB, ...], [...]]
var fixtures: Array = []             # [{home: String, away: String, done: bool, winner: String}]
var semis: Array = []               # [{home, away, done, winner}, ...]
var final_match: Dictionary = {}    # {home, away, done, winner}
var champion: String = ""

func _ready() -> void:
	pass

# ─── Setup ───
func start_new_tournament(human_team: TeamData) -> void:
	stage = Stage.GROUPS
	human_team_name = human_team.team_name
	groups = []
	fixtures = []
	semis = []
	final_match = {}
	champion = ""
	
	# Seeded random draw of all 8 teams into 2 groups of 4
	var pool: Array = GameManager.all_teams.duplicate()
	pool.shuffle()
	var g1: Array = pool.slice(0, TEAMS_PER_GROUP)
	var g2: Array = pool.slice(TEAMS_PER_GROUP, TEAMS_PER_GROUP * 2)
	groups = [g1, g2]
	
	# Build the per-group round-robin fixtures (each team plays 3 matches)
	for gi in range(groups.size()):
		var g: Array = groups[gi]
		for i in range(g.size()):
			for j in range(i + 1, g.size()):
				fixtures.append({
					"group": gi,
					"home": g[i].team_name,
					"away": g[j].team_name,
					"done": false,
					"winner": "",
				})
	
	# Reset every team's tournament stats
	for t in GameManager.all_teams:
		t.matches_played = 0
		t.matches_won = 0
		t.matches_lost = 0
		t.points = 0
		t.total_runs_scored_tournament = 0
		t.total_overs_faced_tournament = 0.0
		t.total_runs_conceded_tournament = 0
		t.total_overs_bowled_tournament = 0.0
		t.nrr = 0.0
	
	tournament_started.emit()
	stage_changed.emit("GROUPS")
	save()

func is_active() -> bool:
	return stage != Stage.DONE and not groups.is_empty()

# ─── Standings / progression ───
func team_by_name(name: String) -> TeamData:
	for t in GameManager.all_teams:
		if t.team_name == name:
			return t
	return null

func record_result(home: String, away: String, winner: String,
		loser_runs_margin: Dictionary) -> void:
	# Register a completed fixture result into standings + team stats.
	var w = team_by_name(winner)
	var l_team_name = away if winner == home else home
	var l = team_by_name(l_team_name)
	if w == null or l == null:
		return
	w.matches_played += 1
	w.matches_won += 1
	w.points += POINTS_PER_WIN
	l.matches_played += 1
	l.matches_lost += 1
	
	# NRR accumulation: runs for/against and overs faced/bowled
	var rf: int = loser_runs_margin.get("winner_runs", 0)
	var ra: int = loser_runs_margin.get("loser_runs", 0)
	var of_: float = loser_runs_margin.get("winner_overs", 0.0)
	var oa: float = loser_runs_margin.get("loser_overs", 0.0)
	w.total_runs_scored_tournament += rf
	w.total_overs_faced_tournament += of_
	w.total_runs_conceded_tournament += ra
	w.total_overs_bowled_tournament += oa
	l.total_runs_scored_tournament += ra
	l.total_overs_faced_tournament += oa
	l.total_runs_conceded_tournament += rf
	l.total_overs_bowled_tournament += of_
	w.calculate_nrr()
	l.calculate_nrr()
	
	# Mark the fixture done
	for f in fixtures:
		if not f["done"] and f["home"] == home and f["away"] == away:
			f["done"] = true
			f["winner"] = winner
			break
	
	fixture_completed.emit({"home": home, "away": away, "winner": winner})
	save()

func sorted_group(gi: int) -> Array:
	# Returns the group's teams sorted by points, then NRR, then wins.
	var g: Array = groups[gi].duplicate()
	g.sort_custom(func(a, b) -> bool:
		if a.points != b.points:
			return a.points > b.points
		if a.nrr != b.nrr:
			return a.nrr > b.nrr
		return a.matches_won > b.matches_won
	)
	return g

func group_stage_complete() -> bool:
	for f in fixtures:
		if not f["done"]:
			return false
	return true

func advance_stage() -> void:
	if stage == Stage.GROUPS and group_stage_complete():
		var a1 = sorted_group(0)[0]
		var a2 = sorted_group(0)[1]
		var b1 = sorted_group(1)[0]
		var b2 = sorted_group(1)[1]
		semis = [
			{"home": a1.team_name, "away": b2.team_name, "done": false, "winner": ""},
			{"home": b1.team_name, "away": a2.team_name, "done": false, "winner": ""},
		]
		stage = Stage.SEMIS
		stage_changed.emit("SEMI FINALS")
		save()
	elif stage == Stage.SEMIS and semis.is_empty() == false:
		var all_done = true
		for s in semis:
			if not s["done"]:
				all_done = false
		if all_done:
			final_match = {"home": semis[0]["winner"], "away": semis[1]["winner"], "done": false, "winner": ""}
			stage = Stage.FINAL
			stage_changed.emit("FINAL")
			save()
	elif stage == Stage.FINAL and final_match.get("done", false):
		champion = final_match["winner"]
		stage = Stage.DONE
		champion_crowned.emit(champion)
		save()

func record_knockout(kind: String, home: String, away: String, winner: String) -> void:
	# kind: "semi0", "semi1", "final"
	if kind.begins_with("semi"):
		var idx := int(kind.substr(4))
		if idx < semis.size():
			semis[idx]["done"] = true
			semis[idx]["winner"] = winner
		# Knockouts also count as played matches for realism
		var w = team_by_name(winner)
		var loser = away if winner == home else home
		var l = team_by_name(loser)
		if w: w.matches_played += 1; w.matches_won += 1
		if l: l.matches_played += 1; l.matches_lost += 1
	elif kind == "final":
		final_match["done"] = true
		final_match["winner"] = winner
		var w = team_by_name(winner)
		var loser = away if winner == home else home
		var l = team_by_name(loser)
		if w: w.matches_played += 1; w.matches_won += 1
		if l: l.matches_played += 1; l.matches_lost += 1
	save()

# ─── Fixture helpers ───
func next_human_fixture() -> Dictionary:
	# The human's next group fixture (or knockout), or {} if none.
	var h = human_team_name
	for f in fixtures:
		if not f["done"] and (f["home"] == h or f["away"] == h):
			return f
	if stage == Stage.SEMIS:
		for i in range(semis.size()):
			var s = semis[i]
			if not s["done"] and (s["home"] == h or s["away"] == h):
				return {"kind": "semi%d" % i, "home": s["home"], "away": s["away"], "done": false}
	if stage == Stage.FINAL and not final_match.get("done", false):
		if final_match["home"] == h or final_match["away"] == h:
			return {"kind": "final", "home": final_match["home"], "away": final_match["away"], "done": false}
	return {}

func pending_ai_fixtures() -> Array:
	# All unplayed fixtures not involving the human (group stage only).
	var out: Array = []
	var h = human_team_name
	if stage == Stage.GROUPS:
		for f in fixtures:
			if not f["done"] and f["home"] != h and f["away"] != h:
				out.append(f)
	return out

# ─── Persistence ───
func save() -> void:
	SaveManager.save_tournament({
		"stage": stage,
		"human_team_name": human_team_name,
		"groups": groups.map(func(g): return g.map(func(t): return t.team_name)),
		"fixtures": fixtures,
		"semis": semis,
		"final": final_match,
		"champion": champion,
		"teams": GameManager.all_teams.map(func(t): return {
			"name": t.team_name,
			"p": t.matches_played, "w": t.matches_won, "l": t.matches_lost,
			"pts": t.points,
			"rf": t.total_runs_scored_tournament, "of": t.total_overs_faced_tournament,
			"ra": t.total_runs_conceded_tournament, "ob": t.total_overs_bowled_tournament,
			"nrr": t.nrr,
			"xi": t.playing_xi.map(func(p): return p.player_name),
		}),
	})

func load_saved() -> bool:
	if not SaveManager.has_tournament_save():
		return false
	var data: Dictionary = SaveManager.load_tournament()
	if data.is_empty():
		return false
	# Rehydrate names into TeamData references
	var name_to_team := {}
	for t in GameManager.all_teams:
		name_to_team[t.team_name] = t
	groups = []
	for g in data.get("groups", []):
		var rg: Array = []
		for n in g:
			if name_to_team.has(n):
				rg.append(name_to_team[n])
		groups.append(rg)
	fixtures = data.get("fixtures", [])
	semis = data.get("semis", [])
	final_match = data.get("final", {})
	champion = data.get("champion", "")
	stage = int(data.get("stage", Stage.GROUPS))
	human_team_name = data.get("human_team_name", "")
	for ts in data.get("teams", []):
		var t = name_to_team.get(ts.get("name", ""), null)
		if t:
			t.matches_played = int(ts.get("p", 0))
			t.matches_won = int(ts.get("w", 0))
			t.matches_lost = int(ts.get("l", 0))
			t.points = int(ts.get("pts", 0))
			t.total_runs_scored_tournament = int(ts.get("rf", 0))
			t.total_overs_faced_tournament = float(ts.get("of", 0.0))
			t.total_runs_conceded_tournament = int(ts.get("ra", 0))
			t.total_overs_bowled_tournament = float(ts.get("ob", 0.0))
			t.nrr = float(ts.get("nrr", 0.0))
			# Rehydrate the custom XI (falls back to default XI on bad data)
			var by_name := {}
			for p in t.squad:
				by_name[p.player_name] = p
			var xi_names: Array = ts.get("xi", [])
			var xi: Array[PlayerData] = []
			for n in xi_names:
				if by_name.has(n):
					var pd := by_name[n] as PlayerData
					if pd != null:
						xi.append(pd)
			if xi.size() == 11:
				t.set_playing_xi(xi)
	return is_active() or stage == Stage.DONE

func has_save() -> bool:
	return SaveManager.has_tournament_save()

func abandon() -> void:
	stage = Stage.DONE
	groups = []
	fixtures = []
	semis = []
	final_match = {}
	SaveManager.delete_tournament_save()

# Stage label for UI
func stage_label() -> String:
	match stage:
		Stage.GROUPS: return "GROUP STAGE"
		Stage.SEMIS: return "SEMI FINALS"
		Stage.FINAL: return "FINAL"
		Stage.DONE: return "COMPLETE"
	return ""

# Parses cricket over notation ("18.3" = 18 overs + 3 balls) into float overs.
static func overs_to_float(over_string: String) -> float:
	var parts = over_string.split(".")
	if parts.size() == 2:
		return float(parts[0]) + float(parts[1]) / 6.0
	return 0.0

# Builds the {winner_runs, winner_overs, loser_runs, loser_overs} payload for
# record_result from the WINNER's and LOSER's innings scorecards.
# All-out sides count the full quota faced (standard NRR rule).
static func nrr_payload(winner_sc: Dictionary, loser_sc: Dictionary) -> Dictionary:
	var w_overs := overs_to_float(winner_sc.get("total_overs", "0.0"))
	var l_overs := overs_to_float(loser_sc.get("total_overs", "0.0"))
	if int(winner_sc.get("total_wickets", 0)) >= 10 and w_overs < 20.0:
		w_overs = 20.0
	if int(loser_sc.get("total_wickets", 0)) >= 10 and l_overs < 20.0:
		l_overs = 20.0
	return {
		"winner_runs": int(winner_sc.get("total_runs", 0)),
		"winner_overs": w_overs,
		"loser_runs": int(loser_sc.get("total_runs", 0)),
		"loser_overs": l_overs,
	}

# Picks the correct innings scorecards for NRR recording from a finished-match
# scorecard: for super-over games, the MAIN-match innings (shootout runs never
# count toward Net Run Rate). Returns [winner_sc, loser_sc].
static func nrr_innings(sc: Dictionary, first_sc: Dictionary, winner: String) -> Array:
	if sc.get("super_over", false):
		var mains: Array = sc.get("main_innings", [])
		if mains.size() >= 2:
			var wsc = mains[0] if winner == mains[0].get("team_name", "") else mains[1]
			var lsc = mains[1] if winner == mains[0].get("team_name", "") else mains[0]
			return [wsc, lsc]
	return [sc, first_sc] if winner == sc.get("team_name", "") else [first_sc, sc]
