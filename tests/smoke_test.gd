extends SceneTree
# Headless smoke test: plays AI-vs-AI matches through MatchEngine and checks invariants.
# Run: Godot_v4.2.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_test.gd
# Exit code 0 = all checks passed, 1 = failure.
# NOTE: autoload identifiers aren't resolved at compile time in -s mode, so we look them up at runtime.

var _engine: Node = null
var _gm: Node = null
var _const: Node = null

var _failures: Array[String] = []
var _results: Array[String] = []

# Match plan: [label, format, max_overs, fast_forward, human_team_offset, human_bowls, hotseat]
# human_team_offset: -1 = pure AI match; 0/1 = teams[i]/teams[i+1] is human.
var _matches: Array = [
	["T20-A", 0, 3, false, -1, false, false],
	["T20-B", 0, 3, false, -1, false, false],
	["T20-C", 0, 3, false, -1, false, false],
	["ODI-A", 1, 5, false, -1, false, false],
	["T20-FF", 0, 3, true, -1, false, false],
	["FULL-A", 0, 2, false, 0, true, false],
	["TOSS-H1", 0, 2, false, 1, true, false],
	["TOSS-H2", 0, 2, false, 0, false, false],
	["HOTSEAT", 0, 2, false, -1, false, true],
]
var _match_index: int = 0
var _running: bool = false

var _wide_count: int = 0
var _wicket_count: int = 0
var _no_ball_count: int = 0
var _reviewable_wickets: int = 0
var _drop_count: int = 0
var _hat_trick_count: int = 0
var _cur_format: int = 0
var _cur_full: bool = false
var _cur_hotseat: bool = false
var _shot_requests: int = 0
var _bowl_requests: int = 0
var _drs_requests: int = 0
var _shots_inn1: int = 0
var _bowls_inn1: int = 0

func _initialize() -> void:
	_engine = root.get_node("MatchEngine")
	_gm = root.get_node("GameManager")
	_const = root.get_node("Constants")
	_engine.match_ended_signal.connect(_on_match_ended)
	_engine.ball_result_ready.connect(_on_ball_result)
	# Auto-respond to the human-input requests so full matches run headless.
	_engine.request_shot_selection.connect(_on_request_shot)
	_engine.request_bowl_selection.connect(_on_request_bowl)
	_engine.request_drs_review.connect(_on_request_drs)
	_test_drs_directly()
	_test_career()
	process_frame.connect(_on_frame)

func _on_request_shot(_name: String) -> void:
	_shot_requests += 1
	if _gm.state.get("is_first_innings", true):
		_shots_inn1 += 1
	_engine.receive_shot_input(randi_range(0, 5))

func _on_request_bowl() -> void:
	_bowl_requests += 1
	if _gm.state.get("is_first_innings", true):
		_bowls_inn1 += 1
	# Index 0 is always a valid delivery for any bowler type.
	_engine.receive_bowl_input(0)

func _on_request_drs(_wtype: String, _left: int) -> void:
	_drs_requests += 1
	_engine.receive_drs_input(randi_range(0, 1) == 0)

func _on_frame() -> void:
	if _tournament_phase:
		if _tour_advance:
			_tour_advance = false
			_play_next_tour_fixture(root.get_node("TournamentManager"))
		return
	if _direct_test_active:
		_drive_direct_test()
		return
	if not _running and _match_index < _matches.size():
		_start_match(_matches[_match_index])

func _start_match(spec: Array) -> void:
	_running = true
	_wide_count = 0
	_wicket_count = 0
	_no_ball_count = 0
	_reviewable_wickets = 0
	_drop_count = 0
	_hat_trick_count = 0
	_shot_requests = 0
	_bowl_requests = 0
	_drs_requests = 0
	_shots_inn1 = 0
	_bowls_inn1 = 0
	var label: String = spec[0]
	var format: int = spec[1]
	var max_overs: int = spec[2]
	var ff: bool = spec[3]
	var human_off: int = spec[4]
	var human_bowls: bool = spec[5]
	var hotseat: bool = spec[6] if spec.size() > 6 else false
	_cur_format = format
	_cur_full = human_off >= 0 or hotseat
	_cur_hotseat = hotseat
	_engine.fast_forward = ff
	var teams = _gm.all_teams
	var team_a = teams[_match_index % teams.size()]
	var team_b = teams[(_match_index + 1) % teams.size()]
	var human_team = null
	if human_off == 0:
		human_team = team_a
	elif human_off == 1:
		human_team = team_b
	_engine.start_match(team_a, team_b, format, human_team, human_bowls, hotseat)
	_gm.state["max_overs"] = max_overs
	# Simulate a HUD that connects one frame late — exercises the pending-start handshake.
	await process_frame
	_engine.note_hud_ready()

