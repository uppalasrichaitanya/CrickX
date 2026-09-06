# MatchEngine.gd — Drives the match loop and state machine (Autoload).
# NEW FLOW: Bowler picks delivery → Reveal to batsman → Batsman reacts with shot.
extends Node

signal state_changed(new_state: String)
signal ball_result_ready(outcome: Dictionary)
signal over_ended(summary: Dictionary)
signal innings_ended_signal(scorecard: Dictionary)
signal match_ended_signal(winner: String)
signal request_shot_selection(delivery_name: String)
signal request_bowl_selection()
signal request_drs_review(wicket_type: String, reviews_left: int)
signal delivery_incoming(delivery_name: String)
signal delivery_thrown(delivery_type: int)
signal super_over_starting(round_no: int)
signal second_innings_starting()

enum State { IDLE, BOWLING_APPROACH, WAITING_FOR_SHOT, WAITING_FOR_BOWL, SIMULATING, SHOWING_RESULT, WAITING_FOR_REVIEW, END_OF_OVER, END_OF_INNINGS, MATCH_OVER }

var current_state: int = State.IDLE
var simulator: BallSimulator = null
var current_shot: int = -1
var current_delivery: int = -1
var is_human_batting: bool = true
var is_human_bowling: bool = false
var runs_this_over: int = 0
var wickets_this_over: int = 0
var balls_this_over_log: Array[Dictionary] = []
var weather_pitch := WeatherPitchSystem.new()
var _hud_connected: bool = false
var _match_pending: bool = false
var _match_gen: int = 0  # Generation token — zombie coroutines from old matches abort on mismatch
var human_side: TeamData = null  # The player's team this match (null = pure AI match)
var human_bowls_role: bool = true  # Does the human play their bowling innings?
var hotseat: bool = false  # Hot-seat: both teams are human (pass-the-device)
var _net_wait: bool = false  # Current input wait is for the remote peer
var net_fallbacks: int = 0  # Watchdog AI-fills (0 in a healthy session)
var fast_forward: bool = false  # Collapse inter-ball delays for quick auto-sim
var _pending_drs_outcome: Dictionary = {}
var _pending_drs_wicket_type: String = ""
var _prev_bowler: PlayerData = null  # Consecutive-over guard
var _hat_trick_ball: bool = false    # Bowler is ON a hat-trick ball right now
var _over_events: Array[String] = [] # Pending flavor lines for the over summary

func _ready() -> void:
	simulator = BallSimulator.new()
	add_child(simulator)

# Called by MatchHUD once its _ready() has finished (all signals connected).
func note_hud_ready() -> void:
	_hud_connected = true
	if _match_pending:
		_match_pending = false
		_begin_match_flow()

# Called by MatchHUD when it is freed, so a stale flag can't skip the handshake next match.
func note_hud_gone() -> void:
	_hud_connected = false

func start_match(team_a: TeamData, team_b: TeamData, format: int,
		human_team: TeamData = null, human_plays_bowling: bool = true,
		hotseat_mode: bool = false) -> void:
	_match_gen += 1  # Any ball-flow coroutines still awaiting from the last match now abort.
	GameManager.start_new_match(team_a, team_b, format)
	GameManager.remove_meta("match_tied")
	human_side = human_team
	human_bowls_role = human_plays_bowling
	hotseat = hotseat_mode
	# Roles are derived from the human's team: bat when their side is at the
	# crease, bowl when it fields (if the mode allows bowling).
	_apply_roles()
	_prev_bowler = null
	_hat_trick_ball = false
	for t in [team_a, team_b]:
		for p in t.squad:
			p.set_meta("wicket_ledger", [])
	simulator.ai_controller.set_difficulty(GameManager.difficulty)
	runs_this_over = 0
	wickets_this_over = 0
	balls_this_over_log = []
	# Don't start bowling until the HUD exists and has connected its signal handlers,
	# otherwise the first ball's shot-selection request is lost and the match hangs.
	if _hud_connected:
		_begin_match_flow()
	else:
		var gen := _match_gen
		_match_pending = true
		# Safety net: never hang the game indefinitely if the HUD never appears.
		await get_tree().create_timer(5.0).timeout
		if _match_pending and gen == _match_gen:
			_match_pending = false
			push_warning("MatchEngine: HUD never reported ready — starting ball flow anyway.")
			_begin_match_flow()

