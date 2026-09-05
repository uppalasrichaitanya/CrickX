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

# Match plan: [label, format, max_overs, fast_forward, full_mode]
var _matches: Array = [
	["T20-A", 0, 3, false, false],
	["T20-B", 0, 3, false, false],
	["T20-C", 0, 3, false, false],
	["ODI-A", 1, 5, false, false],
	["T20-FF", 0, 3, true, false],
	["FULL-A", 0, 2, false, true],
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
var _shot_requests: int = 0
var _bowl_requests: int = 0
var _drs_requests: int = 0

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
	process_frame.connect(_on_frame)

func _on_request_shot(_name: String) -> void:
	_shot_requests += 1
	_engine.receive_shot_input(randi_range(0, 5))

func _on_request_bowl() -> void:
	_bowl_requests += 1
	# Index 0 is always a valid delivery for any bowler type.
	_engine.receive_bowl_input(0)

func _on_request_drs(_wtype: String, _left: int) -> void:
	_drs_requests += 1
	_engine.receive_drs_input(randi_range(0, 1) == 0)

func _on_frame() -> void:
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
	var label: String = spec[0]
	var format: int = spec[1]
	var max_overs: int = spec[2]
	var ff: bool = spec[3]
	var full: bool = spec[4]
	_cur_format = format
	_cur_full = full
	_engine.fast_forward = ff
	var teams = _gm.all_teams
	# Full Match: human bats the 1st innings (we auto-respond), AI bowls it;
	# then the human bowls the 2nd innings (is_human_bowling = full_mode).
	_engine.start_match(
		teams[_match_index % teams.size()],
		teams[(_match_index + 1) % teams.size()],
		format, full, false, full
	)
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

	# 6. Target logic: winner must be consistent with the scores
	if first.size() > 0:
		var target = first.get("total_runs", 0) + 1
		var chased = sc.get("total_runs", 0)
		var expected = sc.get("team_name", "") if chased >= target else first.get("team_name", "")
		if winner != expected:
			_failures.append("%s: winner %s inconsistent (chased %d vs target %d)" % [label, winner, chased, target])

	# 7. DRS: reviews must stay within the format's bounds
	var reviews_now = _gm.drs_reviews_batting
	var max_reviews = int(_gm.get_max_reviews())
	if reviews_now < 0 or reviews_now > max_reviews:
		_failures.append("%s: DRS reviews out of bounds (now %d, max %d)" % [label, reviews_now, max_reviews])

	# 8. Full Match: both human roles must have been exercised
	#    (bat the 1st innings, bowl the 2nd innings)
	if _cur_full:
		if _shot_requests < 3:
			_failures.append("%s: expected >=3 shot requests (1st innings), got %d" % [label, _shot_requests])
		if _bowl_requests < 3:
			_failures.append("%s: expected >=3 bowl requests (2nd innings), got %d" % [label, _bowl_requests])

	_engine.fast_forward = false

	_results.append(
		"%-7s: %s won | 2nd inn %s/%d in %s ov | 1st inn %s/%d | wides %d, wickets %d, drops %d, reviews used %d%s" % [
			label, winner,
			str(sc.get("total_runs")), sc.get("total_wickets"), str(sc.get("total_overs")),
			str(first.get("total_runs")), first.get("total_wickets"),
			_wide_count, _wicket_count, _drop_count, max_reviews - reviews_now,
			(" | shots %d, bowls %d, drs %d" % [_shot_requests, _bowl_requests, _drs_requests]) if _cur_full else ""
		]
	)

	if _match_index >= _matches.size():
		_finish()

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
		print("ALL CHECKS PASSED (%d matches + DRS unit)" % _matches.size())
		quit(0)
	else:
		print("FAILURES (%d):" % _failures.size())
		for f in _failures:
			print("  X " + f)
		quit(1)