func _on_ball_result(outcome: Dictionary) -> void:
	if outcome.get("is_wide", false):
		_wide_count += 1
	if outcome.get("is_no_ball", false):
		_no_ball_count += 1
	if outcome.get("commentary_key", "") == "DROPPED_CATCH":
		_drop_count += 1
	if outcome.get("hat_trick_completed", false):
		_hat_trick_count += 1
	if outcome.get("is_wicket", false):
		_wicket_count += 1
		var wt = outcome.get("wicket_type", "")
		if wt in ["LBW", "CAUGHT", "CAUGHT_BEHIND"]:
			_reviewable_wickets += 1

func _on_match_ended(winner: String) -> void:
	if _direct_test_active:
		_direct_endings.append(winner)
		return
	if _tournament_phase:
		return  # Tournament matches are handled by _on_tour_match_ended
	_running = false
	_match_index += 1
	var spec: Array = _matches[_match_index - 1]
	var label: String = spec[0]
	var max_overs: int = spec[2]
	var sc = _gm._build_scorecard()
	var first = _gm.first_innings_scorecard

	# 1. Winner announced
	if winner == "":
		_failures.append("%s: empty winner" % label)

	# 2. Scorecard sanity
	if first.is_empty():
		_failures.append("%s: first innings scorecard missing" % label)
	if sc.get("total_wickets", -1) > _const.MAX_WICKETS:
		_failures.append("%s: more than %d wickets" % [label, _const.MAX_WICKETS])

	# 3. Runs accounting: batters + penalties = team total (exact now that
	#    no-ball runs are never credited to the striker)
	var bat_runs = 0
	for b in sc.get("batsmen", []):
		bat_runs += b.get("runs", 0)
	var extras = 0
	for k in ["wides", "no_balls", "byes", "leg_byes"]:
		extras += sc.get("extras", {}).get(k, 0)
	var total = sc.get("total_runs", 0)
	if bat_runs + extras != total:
		_failures.append("%s: runs accounting off (bat %d + extras %d vs total %d)" % [label, bat_runs, extras, total])

	# 3b. Bowler figures: every run must be charged to some bowler (exact)
	var bowl_conceded = 0
	for b in sc.get("bowlers", []):
		bowl_conceded += b.get("runs", 0)
	if bowl_conceded != total:
		_failures.append("%s: bowlers conceded %d vs team total %d — figures broken" % [label, bowl_conceded, total])

	# 4. Bowler over limits (format-aware)
	var cap = float(_const.MAX_BOWLER_OVERS_T20) if _cur_format == _const.MatchFormat.T20 else float(_const.MAX_BOWLER_OVERS_ODI)
	for b in sc.get("bowlers", []):
		if b.get("overs", 0.0) > cap:
			_failures.append("%s: bowler %s bowled %s overs (cap %d)" % [label, b.get("name"), str(b.get("overs")), int(cap)])

	# 5. Wide rate sanity (was ~43% per ball before the fix)
	if _wide_count > max_overs * 6:
		_failures.append("%s: %d wides in %d legal balls — wide rate still broken" % [label, _wide_count, max_overs * 6])

	# 6. Target logic: winner must be consistent with the scores.
	#    Super-over games skip the strict check (the shootout decides).
	if first.size() > 0 and not sc.get("super_over", false):
		var target = first.get("total_runs", 0) + 1
		var chased = sc.get("total_runs", 0)
		var expected = sc.get("team_name", "") if chased >= target else first.get("team_name", "")
		if winner != expected:
			_failures.append("%s: winner %s inconsistent (chased %d vs target %d)" % [label, winner, chased, target])
	if sc.get("super_over", false):
		var mains: Array = sc.get("main_innings", [])
		if mains.size() != 2:
			_failures.append("%s: super-over scorecard missing main innings" % label)

	# 7. DRS: reviews must stay within the format's bounds
	var reviews_now = _gm.drs_reviews_batting
	var max_reviews = int(_gm.get_max_reviews())
	if reviews_now < 0 or reviews_now > max_reviews:
		_failures.append("%s: DRS reviews out of bounds (now %d, max %d)" % [label, reviews_now, max_reviews])

	# 8. Human-role specs: verify the derived roles match the human's team
	#    (which innings saw shot vs bowl requests).
	if _cur_hotseat:
		# Both sides human: shots AND bowls in BOTH innings.
		if _shots_inn1 < 3:
			_failures.append("%s: expected >=3 shots in 1st innings, got %d" % [label, _shots_inn1])
		if _bowls_inn1 < 3:
			_failures.append("%s: expected >=3 bowls in 1st innings, got %d" % [label, _bowls_inn1])
		if _shot_requests - _shots_inn1 < 3:
			_failures.append("%s: expected >=3 shots in 2nd innings, got %d" % [label, _shot_requests - _shots_inn1])
		if _bowl_requests - _bowls_inn1 < 3:
			_failures.append("%s: expected >=3 bowls in 2nd innings, got %d" % [label, _bowl_requests - _bowls_inn1])
	elif _cur_full:
		var label8 := label
		if label8 == "FULL-A":
			# Human = team A: shots in the 1st innings, bowls in the 2nd
			if _shots_inn1 < 3:
				_failures.append("%s: expected >=3 shots in 1st innings, got %d" % [label8, _shots_inn1])
			if _bowls_inn1 != 0:
				_failures.append("%s: bowl requests in 1st innings but human bats first" % label8)
			if _bowl_requests - _bowls_inn1 < 3:
				_failures.append("%s: expected >=3 bowls in 2nd innings, got %d" % [label8, _bowl_requests - _bowls_inn1])
		elif label8 == "TOSS-H1":
			# Human = team B: bowls in the 1st innings, bats in the 2nd
			if _bowls_inn1 < 3:
				_failures.append("%s: expected >=3 bowls in 1st innings, got %d" % [label8, _bowls_inn1])
			if _shots_inn1 != 0:
				_failures.append("%s: shot requests in 1st innings but human bats second" % label8)
			if _shot_requests - _shots_inn1 < 3:
				_failures.append("%s: expected >=3 shots in 2nd innings, got %d" % [label8, _shot_requests - _shots_inn1])
		elif label8 == "TOSS-H2":
			# Human = team A, no bowling: shots in the 1st innings only
			if _shots_inn1 < 3:
				_failures.append("%s: expected >=3 shots in 1st innings, got %d" % [label8, _shots_inn1])
			if _bowl_requests != 0:
				_failures.append("%s: bowl requests but human plays no bowling (%d)" % [label8, _bowl_requests])

	_engine.fast_forward = false

	_results.append(
		"%-7s: %s won%s | 2nd inn %s/%d in %s ov | 1st inn %s/%d | wides %d, wickets %d, drops %d, reviews used %d%s" % [
			label, winner, " [SO]" if sc.get("super_over", false) else "",
			str(sc.get("total_runs")), sc.get("total_wickets"), str(sc.get("total_overs")),
			str(first.get("total_runs")), first.get("total_wickets"),
			_wide_count, _wicket_count, _drop_count, max_reviews - reviews_now,
			(" | shots %d, bowls %d, drs %d" % [_shot_requests, _bowl_requests, _drs_requests]) if _cur_full else ""
		]
	)

	if _match_index >= _matches.size() and not _tournament_phase and not _direct_test_active:
		_run_super_over_direct_test()