# Human plays their team's role in the current innings: bats if their side
# is at the crease, bowls otherwise (when the mode allows bowling).
# Hot-seat: both sides are human, so both flags stay true every innings.
# Pure AI matches (human_side == null) leave both flags false.
func _apply_roles() -> void:
	if hotseat:
		is_human_batting = true
		is_human_bowling = true
		return
	if human_side == null:
		is_human_batting = false
		is_human_bowling = false
		return
	is_human_batting = (GameManager.batting_team == human_side)
	is_human_bowling = human_bowls_role and (GameManager.bowling_team == human_side)

func _begin_match_flow() -> void:
	AudioManager.start_ambient()
	await _wait(0.8)
	_begin_ball(_match_gen)

# ─── Online (authoritative host) helpers ───
# The host runs the full sim; the client mirrors events and sends inputs.
func _net_active() -> bool:
	return NetworkManager.online and NetworkManager.is_host

# True when the BOWLING side right now is the remote peer's team.
func _net_turn_bowl() -> bool:
	return _net_active() and GameManager.bowling_team != null \
		and GameManager.bowling_team.team_name == NetworkManager.client_team_name

# True when the BATTING side right now is the remote peer's team.
func _net_turn_bat() -> bool:
	return _net_active() and GameManager.batting_team != null \
		and GameManager.batting_team.team_name == NetworkManager.client_team_name

func _net_broadcast(event: Dictionary) -> void:
	if _net_active():
		event["snapshot"] = NetworkManager.build_snapshot()
		NetworkManager.broadcast(event)

# ENet RPCs only carry plain Variants — strip any Object references
# (e.g. the catch fielder) from engine dicts before broadcasting.
func _net_clean(d: Dictionary) -> Dictionary:
	var out := d.duplicate()
	for k in out.keys():
		if out[k] is Object:
			out.erase(k)
		elif out[k] is Array:
			var arr: Array = (out[k] as Array).duplicate()
			for i in range(arr.size()):
				if arr[i] is Dictionary:
					arr[i] = _net_clean(arr[i])
			out[k] = arr
	return out

# Host watchdog: a dropped/silent peer can never soft-lock the match —
# unresolved remote inputs fall back to AI after the timeout.
func _start_net_watchdog() -> void:
	var gen := _match_gen
	var st := current_state
	_net_wait = true
	await get_tree().create_timer(NetworkManager.INPUT_WAIT_TIMEOUT).timeout
	if gen != _match_gen or not _net_wait or current_state != st:
		return
	_net_wait = false
	net_fallbacks += 1
	if current_state == State.WAITING_FOR_BOWL:
		current_delivery = simulator.ai_controller.choose_bowling_delivery(
			GameManager.current_bowler, GameManager.striker, GameManager.state)
		_on_delivery_chosen(current_delivery, _match_gen)
	elif current_state == State.WAITING_FOR_SHOT:
		current_shot = simulator.ai_controller.choose_batting_shot(
			GameManager.striker, GameManager.state)
		_on_shot_selected(current_shot)
	elif current_state == State.WAITING_FOR_REVIEW:
		_resolve_drs_review(false)

# ═══════════════════════════════════════
# NEW FLOW: Delivery first, then batsman reacts
# Ball-flow coroutines carry the match generation they belong to; if a newer
# match starts while they're suspended, they abort on resume (no zombie bowling).
# ═══════════════════════════════════════
func _begin_ball(gen: int) -> void:
	if gen != _match_gen:
		return
	current_shot = -1
	current_delivery = -1
	
	# Step 1: pick who bowls this ball — local human, remote human, or AI
	if _net_turn_bowl():
		current_state = State.WAITING_FOR_BOWL
		_net_broadcast({"type": "request_bowl"})
		_start_net_watchdog()
	elif is_human_bowling:
		current_state = State.WAITING_FOR_BOWL
		request_bowl_selection.emit()
	else:
		current_delivery = simulator.ai_controller.choose_bowling_delivery(
			GameManager.current_bowler, GameManager.striker, GameManager.state)
		_on_delivery_chosen(current_delivery, gen)

