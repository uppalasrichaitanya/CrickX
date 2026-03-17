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
signal delivery_incoming(delivery_name: String)
signal second_innings_starting()

enum State { IDLE, BOWLING_APPROACH, WAITING_FOR_SHOT, WAITING_FOR_BOWL, SIMULATING, SHOWING_RESULT, END_OF_OVER, END_OF_INNINGS, MATCH_OVER }

var current_state: int = State.IDLE
var simulator: BallSimulator = null
var current_shot: int = -1
var current_delivery: int = -1
var is_human_batting: bool = true
var is_human_bowling: bool = false
var runs_this_over: int = 0
var wickets_this_over: int = 0
var balls_this_over_log: Array[Dictionary] = []
var _timer: Timer = null
var weather_pitch := WeatherPitchSystem.new()

func _ready() -> void:
	simulator = BallSimulator.new()
	add_child(simulator)
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)

func start_match(team_a: TeamData, team_b: TeamData, format: int,
		human_bats: bool = true, human_bowls: bool = false) -> void:
	GameManager.start_new_match(team_a, team_b, format)
	is_human_batting = human_bats
	is_human_bowling = human_bowls
	simulator.ai_controller.set_difficulty(GameManager.difficulty)
	runs_this_over = 0
	wickets_this_over = 0
	balls_this_over_log = []
	await get_tree().create_timer(0.8).timeout
	_begin_ball()

# ═══════════════════════════════════════
# NEW FLOW: Delivery first, then batsman reacts
# ═══════════════════════════════════════
func _begin_ball() -> void:
	current_shot = -1
	current_delivery = -1
	
	# Step 1: AI bowler always picks delivery first
	if is_human_bowling:
		current_state = State.WAITING_FOR_BOWL
		request_bowl_selection.emit()
	else:
		current_delivery = simulator.ai_controller.choose_bowling_delivery(
			GameManager.current_bowler, GameManager.striker, GameManager.state)
		_on_delivery_chosen(current_delivery)

func receive_bowl_input(delivery: int) -> void:
	if current_state == State.WAITING_FOR_BOWL:
		current_delivery = delivery
		_on_delivery_chosen(delivery)

func _on_delivery_chosen(delivery: int) -> void:
	current_delivery = delivery
	current_state = State.BOWLING_APPROACH
	
	# Step 2: Show "bowler running in..." then reveal
	var del_name = _get_delivery_name(delivery)
	delivery_incoming.emit(del_name)
	
	# After 0.6s approach animation, show shot selection
	await get_tree().create_timer(0.6).timeout
	
	# Step 3: Now batsman must react
	if is_human_batting:
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
		_on_shot_selected(shot)

func _simulate() -> void:
	var outcome = simulator.simulate_ball(
		GameManager.striker, GameManager.current_bowler,
		current_shot, current_delivery, GameManager.state)
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
	
	if not is_wicket:
		GameManager.striker.match_runs += runs
		if runs == 4: GameManager.striker.match_fours += 1
		if runs == 6: GameManager.striker.match_sixes += 1
	
	GameManager.state["total_runs"] += runs
	runs_this_over += runs
	
	if is_wide: GameManager.extras["wides"] += 1
	if is_no_ball: GameManager.extras["no_balls"] += 1
	
	# Bowler stats
	if not is_wide and not is_no_ball:
		GameManager.current_bowler.match_runs_conceded += runs
	
	# Track shot history for AI
	if current_shot >= 0:
		var hist = GameManager.striker.shot_history
		hist[current_shot] = hist.get(current_shot, 0) + 1
	
	# Ball count (wides/no-balls don't count)
	if not is_wide and not is_no_ball:
		GameManager.state["current_ball"] += 1
		balls_this_over_log.append(outcome)
	
	# Handle wicket
	if is_wicket:
		GameManager.state["total_wickets"] += 1
		wickets_this_over += 1
		GameManager.striker.is_out = true
		var wtype = outcome.get("wicket_type", "BOWLED")
		GameManager.striker.dismissal_text = wtype
		GameManager.current_bowler.match_wickets += 1
		
		GameManager.fall_of_wickets.append({
			"score": GameManager.state["total_runs"],
			"over": GameManager.get_current_over_string(),
			"batsman": GameManager.striker.player_name,
		})
		
		GameManager.wicket_fallen.emit(GameManager.striker, wtype)
		AudioManager.play_wicket()
		
		# Check all out
		if GameManager.state["total_wickets"] >= Constants.MAX_WICKETS:
			_end_innings()
			return
		
		# New batsman
		var next = GameManager.next_batsman()
		if next == null:
			_end_innings()
			return
		GameManager.striker = next
		GameManager.striker.is_on_strike = true
	else:
		# Boundary sounds
		if runs == 4 or runs == 6:
			AudioManager.play_bat_hit()
			AudioManager.play_crowd_cheer()
			GameManager.boundary_hit.emit(runs)
		
		# Rotate strike on odd runs
		if runs % 2 == 1:
			GameManager.rotate_strike()
	
	# Check chase target
	if not GameManager.state["is_first_innings"]:
		if GameManager.state["total_runs"] >= GameManager.state["target"]:
			_end_match(GameManager.batting_team.team_name)
			return
	
	# Emit ball result
	GameManager.ball_bowled.emit(outcome)
	current_state = State.SHOWING_RESULT
	ball_result_ready.emit(outcome)
	
	# Check end of over
	if GameManager.state["current_ball"] >= Constants.BALLS_PER_OVER:
		_end_over()
	else:
		_wait_then_next_ball()