# ─── Super-over direct mechanics test (synthetic tie, no RNG dependence) ───
var _direct_test_active: bool = false
var _direct_stage: int = -1
var _direct_endings: Array = []

func _run_super_over_direct_test() -> void:
	_direct_test_active = true
	_direct_stage = 0
	_direct_endings = []
	_engine.fast_forward = true
	_engine.human_side = null

# Driven from _on_frame; each stage runs once, engine flow continues async.
# NOTE: after kicking the tie, setup assertions run on the NEXT frame —
# observing engine state across a frame boundary is the only reliable way
# to read it (the shootout's first mini-innings keeps round/maxw/sides
# stable until it completes).
func _drive_direct_test() -> void:
	var gm = root.get_node("GameManager")
	if _direct_stage == 0:
		# Build a tied main match: A 49/5 in 20, B 49/5 in 20 (target 50).
		var A = gm.all_teams[0]
		var B = gm.all_teams[1]
		gm.start_new_match(A, B, 0)
		gm.state["total_runs"] = 49
		gm.state["total_wickets"] = 5
		gm.state["current_over"] = 20
		gm.swap_innings()  # target = 50
		gm.state["total_runs"] = 49
		gm.state["total_wickets"] = 5
		gm.state["current_over"] = 20
		gm.state["current_ball"] = 0
		_engine._end_innings()  # tie branch -> super-over round 1
		_direct_stage = 1
	elif _direct_stage == 1:
		# The shootout's first mini-innings is now live: setup must read
		# round 1, 1-over/2-wicket caps, DEATH phase, snapshots, chaser batting.
		if gm.state.get("super_over", false) != true:
			_failures.append("SO: super_over flag not set after tie")
			_direct_stage = 99
			return
		if int(gm.state.get("super_over_round", 0)) != 1:
			_failures.append("SO: expected round 1, got %s" % str(gm.state.get("super_over_round")))
			_direct_stage = 99
			return
		if int(gm.state.get("max_overs", 0)) != 1:
			_failures.append("SO: max_overs not 1 (got %s)" % str(gm.state.get("max_overs")))
		if int(gm.state.get("max_wickets", 0)) != 2:
			_failures.append("SO: max_wickets not 2 (got %s)" % str(gm.state.get("max_wickets")))
		if gm.state.get("phase", -1) != _const.MatchPhase.DEATH:
			_failures.append("SO: phase not DEATH")
		# Shootout reviews start at 1/1 but may already be consumed mid-shootout;
		# they must never go negative or exceed the allocation.
		if int(gm.drs_reviews_batting) < 0 or int(gm.drs_reviews_batting) > 1 \
				or int(gm.drs_reviews_bowling) < 0 or int(gm.drs_reviews_bowling) > 1:
			_failures.append("SO: DRS reviews out of shootout bounds")
		var mains: Array = gm.super_over_scorecards
		if mains.size() != 2:
			_failures.append("SO: expected 2 snapshotted main innings, got %d" % mains.size())
		else:
			if mains[0].get("team_name", "") != gm.all_teams[0].team_name or int(mains[0].get("total_runs", -1)) != 49:
				_failures.append("SO: main innings snapshot 1 wrong: %s" % [mains[0]])
			if mains[1].get("team_name", "") != gm.all_teams[1].team_name or int(mains[1].get("total_runs", -1)) != 49:
				_failures.append("SO: main innings snapshot 2 wrong: %s" % [mains[1]])
		if gm.state.get("so_first_batting", "") != gm.all_teams[1].team_name and int(gm.state.get("super_over_round", 0)) == 1:
			# Round 1: the main-match chaser (B) must bat first in the shootout.
			_failures.append("SO: chaser (B) should bat first in the shootout")
		_direct_stage = 2
	elif _direct_stage == 2:
		# Wait for the (real, 1-over) super-over match to complete.
		if _direct_endings.is_empty():
			return
		var gm2 = root.get_node("GameManager")
		var sc = gm2._build_scorecard()
		var winner: String = _direct_endings[_direct_endings.size() - 1]
		if winner != gm2.all_teams[0].team_name and winner != gm2.all_teams[1].team_name:
			_failures.append("SO: winner %s not one of the two sides" % winner)
		if sc.get("super_over", false) != true:
			_failures.append("SO: final scorecard missing super_over flag")
		var mains2: Array = sc.get("main_innings", [])
		if mains2.size() != 2:
			_failures.append("SO: final scorecard missing main innings")
		# NRR helper resolves to the fabricated 49/49 main-match figures.
		var tm = root.get_node("TournamentManager")
		var pair: Array = tm.nrr_innings(sc, gm2.first_innings_scorecard, winner)
		var payload: Dictionary = tm.nrr_payload(pair[0], pair[1])
		if int(payload.get("winner_runs", -1)) != 49 or int(payload.get("loser_runs", -1)) != 49:
			_failures.append("SO: NRR payload not the 49/49 main figures: %s" % [payload])
		print("[so] super-over resolved: winner=%s rounds=%s" % [winner, str(gm2.state.get("super_over_round", 0))])
		_direct_test_active = false
		_begin_tournament_phase()