func receive_bowl_input(delivery: int) -> void:
	if current_state == State.WAITING_FOR_BOWL:
		_net_wait = false
		current_delivery = delivery
		_on_delivery_chosen(delivery, _match_gen)

func _on_delivery_chosen(delivery: int, gen: int) -> void:
	if gen != _match_gen:
		return
	current_delivery = delivery
	current_state = State.BOWLING_APPROACH
	
	# Step 2: Show "bowler running in..." then reveal
	var del_name = _get_delivery_name(delivery)
	if _hat_trick_ball:
		del_name = "⚡ HAT-TRICK BALL ⚡ " + del_name
	delivery_incoming.emit(del_name)
	delivery_thrown.emit(delivery)
	_net_broadcast({"type": "delivery", "delivery_name": del_name, "delivery_type": delivery})
	
	# After 0.6s approach animation, show shot selection
	await _wait(0.6)
	if gen != _match_gen:
		return
	
	# Step 3: Now batsman must react — local human, remote human, or AI
	if _net_turn_bat():
		current_state = State.WAITING_FOR_SHOT
		_net_broadcast({"type": "request_shot", "delivery_name": del_name})
		_start_net_watchdog()
	elif is_human_batting:
		current_state = State.WAITING_FOR_SHOT
		request_shot_selection.emit(del_name)
	else:
		current_shot = simulator.ai_controller.choose_batting_shot(
			GameManager.striker, GameManager.state)
		_on_shot_selected(current_shot)

func _on_shot_selected(shot: int) -> void:
	current_shot = shot
	current_state = State.SIMULATING
	_simulate()

func receive_shot_input(shot: int) -> void:
	if current_state == State.WAITING_FOR_SHOT:
		_net_wait = false
		_on_shot_selected(shot)

func _simulate() -> void:
	var outcome = simulator.simulate_ball(
		GameManager.striker, GameManager.current_bowler,
		current_shot, current_delivery, GameManager.state,
		GameManager.bowling_team)
	outcome["delivery_name"] = _get_delivery_name(current_delivery)
	outcome["shot_name"] = _get_shot_name(current_shot)
	_process_outcome(outcome)

func _process_outcome(outcome: Dictionary) -> void:
	var runs = outcome.get("runs", 0)
	var is_wicket = outcome.get("is_wicket", false)
	var is_wide = outcome.get("is_wide", false)
	var is_no_ball = outcome.get("is_no_ball", false)
	
	# Update match stats
	if not is_wide:
		GameManager.striker.match_balls += 1
		if runs > 0 and not (is_no_ball and not is_wicket and runs == 1):
			GameManager.striker.match_runs += runs
			if runs == 4: GameManager.striker.match_fours += 1
			if runs == 6: GameManager.striker.match_sixes += 1
	
	GameManager.state["total_runs"] += runs
	runs_this_over += runs
	
	if is_wide: GameManager.extras["wides"] += 1
	if is_no_ball: GameManager.extras["no_balls"] += 1
	
	# Bowler stats — wides/no-ball penalty runs DO count against the bowler.
	var bowler_runs = runs if not is_wide else 1
	if is_no_ball:
		bowler_runs = 1 + maxf(0.0, float(runs - 1))
	GameManager.current_bowler.match_runs_conceded += int(bowler_runs)
	
	# Track shot history for AI
	if current_shot >= 0:
		var hist = GameManager.striker.shot_history
		hist[current_shot] = hist.get(current_shot, 0) + 1
	
	# Ball count (wides/no-balls don't count)
	if not is_wide and not is_no_ball:
		GameManager.state["current_ball"] += 1
		balls_this_over_log.append(outcome)
	
	if is_wicket:
		var wtype = outcome.get("wicket_type", "BOWLED")
		if _is_reviewable_wicket(wtype) and GameManager.drs_reviews_batting > 0:
			# Wicket is deferred — resolved after the (possible) DRS review.
			_enter_drs_review(outcome, wtype)
			return
		_finalize_wicket(outcome, wtype)
	else:
		# Dropped catch — bowler's heartbreak, batsman's life
		if outcome.get("commentary_key", "") == "DROPPED_CATCH":
			AudioManager.play_crowd_cheer()
		# Boundary sounds
		if runs == 4 or runs == 6:
			AudioManager.play_bat_hit()
			AudioManager.play_crowd_cheer()
			GameManager.boundary_hit.emit(runs)
		
		# Rotate strike on odd runs (not off the no-ball penalty itself)
		if runs % 2 == 1 and not is_no_ball:
			GameManager.rotate_strike()
		_after_ball(outcome)