func _wait_then_next_ball() -> void:
	await get_tree().create_timer(0.8).timeout
	_begin_ball()

func _end_over() -> void:
	current_state = State.END_OF_OVER
	GameManager.state["current_over"] += 1
	GameManager.state["current_ball"] = 0
	GameManager.update_phase()
	
	# Bowler overs tracking
	GameManager.current_bowler.match_overs_bowled += 1.0
	GameManager.current_bowler.current_spell_overs += 1.0
	
	# Maiden check
	if runs_this_over == 0 and wickets_this_over == 0:
		GameManager.current_bowler.match_maidens += 1
	
	# Rotate strike at end of over
	GameManager.rotate_strike()
	
	# Weather change check
	if weather_pitch.should_change_weather(GameManager.state["current_over"]):
		GameManager.weather = weather_pitch.get_random_weather()
		GameManager.state["weather"] = GameManager.weather
	
	var summary = {
		"over_number": GameManager.state["current_over"],
		"runs": runs_this_over,
		"wickets": wickets_this_over,
		"bowler": GameManager.current_bowler.player_name,
		"economy": GameManager.current_bowler.get_economy(),
		"balls": balls_this_over_log.duplicate(),
	}
	GameManager.over_completed.emit(GameManager.state["current_over"], runs_this_over, wickets_this_over)
	over_ended.emit(summary)
	
	# Check max overs
	if GameManager.state["current_over"] >= GameManager.state["max_overs"]:
		_end_innings()
		return
	
	# Pick new bowler
	var new_bowler = simulator.ai_controller.choose_bowler(GameManager.bowling_team, GameManager.state)
	GameManager.current_bowler = new_bowler
	
	# Reset over tracking
	runs_this_over = 0
	wickets_this_over = 0
	balls_this_over_log = []
	
	# Wait then start next over
	await get_tree().create_timer(1.5).timeout
	_begin_ball()

func _end_innings() -> void:
	current_state = State.END_OF_INNINGS
	var scorecard = GameManager._build_scorecard()
	GameManager.innings_ended.emit(scorecard)
	innings_ended_signal.emit(scorecard)
	
	if GameManager.state["is_first_innings"]:
		# Signal the HUD that second innings is starting
		second_innings_starting.emit()
		await get_tree().create_timer(3.0).timeout
		GameManager.swap_innings()
		# In Quick Match: Human bats first, AI bowls.
		# Second innings: AI bats, human can't do anything (auto-sim).
		is_human_batting = false
		is_human_bowling = false
		runs_this_over = 0
		wickets_this_over = 0
		balls_this_over_log = []
		_begin_ball()
	else:
		# Match over
		var winner = ""
		var bat_runs = GameManager.state["total_runs"]
		var target = GameManager.state["target"]
		if bat_runs >= target:
			winner = GameManager.batting_team.team_name
		else:
			winner = GameManager.bowling_team.team_name
		_end_match(winner)

func _end_match(winner: String) -> void:
	current_state = State.MATCH_OVER
	var scorecard = GameManager._build_scorecard()
	GameManager.match_ended.emit(winner, scorecard)
	match_ended_signal.emit(winner)

# ═══════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════
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