# ─── Tournament unit test: full auto-sim World Cup ───
var _tournament_phase: bool = false
var _tour_fixtures: Array = []
var _tour_idx: int = 0
var _tour_kind: String = "group"
var _tour_advance: bool = false

func _begin_tournament_phase() -> void:
	_tournament_phase = true
	var tm = root.get_node("TournamentManager")
	var gm = root.get_node("GameManager")
	_engine.fast_forward = true
	# AI-vs-AI tournament: every fixture auto-sims at 1 over per innings.
	tm.start_new_tournament(gm.all_teams[0])
	_tour_fixtures = tm.fixtures.duplicate(true)
	_tour_idx = 0
	_tour_kind = "group"
	_engine.match_ended_signal.connect(_on_tour_match_ended)
	print("[tour] tournament phase begun: %d group fixtures" % _tour_fixtures.size())
	_tour_advance = true

# Plays the next tournament fixture (called from _on_frame, never re-entrant).
func _play_next_tour_fixture(tm: Node) -> void:
	var gm = root.get_node("GameManager")
	if _tour_kind == "group":
		if _tour_idx < _tour_fixtures.size():
			var f = _tour_fixtures[_tour_idx]
			var home = tm.team_by_name(f["home"])
			var away = tm.team_by_name(f["away"])
			_engine.start_match(home, away, 0, null, true)
			gm.state["max_overs"] = 1
		else:
			if not tm.group_stage_complete():
				_failures.append("tour: group stage not complete after all fixtures")
			tm.advance_stage()
			if tm.stage != tm.Stage.SEMIS:
				_failures.append("tour: stage did not advance to SEMIS (got %d)" % tm.stage)
			if tm.semis.size() != 2:
				_failures.append("tour: expected 2 semis, got %d" % tm.semis.size())
			_tour_kind = "semi"
			_tour_idx = 0
			_tour_advance = true
			return
	elif _tour_kind == "semi":
		if _tour_idx < tm.semis.size():
			var s = tm.semis[_tour_idx]
			var home = tm.team_by_name(s["home"])
			var away = tm.team_by_name(s["away"])
			_engine.start_match(home, away, 0, null, true)
			gm.state["max_overs"] = 1
		else:
			for s in tm.semis:
				if not s["done"]:
					_failures.append("tour: semi not done: %s" % [s])
			tm.advance_stage()
			if tm.stage != tm.Stage.FINAL:
				_failures.append("tour: stage did not advance to FINAL (got %d)" % tm.stage)
			_tour_kind = "final"
			_tour_advance = true
			return
	elif _tour_kind == "final":
		if not tm.final_match.get("done", false):
			var home = tm.team_by_name(tm.final_match["home"])
			var away = tm.team_by_name(tm.final_match["away"])
			_engine.start_match(home, away, 0, null, true)
			gm.state["max_overs"] = 1
		else:
			tm.advance_stage()
			if tm.stage != tm.Stage.DONE:
				_failures.append("tour: did not reach DONE (got %d)" % tm.stage)
			if tm.champion == "":
				_failures.append("tour: no champion crowned")
			# Save/load round-trip check
			var before_groups: Array = tm.groups.map(func(g): return g.map(func(t): return t.team_name))
			var before_points: Dictionary = {}
			for t in gm.all_teams:
				before_points[t.team_name] = t.points
			tm.load_saved()
			var after_groups: Array = tm.groups.map(func(g): return g.map(func(t): return t.team_name))
			if before_groups != after_groups:
				_failures.append("tour: save/load groups mismatch")
			for t in gm.all_teams:
				if before_points[t.team_name] != t.points:
					_failures.append("tour: save/load points mismatch for %s" % t.team_name)
			var played_total := 0
			for t in gm.all_teams:
				played_total += t.matches_played
			if played_total < 24:  # 12 group games = 24 team-appearances
				_failures.append("tour: too few matches recorded (%d team-appearances)" % played_total)
			print("[tour] champion: %s | team-appearances: %d" % [tm.champion, played_total])
			_test_xi_persistence(tm, gm)
			_tour_kind = "done"
			_engine.fast_forward = false
			tm.abandon()
			_engine.match_ended_signal.disconnect(_on_tour_match_ended)
			_finish()
			return
	return  # waiting for the current fixture's match_ended signal