func _after_ball(outcome: Dictionary) -> void:
	# Hat-trick ledger: one entry per legal delivery, once the ball is final.
	if not outcome.get("is_wide", false) and not outcome.get("is_no_ball", false):
		_record_ledger(GameManager.current_bowler, outcome.get("is_wicket", false))
	
	# Check chase target
	if not GameManager.state["is_first_innings"]:
		if GameManager.state["total_runs"] >= GameManager.state["target"]:
			_end_match(GameManager.batting_team.team_name)
			return
	
	# Emit ball result
	GameManager.ball_bowled.emit(outcome)
	current_state = State.SHOWING_RESULT
	ball_result_ready.emit(outcome)
	_net_broadcast({"type": "ball", "outcome": _net_clean(outcome)})
	
	# Check end of over
	if GameManager.state["current_ball"] >= Constants.BALLS_PER_OVER:
		_end_over()
	else:
		_wait_then_next_ball(_result_wait(outcome))

# Big moments (boundary, wicket, drop, review) get a longer beat so the
# field view animation can breathe; ordinary balls keep the snappy pace.
func _result_wait(outcome: Dictionary) -> float:
	var runs = outcome.get("runs", 0)
	if runs >= 4 or outcome.get("is_wicket", false) \
			or outcome.get("commentary_key", "") == "DROPPED_CATCH" \
			or outcome.get("milestone", "") != "":
		return 1.4
	return 0.8

func _finalize_wicket(outcome: Dictionary, wtype: String) -> void:
	GameManager.state["total_wickets"] += 1
	wickets_this_over += 1
	GameManager.striker.is_out = true
	GameManager.partnership_start_runs = GameManager.state["total_runs"]
	GameManager.striker.dismissal_text = outcome.get("dismissal_display", wtype)
	GameManager.current_bowler.match_wickets += 1
	GameManager.fall_of_wickets.append({
		"score": GameManager.state["total_runs"],
		"over": GameManager.get_current_over_string(),
		"batsman": GameManager.striker.player_name,
	})
	
	GameManager.wicket_fallen.emit(GameManager.striker, wtype)
	AudioManager.play_wicket()
	
	# Hat-trick bookkeeping: this wicket may complete a hat-trick.
	if _hat_trick_ball:
		outcome["hat_trick_completed"] = true
	
	# Check all out (per-innings wicket cap — 2 in a super over)
	if GameManager.state["total_wickets"] >= int(GameManager.state.get("max_wickets", Constants.MAX_WICKETS)):
		_end_innings()
		return
	
	# New batsman
	var next = GameManager.next_batsman()
	if next == null:
		_end_innings()
		return
	GameManager.striker = next
	GameManager.striker.is_on_strike = true
	_after_ball(outcome)

# Ledger of the bowler's last 2 legal deliveries (true = wicket).
# When both are wickets, his next legal delivery is a hat-trick ball.
func _record_ledger(bowler: PlayerData, took_wicket: bool) -> void:
	var ledger: Array = bowler.get_meta("wicket_ledger", [])
	ledger.append(took_wicket)
	if ledger.size() > 2:
		ledger = ledger.slice(ledger.size() - 2, ledger.size())
	bowler.set_meta("wicket_ledger", ledger)
	_hat_trick_ball = (ledger.size() == 2 and ledger[0] == true and ledger[1] == true)

# ═══════════════════════════════════════
# DRS REVIEW FLOW
# ═══════════════════════════════════════
func _is_reviewable_wicket(wtype: String) -> bool:
	return wtype in ["LBW", "CAUGHT", "CAUGHT_BEHIND"]

func _enter_drs_review(outcome: Dictionary, wtype: String) -> void:
	current_state = State.WAITING_FOR_REVIEW
	_pending_drs_outcome = outcome
	_pending_drs_wicket_type = wtype
	if _net_turn_bat():
		_net_broadcast({"type": "request_drs", "wicket_type": wtype,
			"reviews_left": GameManager.drs_reviews_batting})
		_start_net_watchdog()
	elif is_human_batting:
		request_drs_review.emit(wtype, GameManager.drs_reviews_batting)
	else:
		# AI team is batting: decide after a short dramatic beat.
		var gen := _match_gen
		await _wait(1.2)
		if gen != _match_gen:
			return
		var wants_review = simulator.ai_controller.should_review_drs(
			GameManager.striker, true, wtype)
		_resolve_drs_review(wants_review)

func receive_drs_input(should_review: bool) -> void:
	if current_state != State.WAITING_FOR_REVIEW:
		return
	if not is_human_batting and not _net_wait:
		return
	_net_wait = false
	_resolve_drs_review(should_review)

func _resolve_drs_review(should_review: bool) -> void:
	current_state = State.SIMULATING
	var outcome = _pending_drs_outcome
	var wtype = _pending_drs_wicket_type
	_pending_drs_outcome = {}
	
	if not should_review:
		_finalize_wicket(outcome, wtype)
		return
	
	# Review taken — always costs a review.
	GameManager.drs_reviews_batting -= 1
	GameManager.drs_initiated.emit(GameManager.batting_team.team_name, wtype)
	var result = simulator.drs.review_decision(
		wtype, GameManager.striker, GameManager.current_bowler, true)
	
	if result.get("overturned", false):
		# Wicket does not stand — same batsman stays.
		var o = outcome.duplicate()
		o["is_wicket"] = false
		o["runs"] = 0
		o["commentary_key"] = "DRS_NOT_OUT"
		o["drs_commentary"] = result.get("commentary", "")
		_after_ball(o)
	else:
		outcome["drs_reviewed"] = true
		outcome["drs_commentary"] = result.get("commentary", "")
		_finalize_wicket(outcome, wtype)

func _wait_then_next_ball(delay: float = 0.8) -> void:
	var gen := _match_gen
	await _wait(delay)
	if gen != _match_gen:
		return
	_begin_ball(gen)