func _overs_float(state: Dictionary) -> float:
	# Overs as float: completed overs + balls/6
	return float(state.get("current_over", 0)) + float(state.get("current_ball", 0)) / 6.0

# XI persistence: custom XI survives save/load; invalid XIs are rejected.
func _test_xi_persistence(tm: Node, gm: Node) -> void:
	var team = gm.all_teams[0]
	# Build a custom XI: squad indices 2..12 (11 players, includes bowlers).
	# slice() on a typed array preserves the type.
	var custom: Array = team.squad.slice(2, 13)
	var problems: Array = team.validate_xi(custom)
	if not problems.is_empty():
		_failures.append("XI: valid custom XI rejected: %s" % [problems])
		return
	var apply_problems: Array = team.set_playing_xi(custom)
	if not apply_problems.is_empty():
		_failures.append("XI: set_playing_xi failed: %s" % [apply_problems])
		return
	# Invalid XI must be rejected, original XI kept.
	var short: Array = team.squad.slice(0, 10)
	if team.validate_xi(short).is_empty():
		_failures.append("XI: 10-player XI accepted (should be rejected)")
	if team.playing_xi.size() != 11:
		_failures.append("XI: playing_xi corrupted by rejected set")
	# Round-trip through the real tournament save.
	tm.save()
	var expected: Array = []
	for p in team.playing_xi:
		expected.append(p.player_name)
	# Clobber locally to prove the load restores it.
	team.playing_xi.clear()
	for i in range(11):
		team.playing_xi.append(team.squad[i])
	if not tm.load_saved():
		_failures.append("XI: load_saved failed during XI round-trip")
		return
	var got: Array = []
	for p in team.playing_xi:
		got.append(p.player_name)
	if got != expected:
		_failures.append("XI: round-trip mismatch: %s vs %s" % [got, expected])
	print("[xi] persistence round-trip OK (%d players)" % got.size())

# Records a finished tournament fixture; the next one is started by _on_frame.
func _on_tour_match_ended(winner: String) -> void:
	if not _tournament_phase:
		return
	var tm = root.get_node("TournamentManager")
	var gm = root.get_node("GameManager")
	var sc = gm._build_scorecard()
	var first = gm.first_innings_scorecard
	if _tour_kind == "group":
		var f = _tour_fixtures[_tour_idx]
		if winner != f["home"] and winner != f["away"]:
			_failures.append("tour: winner %s not one of the fixture teams" % winner)
		var innings: Array = tm.nrr_innings(sc, first, winner)
		tm.record_result(f["home"], f["away"], winner, tm.nrr_payload(innings[0], innings[1]))
		_tour_idx += 1
	elif _tour_kind == "semi":
		var s = tm.semis[_tour_idx]
		if winner != s["home"] and winner != s["away"]:
			_failures.append("tour: semi winner %s invalid" % winner)
		tm.record_knockout("semi%d" % _tour_idx, s["home"], s["away"], winner)
		_tour_idx += 1
	elif _tour_kind == "final":
		tm.record_knockout("final", tm.final_match["home"], tm.final_match["away"], winner)
	_tour_advance = true

func _overs_from_string(s: String) -> float:
	var parts = s.split(".")
	if parts.size() == 2:
		return float(parts[0]) + float(parts[1]) / 6.0
	return 0.0

func _finish_tournament() -> void:
	_finish()