func _end_over() -> void:
	var gen := _match_gen
	current_state = State.END_OF_OVER
	GameManager.state["current_over"] += 1
	GameManager.state["current_ball"] = 0
	GameManager.update_phase()
	
	# Bowler overs tracking
	GameManager.current_bowler.match_overs_bowled += 1.0
	GameManager.current_bowler.current_spell_overs += 1.0
	
	# Fatigue recovery for everyone not bowling this over
	for p in GameManager.bowling_team.playing_xi:
		if p != GameManager.current_bowler:
			p.fatigue = clampf(p.fatigue - Constants.SPELL_REST_RECOVERY, 0.0, 1.0)
	
	# Over event flavor (shown by the HUD after the summary)
	_over_events = []
	if runs_this_over == 0 and wickets_this_over == 0:
		GameManager.current_bowler.match_maidens += 1
		GameManager.momentum = simulator.atmosphere.update_momentum(GameManager.momentum, "MAIDEN")
		_over_events.append("MAIDEN")
	elif runs_this_over >= Constants.BIG_OVER_RUNS:
		GameManager.momentum = simulator.atmosphere.update_momentum(GameManager.momentum, "BIG_OVER")
		_over_events.append("BIG_OVER")
	
	# Rotate strike at end of over
	GameManager.rotate_strike()
	
	# Weather change check
	if weather_pitch.should_change_weather(GameManager.state["current_over"]):
		GameManager.weather = weather_pitch.get_random_weather()
		GameManager.state["weather"] = GameManager.weather
		_over_events.append("WEATHER_CHANGE")
	
	# Drinks break — fatigue recovery for both sides
	var drinks_over = Constants.DRINKS_BREAK_OVER_T20 if GameManager.state["format"] == Constants.MatchFormat.T20 else Constants.DRINKS_BREAK_OVER_ODI
	if GameManager.state["current_over"] > 0 and GameManager.state["current_over"] % drinks_over == 0 and GameManager.state["current_over"] < GameManager.state["max_overs"]:
		simulator.form_fatigue.apply_drinks_break(GameManager.batting_team)
		simulator.form_fatigue.apply_drinks_break(GameManager.bowling_team)
		_over_events.append("DRINKS_BREAK")
	
	var summary = {
		"over_number": GameManager.state["current_over"],
		"runs": runs_this_over,
		"wickets": wickets_this_over,
		"bowler": GameManager.current_bowler.player_name,
		"economy": GameManager.current_bowler.get_economy(),
		"balls": balls_this_over_log.duplicate(),
		"events": _over_events.duplicate(),
	}
	GameManager.over_completed.emit(GameManager.state["current_over"], runs_this_over, wickets_this_over)
	over_ended.emit(summary)
	_net_broadcast({"type": "over", "summary": _net_clean(summary)})
	
	# Check max overs
	if GameManager.state["current_over"] >= GameManager.state["max_overs"]:
		_end_innings()
		return
	
	# Pick new bowler (never the same bowler twice in a row)
	_prev_bowler = GameManager.current_bowler
	var new_bowler = simulator.ai_controller.choose_bowler(GameManager.bowling_team, GameManager.state, _prev_bowler)
	if new_bowler != _prev_bowler:
		GameManager.current_bowler.current_spell_overs = 0.0  # spell resets on change
	GameManager.current_bowler = new_bowler
	_prev_bowler = new_bowler
	
	# Reset over tracking
	runs_this_over = 0
	wickets_this_over = 0
	balls_this_over_log = []
	
	# Wait then start next over
	await _wait(1.5)
	if gen != _match_gen:
		return
	_begin_ball(gen)

func _end_innings() -> void:
	var gen := _match_gen
	current_state = State.END_OF_INNINGS
	_credit_partial_over()
	var scorecard = GameManager._build_scorecard()
	GameManager.innings_ended.emit(scorecard)
	innings_ended_signal.emit(scorecard)
	
	if GameManager.state["is_first_innings"]:
		# Signal the HUD that second innings is starting
		second_innings_starting.emit()
		_net_broadcast({"type": "innings_break",
			"target": GameManager.state.get("total_runs", 0) + 1})
		await _wait(3.0)
		if gen != _match_gen:
			return
		GameManager.swap_innings()
		if GameManager.state.get("super_over", false):
			# Super-over chase: death-phase batting, captain's shootout rules.
			GameManager.state["phase"] = Constants.MatchPhase.DEATH
		# Second innings: roles re-derive from the human's team.
		_apply_roles()
		runs_this_over = 0
		wickets_this_over = 0
		balls_this_over_log = []
		_prev_bowler = null
		_hat_trick_ball = false
		for p in GameManager.bowling_team.squad:
			p.set_meta("wicket_ledger", [])
		_begin_ball(gen)
	else:
		# Match over — unless scores are level in a T20 (super over time).
		var bat_runs = GameManager.state["total_runs"]
		var target = GameManager.state["target"]
		var is_t20 = GameManager.state["format"] == Constants.MatchFormat.T20
		var in_shootout = GameManager.state.get("super_over", false)
		if bat_runs == target - 1 and is_t20 and not in_shootout:
			# LEVEL — first super-over round; the chaser bats first (no swap).
			_start_super_over_round(gen)
			return
		if bat_runs == target - 1 and is_t20 and in_shootout:
			# Tied again — swap sides so the other team bats first next round.
			var tmp = GameManager.batting_team
			GameManager.batting_team = GameManager.bowling_team
			GameManager.bowling_team = tmp
			_start_super_over_round(gen)
			return
		var winner = ""
		if bat_runs >= target:
			winner = GameManager.batting_team.team_name
		else:
			winner = GameManager.bowling_team.team_name
		# ODI ties stand as ties (super overs are a T20 shootout format).
		if bat_runs == target - 1 and not is_t20:
			GameManager.set_meta("match_tied", true)
		_end_match(winner)