# ─── Career unit checks (fabricated stats, no sim) ───
func _test_career() -> void:
	var cm = root.get_node("CareerManager")
	var backup: Dictionary = cm.players.duplicate(true)
	cm.reset()
	# Fabricate one match worth of stats on two real players.
	var bat = _gm.all_teams[0].playing_xi[0]
	var bowl = _gm.all_teams[1].playing_xi[7]
	bat.match_runs = 67
	bat.match_balls = 40
	bat.match_fours = 8
	bat.match_sixes = 2
	bat.is_out = true
	bowl.match_wickets = 3
	bowl.match_runs_conceded = 24
	bowl.match_catches = 0
	var fielder = _gm.all_teams[1].playing_xi[3]
	fielder.match_catches = 2
	_engine.human_side = null
	_gm.batting_team = _gm.all_teams[0]
	_gm.bowling_team = _gm.all_teams[1]
	_gm.state["super_over"] = false
	cm.record_match()
	var e1: Dictionary = cm.players.get(bat.player_name, {})
	if int(e1.get("runs", -1)) != 67 or int(e1.get("fifties", -1)) != 1:
		_failures.append("career: batter aggregates wrong: %s" % [e1])
	var e2: Dictionary = cm.players.get(bowl.player_name, {})
	if int(e2.get("wickets", -1)) != 3 or int(e2.get("best_wkts", -1)) != 3:
		_failures.append("career: bowler aggregates wrong: %s" % [e2])
	if int(cm.players.get(fielder.player_name, {}).get("catches", -1)) != 2:
		_failures.append("career: fielder catches wrong")
	if cm.batting_table().is_empty() or cm.bowling_table().is_empty():
		_failures.append("career: tables empty after recording")
	# Super-over matches must NOT pollute career stats.
	_gm.state["super_over"] = true
	cm.record_match()
	if int(cm.players[bat.player_name]["runs"]) != 67:
		_failures.append("career: super-over match leaked into aggregates")
	_gm.state["super_over"] = false
	# Save/load round-trip.
	cm.save()
	cm.players.clear()
	cm.load_career()
	if int(cm.players.get(bat.player_name, {}).get("runs", -1)) != 67:
		_failures.append("career: save/load round-trip lost data")
	cm.reset()
	if not cm.players.is_empty():
		_failures.append("career: reset did not clear")
	# Restore any pre-existing career data (don't clobber real saves).
	cm.players = backup
	cm.save()
	print("[career] unit checks done")

# ─── Direct DRS unit checks ───
func _test_drs_directly() -> void:
	var drs_script = load("res://scripts/core/modules/DRSSystem.gd")
	var p_script = load("res://scripts/core/PlayerData.gd")
	var drs = drs_script.new()
	var batsman = p_script.new()
	var bowler = p_script.new()
	batsman.player_name = "TestBat"
	batsman.batting_skill = 75
	bowler.player_name = "TestBowl"
	bowler.bowling_skill = 70
	bowler.bowling_type = "FAST"
	var overturned = 0
	for i in range(100):
		var wtype = "LBW" if i % 2 == 0 else "CAUGHT"
		var res = drs.review_decision(wtype, batsman, bowler, true)
		if not (res is Dictionary) or not res.has("overturned") or not (res["overturned"] is bool):
			_failures.append("DRS: malformed result on iter %d" % i)
			return
		if res.get("umpires_call", false) and res["overturned"]:
			_failures.append("DRS: umpire's call but result overturned (iter %d)" % i)
			return
		if res["overturned"]:
			overturned += 1
		if wtype == "CAUGHT" and res.get("umpires_call", false):
			_failures.append("DRS: umpire's call on a caught decision (iter %d)" % i)
			return
	if overturned == 0 or overturned == 100:
		_failures.append("DRS: degenerate overturn rate %d/100" % overturned)
	print("DRS direct: %d/100 overturned (expected ~10-50)" % overturned)

func _finish() -> void:
	print("── SMOKE TEST RESULTS ─────────────────────")
	for line in _results:
		print(line)
	if _failures.is_empty():
		print("ALL CHECKS PASSED (%d matches + DRS unit + full tournament)" % _matches.size())
		quit(0)
	else:
		print("FAILURES (%d):" % _failures.size())
		for f in _failures:
			print("  X " + f)
		quit(1)