# Begins one super-over round (both mini-innings flow through the normal loop).
func _start_super_over_round(gen: int) -> void:
	current_state = State.END_OF_INNINGS
	GameManager.start_super_over()
	_apply_roles()
	runs_this_over = 0
	wickets_this_over = 0
	balls_this_over_log = []
	_prev_bowler = null
	_hat_trick_ball = false
	for p in GameManager.bowling_team.squad:
		p.set_meta("wicket_ledger", [])
	super_over_starting.emit(int(GameManager.state.get("super_over_round", 1)))
	_net_broadcast({"type": "super_over", "round": int(GameManager.state.get("super_over_round", 1))})
	await _wait(2.0)
	if gen != _match_gen:
		return
	_begin_ball(gen)

func _end_match(winner: String) -> void:
	current_state = State.MATCH_OVER
	AudioManager.stop_ambient()
	_credit_partial_over()  # chase completed mid-over — keep bowler figures honest
	var scorecard = GameManager._build_scorecard()
	CareerManager.record_match()
	GameManager.match_ended.emit(winner, scorecard)
	match_ended_signal.emit(winner)
	_net_broadcast({"type": "match_end", "winner": winner,
		"scorecard": _net_clean(scorecard),
		"first_innings": _net_clean(GameManager.first_innings_scorecard)})

# Credit the current bowler for a partial over at innings/match end.
# Guarded so calling it twice (end_innings then end_match) never double-counts.
func _credit_partial_over() -> void:
	var partial = GameManager.state.get("current_ball", 0)
	if partial > 0 and GameManager.current_bowler != null:
		GameManager.current_bowler.match_overs_bowled += float(partial) / float(Constants.BALLS_PER_OVER)
		GameManager.state["current_ball"] = 0

# ═══════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════
func _wait(seconds: float) -> SceneTreeTimer:
	# Fast-forward collapses inter-ball delays to keep auto-sim snappy.
	var scaled = seconds if not fast_forward else 0.04
	return get_tree().create_timer(scaled)

func _get_delivery_name(delivery: int) -> String:
	match delivery:
		Constants.DeliveryType.YORKER: return "YORKER"
		Constants.DeliveryType.BOUNCER: return "SHORT BALL"
		Constants.DeliveryType.FULL_TOSS: return "FULL TOSS"
		Constants.DeliveryType.OFF_SPIN: return "OFF SPIN"
		Constants.DeliveryType.LEG_SPIN: return "LEG BREAK"
		Constants.DeliveryType.SLOWER: return "SLOWER BALL"
		_: return "DELIVERY"

func _get_shot_name(shot: int) -> String:
	match shot:
		Constants.ShotType.AGGRESSIVE_DRIVE: return "Drive"
		Constants.ShotType.PULL_SHOT: return "Pull"
		Constants.ShotType.SWEEP_SHOT: return "Sweep"
		Constants.ShotType.LOFT_SLOG: return "Slog"
		Constants.ShotType.DEFENSIVE_BLOCK: return "Block"
		Constants.ShotType.LEAVE_BALL: return "Leave"
		_: return "Shot"
