# MatchHUD.gd — In-match display with delivery reveal, shot reaction, and commentary.
# NEW FLOW: See the delivery → React with your shot → See the result.
extends Control

# ─── Top Bar ───
@onready var lbl_batting_team := $TopBar/BattingTeam
@onready var lbl_score := $TopBar/Score
@onready var lbl_overs := $TopBar/Overs
@onready var lbl_format := $TopBar/FormatBadge
@onready var lbl_bowling_team := $TopBar/BowlingTeam
@onready var lbl_target_info := $TopBar/TargetInfo

# ─── Center Panel ───
@onready var lbl_striker := $CenterPanel/CenterVBox/BattingBox/Striker
@onready var lbl_non_striker := $CenterPanel/CenterVBox/BattingBox/NonStriker
@onready var lbl_bowler := $CenterPanel/CenterVBox/BowlingBox/Bowler
@onready var lbl_partnership := $CenterPanel/CenterVBox/InfoBox/Partnership
@onready var lbl_rrr := $CenterPanel/CenterVBox/InfoBox/RRR
@onready var lbl_crr := $CenterPanel/CenterVBox/InfoBox/CRR

# ─── Over Dots ───
@onready var over_dots_container := $OverDotsBar/HBox

# ─── Commentary ───
@onready var commentary_label := $CommentaryBox/CommentaryText
var commentary_tween: Tween = null

# ─── Shot Selection ───
@onready var shot_panel := $ShotSelectionPanel
@onready var timer_bar := $ShotSelectionPanel/ShotVBox/TimerBar
@onready var btn_shot_1 := $ShotSelectionPanel/ShotVBox/Grid/BtnShot1
@onready var btn_shot_2 := $ShotSelectionPanel/ShotVBox/Grid/BtnShot2
@onready var btn_shot_3 := $ShotSelectionPanel/ShotVBox/Grid/BtnShot3
@onready var btn_shot_4 := $ShotSelectionPanel/ShotVBox/Grid/BtnShot4
@onready var btn_shot_5 := $ShotSelectionPanel/ShotVBox/Grid/BtnShot5
@onready var btn_shot_6 := $ShotSelectionPanel/ShotVBox/Grid/BtnShot6

# ─── Delivery Alert ───
@onready var delivery_alert := $DeliveryAlert
@onready var lbl_delivery_name := $DeliveryAlert/DeliveryName

# ─── Bowl Selection ───
@onready var bowl_panel := $BowlSelectionPanel
@onready var bowl_timer_bar := $BowlSelectionPanel/BowlVBox/TimerBar
@onready var bowl_grid := $BowlSelectionPanel/BowlVBox/Grid
@onready var bowl_locked := $BowlSelectionPanel/BowlVBox/BowlLocked
@onready var btn_bowl_ready := $BowlSelectionPanel/BowlVBox/BtnBowlReady
@onready var bowl_title := $BowlSelectionPanel/BowlVBox/Title
@onready var shot_title := $ShotSelectionPanel/ShotVBox/Title
@onready var btn_bowl_1 := $BowlSelectionPanel/BowlVBox/Grid/BtnBowl1
@onready var btn_bowl_2 := $BowlSelectionPanel/BowlVBox/Grid/BtnBowl2
@onready var btn_bowl_3 := $BowlSelectionPanel/BowlVBox/Grid/BtnBowl3
@onready var btn_bowl_4 := $BowlSelectionPanel/BowlVBox/Grid/BtnBowl4

# ─── DRS Review Popup ───
@onready var drs_popup := $DRSPopup
@onready var lbl_drs_info := $DRSPopup/DRSPanel/DRSVBox/DRSInfo
@onready var drs_timer_bar := $DRSPopup/DRSPanel/DRSVBox/DRSTimer
@onready var btn_drs_yes := $DRSPopup/DRSPanel/DRSVBox/DRSBtns/DRSYesBtn
@onready var btn_drs_no := $DRSPopup/DRSPanel/DRSVBox/DRSBtns/DRSNoBtn

# ─── Status indicators ───
@onready var lbl_weather := $StatusBar/Weather
@onready var lbl_pitch := $StatusBar/Pitch
@onready var lbl_pressure := $StatusBar/Pressure
@onready var lbl_momentum := $StatusBar/Momentum
@onready var lbl_drs := $StatusBar/DRS
@onready var btn_ff := $StatusBar/FFBtn
@onready var btn_wagon := $StatusBar/WagonBtn

# ─── Field View ───
var field_view: FieldView = null
var _partnership_milestone_shown: int = 0

# ─── Over Summary Popup ───
@onready var over_summary_popup := $OverSummaryPopup
@onready var lbl_over_summary := $OverSummaryPopup/Content

# ─── Innings Break Popup ───
@onready var innings_break_popup := $InningsBreakPopup
@onready var lbl_innings_break := $InningsBreakPopup/BreakContent

var selection_timer: Timer = null
var bowl_timer: Timer = null
var drs_timer: Timer = null
var is_waiting_for_input: bool = false
var is_waiting_for_bowl: bool = false
var bowl_options: Array[int] = []
var _pending_bowl: int = -1  # Hot-seat: locked-in delivery awaiting the handoff tap
var _weather_pitch := WeatherPitchSystem.new()
const DRS_REVIEW_WINDOW: float = 5.0

func _ready() -> void:
	modulate.a = 0.0
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Constants.SCENE_FADE_DURATION)
	
	# Connect signals from MatchEngine
	MatchEngine.ball_result_ready.connect(_on_ball_result)
	MatchEngine.request_shot_selection.connect(_show_shot_selection)
	MatchEngine.request_bowl_selection.connect(_show_bowl_selection)
	MatchEngine.request_drs_review.connect(_show_drs_review)
	MatchEngine.delivery_incoming.connect(_show_delivery_alert)
	MatchEngine.over_ended.connect(_on_over_ended)
	MatchEngine.innings_ended_signal.connect(_on_innings_ended)
	MatchEngine.match_ended_signal.connect(_on_match_ended)
	MatchEngine.second_innings_starting.connect(_on_second_innings_starting)
	
	# Shot buttons
	btn_shot_1.pressed.connect(func(): _select_shot(Constants.ShotType.AGGRESSIVE_DRIVE))
	btn_shot_2.pressed.connect(func(): _select_shot(Constants.ShotType.PULL_SHOT))
	btn_shot_3.pressed.connect(func(): _select_shot(Constants.ShotType.SWEEP_SHOT))
	btn_shot_4.pressed.connect(func(): _select_shot(Constants.ShotType.LOFT_SLOG))
	btn_shot_5.pressed.connect(func(): _select_shot(Constants.ShotType.DEFENSIVE_BLOCK))
	btn_shot_6.pressed.connect(func(): _select_shot(Constants.ShotType.LEAVE_BALL))
	
	# Setup button text with icons
	btn_shot_1.text = "🏏 [1] Drive"
	btn_shot_2.text = "💪 [2] Pull"
	btn_shot_3.text = "🧹 [3] Sweep"
	btn_shot_4.text = "🚀 [4] Slog"
	btn_shot_5.text = "🛡️ [5] Block"
	btn_shot_6.text = "✋ [6] Leave"
	
	# Tooltips
	btn_shot_1.tooltip_text = "Aggressive drive through covers. Good vs full toss."
	btn_shot_2.tooltip_text = "Pull shot. Best vs short balls. Risk of top edge."
	btn_shot_3.tooltip_text = "Sweep shot. Effective vs spin. Risk of top edge."
	btn_shot_4.tooltip_text = "Big slog! Maximum intent. High six chance but high risk."
	btn_shot_5.tooltip_text = "Defensive block. Safe shot, survive the delivery."
	btn_shot_6.tooltip_text = "Leave the ball. Safe if outside off, risky if on stumps."
	
	# Selection timer (time to react, from Constants)
	selection_timer = Timer.new()
	selection_timer.wait_time = Constants.SHOT_SELECTION_TIMEOUT
	selection_timer.one_shot = true
	selection_timer.timeout.connect(_on_selection_timeout)
	add_child(selection_timer)
	
	# Bowl selection timer (same window as shots)
	bowl_timer = Timer.new()
	bowl_timer.wait_time = Constants.SHOT_SELECTION_TIMEOUT
	bowl_timer.one_shot = true
	bowl_timer.timeout.connect(_on_bowl_timeout)
	add_child(bowl_timer)
	
	# DRS review window timer
	drs_timer = Timer.new()
	drs_timer.wait_time = DRS_REVIEW_WINDOW
	drs_timer.one_shot = true
	drs_timer.timeout.connect(_on_drs_timeout)
	add_child(drs_timer)
	
	# Bowl buttons (delivery list depends on bowler type — set when panel shows)
	btn_bowl_1.pressed.connect(func(): _select_bowl(0))
	btn_bowl_2.pressed.connect(func(): _select_bowl(1))
	btn_bowl_3.pressed.connect(func(): _select_bowl(2))
	btn_bowl_4.pressed.connect(func(): _select_bowl(3))
	btn_bowl_ready.pressed.connect(_on_bowl_ready)
	
	# DRS buttons
	btn_drs_yes.pressed.connect(func(): _select_drs(true))
	btn_drs_no.pressed.connect(func(): _select_drs(false))
	
	# Fast-forward toggle
	btn_ff.toggled.connect(_on_ff_toggled)
	
	# Wagon wheel toggle
	btn_wagon.toggled.connect(func(pressed: bool) -> void:
		if field_view:
			field_view.toggle_wagon(pressed))
	
	# Field view (visual match rendering in the center band)
	var fv_scene = load("res://scenes/match/FieldView.tscn")
	field_view = fv_scene.instantiate()
	field_view.position = Vector2(140, 332)
	add_child(field_view)
	MatchEngine.delivery_thrown.connect(func(del: int) -> void:
		field_view.set_phase(GameManager.state.get("phase", 1))
		field_view.play_delivery(del))
	MatchEngine.ball_result_ready.connect(func(o: Dictionary) -> void: _on_field_outcome(o))
	MatchEngine.second_innings_starting.connect(_on_second_innings_for_field)
	MatchEngine.super_over_starting.connect(_on_super_over_for_field)
	# A wicket ends the current partnership — reset its milestone tracker
	GameManager.wicket_fallen.connect(func(_p, _w: String) -> void:
		_partnership_milestone_shown = 0)
	
	shot_panel.visible = false
	bowl_panel.visible = false
	over_summary_popup.visible = false
	delivery_alert.visible = false
	innings_break_popup.visible = false
	drs_popup.visible = false
	
	_update_display()
	
	# Tell the engine our signal handlers are connected before it starts ball flow.
	MatchEngine.note_hud_ready()

func _exit_tree() -> void:
	if is_instance_valid(MatchEngine):
		MatchEngine.note_hud_gone()

func _unhandled_input(event: InputEvent) -> void:
	if is_waiting_for_input:
		if event.is_action_pressed("shot_1"): _select_shot(Constants.ShotType.AGGRESSIVE_DRIVE)
		elif event.is_action_pressed("shot_2"): _select_shot(Constants.ShotType.PULL_SHOT)
		elif event.is_action_pressed("shot_3"): _select_shot(Constants.ShotType.SWEEP_SHOT)
		elif event.is_action_pressed("shot_4"): _select_shot(Constants.ShotType.LOFT_SLOG)
		elif event.is_action_pressed("shot_5"): _select_shot(Constants.ShotType.DEFENSIVE_BLOCK)
		elif event.is_action_pressed("shot_6"): _select_shot(Constants.ShotType.LEAVE_BALL)
	elif is_waiting_for_bowl:
		for i in range(4):
			if i < bowl_options.size() and event.is_action_pressed("shot_%d" % (i + 1)):
				_select_bowl(i)
				break
	elif _pending_bowl >= 0 and event.is_action_pressed("ui_accept"):
		_on_bowl_ready()

func _show_delivery_alert(delivery_name: String) -> void:
	# Flash the delivery type on screen
	delivery_alert.visible = true
	lbl_delivery_name.text = "🏏 " + delivery_name + " !"
	
	# Animate scale
	delivery_alert.scale = Vector2(0.5, 0.5)
	var tw = create_tween()
	tw.tween_property(delivery_alert, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _show_shot_selection(delivery_name: String) -> void:
	is_waiting_for_input = true
	shot_panel.visible = true
	delivery_alert.visible = true
	lbl_delivery_name.text = "⚡ " + delivery_name + " — REACT!"
	if MatchEngine.hotseat and GameManager.batting_team:
		shot_title.text = "⚡ %s — REACT — CHOOSE YOUR SHOT" % GameManager.batting_team.team_name.to_upper()
	
	timer_bar.value = 100.0
	selection_timer.start()
	# Animate timer bar (matches Constants.SHOT_SELECTION_TIMEOUT)
	var tw = create_tween()
	tw.tween_property(timer_bar, "value", 0.0, Constants.SHOT_SELECTION_TIMEOUT)

func _select_shot(shot: int) -> void:
	if not is_waiting_for_input:
		return
	is_waiting_for_input = false
	shot_panel.visible = false
	delivery_alert.visible = false
	selection_timer.stop()
	AudioManager.play_click()
	MatchEngine.receive_shot_input(shot)

func _on_selection_timeout() -> void:
	# Auto-select defensive block if timeout — you froze!
	_select_shot(Constants.ShotType.DEFENSIVE_BLOCK)

# ═══════════════════════════════════════
# BOWL SELECTION (Full Match — 2nd innings)
# ═══════════════════════════════════════
func _show_bowl_selection() -> void:
	is_waiting_for_bowl = true
	_pending_bowl = -1
	bowl_panel.visible = true
	delivery_alert.visible = false
	bowl_grid.visible = true
	bowl_locked.visible = false
	btn_bowl_ready.visible = false
	if MatchEngine.hotseat and GameManager.bowling_team:
		bowl_title.text = "🎳 %s — PICK A DELIVERY (in secret!)" % GameManager.bowling_team.team_name.to_upper()
	bowl_options = _bowl_options_for(GameManager.current_bowler)
	for i in range(4):
		var btn = [btn_bowl_1, btn_bowl_2, btn_bowl_3, btn_bowl_4][i]
		if i < bowl_options.size():
			btn.visible = true
			btn.text = _bowl_label(bowl_options[i], i)
		else:
			btn.visible = false
	bowl_timer_bar.value = 100.0
	var tw = create_tween()
	tw.tween_property(bowl_timer_bar, "value", 0.0, Constants.SHOT_SELECTION_TIMEOUT)
	bowl_timer.start()

func _select_bowl(idx: int) -> void:
	if not is_waiting_for_bowl or idx >= bowl_options.size():
		return
	AudioManager.play_click()
	if MatchEngine.hotseat:
		# Hot-seat secrecy: lock the choice in, hide the options, and hand
		# the device over. The delivery is only revealed on Ready.
		_pending_bowl = idx
		is_waiting_for_bowl = false
		bowl_timer.stop()
		bowl_grid.visible = false
		var bat := GameManager.batting_team.team_name if GameManager.batting_team else "Batting player"
		bowl_locked.text = "🔒 Delivery locked — pass to %s!" % bat
		bowl_locked.visible = true
		btn_bowl_ready.visible = true
		return
	is_waiting_for_bowl = false
	bowl_panel.visible = false
	bowl_timer.stop()
	MatchEngine.receive_bowl_input(bowl_options[idx])

func _on_bowl_ready() -> void:
	# Hot-seat handoff complete — reveal the locked-in delivery.
	if _pending_bowl < 0 or _pending_bowl >= bowl_options.size():
		return
	AudioManager.play_click()
	bowl_panel.visible = false
	bowl_locked.visible = false
	btn_bowl_ready.visible = false
	MatchEngine.receive_bowl_input(bowl_options[_pending_bowl])
	_pending_bowl = -1

func _on_bowl_timeout() -> void:
	# Hesitated — random delivery it is.
	_select_bowl(_rng_i(0, bowl_options.size() - 1))

func _bowl_options_for(bowler: PlayerData) -> Array[int]:
	if bowler.bowling_type == "SPIN":
		return [Constants.DeliveryType.OFF_SPIN, Constants.DeliveryType.LEG_SPIN, Constants.DeliveryType.SLOWER]
	return [Constants.DeliveryType.YORKER, Constants.DeliveryType.BOUNCER, Constants.DeliveryType.FULL_TOSS, Constants.DeliveryType.SLOWER]

func _bowl_label(delivery: int, idx: int) -> String:
	match delivery:
		Constants.DeliveryType.YORKER: return "🎯 [%d] Yorker" % (idx + 1)
		Constants.DeliveryType.BOUNCER: return "⚡ [%d] Short Ball" % (idx + 1)
		Constants.DeliveryType.FULL_TOSS: return "🎈 [%d] Full Toss" % (idx + 1)
		Constants.DeliveryType.OFF_SPIN: return "🌀 [%d] Off Spin" % (idx + 1)
		Constants.DeliveryType.LEG_SPIN: return "🌀 [%d] Leg Break" % (idx + 1)
		Constants.DeliveryType.SLOWER: return "🐢 [%d] Slower Ball" % (idx + 1)
		_: return "[%d] Delivery" % (idx + 1)

# ═══════════════════════════════════════
# DRS REVIEW
# ═══════════════════════════════════════
func _show_drs_review(wtype: String, reviews_left: int) -> void:
	var who := ""
	if MatchEngine.hotseat and GameManager.batting_team:
		who = GameManager.batting_team.team_name + " — "
	lbl_drs_info.text = "%s%s — %d review%s left" % [who, wtype, reviews_left, "" if reviews_left == 1 else "s"]
	drs_popup.visible = true
	drs_timer_bar.value = 100.0
	var tw = create_tween()
	tw.tween_property(drs_timer_bar, "value", 0.0, DRS_REVIEW_WINDOW)
	drs_timer.start()

func _select_drs(should_review: bool) -> void:
	if not drs_popup.visible:
		return
	drs_popup.visible = false
	drs_timer.stop()
	AudioManager.play_click()
	MatchEngine.receive_drs_input(should_review)

func _on_drs_timeout() -> void:
	# Hesitated too long — no review.
	_select_drs(false)

# ═══════════════════════════════════════
# FAST FORWARD
# ═══════════════════════════════════════
func _on_ff_toggled(pressed: bool) -> void:
	MatchEngine.fast_forward = pressed
	btn_ff.text = "▶️" if pressed else "⏩"

# Route a resolved ball to the field view + milestone fireworks.
func _on_field_outcome(outcome: Dictionary) -> void:
	if field_view == null:
		return
	field_view.play_outcome(outcome)
	
	# Milestone fireworks: batsman 50/100, bowler fifer, hat-trick
	var milestone = outcome.get("milestone", "")
	if milestone == "FIFTY" or milestone == "HUNDRED":
		field_view.play_fireworks()
	if outcome.get("bowl_milestone", "") == "FIFER":
		field_view.play_fireworks()
	if outcome.get("hat_trick_completed", false):
		field_view.play_fireworks()
	
	# Partnership 50 / 100 (once per partnership)
	var p_runs = GameManager.get_partnership_runs()
	if p_runs >= 100 and _partnership_milestone_shown < 100:
		_partnership_milestone_shown = 100
		field_view.play_fireworks()
	elif p_runs >= 50 and _partnership_milestone_shown < 50:
		_partnership_milestone_shown = 50
		field_view.play_fireworks()

func _rng_i(a: int, b: int) -> int:
	return randi_range(a, b)

func _on_ball_result(outcome: Dictionary) -> void:
	_update_display()
	_add_over_dot(outcome)
	_show_commentary(outcome)

func _update_display() -> void:
	if GameManager.batting_team == null:
		return
	
	# Top bar
	lbl_batting_team.text = GameManager.batting_team.team_name
	lbl_score.text = str(GameManager.state.get("total_runs", 0)) + "/" + str(GameManager.state.get("total_wickets", 0))
	lbl_overs.text = "(" + GameManager.get_current_over_string() + ")"
	lbl_format.text = "T20" if GameManager.state.get("format", 0) == Constants.MatchFormat.T20 else "ODI"
	lbl_bowling_team.text = GameManager.bowling_team.team_name
	
	# Target info
	if not GameManager.state.get("is_first_innings", true):
		var needed = GameManager.state.get("target", 0) - GameManager.state.get("total_runs", 0)
		var balls_rem = (GameManager.state.get("max_overs", 20) * 6) - (GameManager.state.get("current_over", 0) * 6 + GameManager.state.get("current_ball", 0))
		lbl_target_info.text = "Need: " + str(needed) + " off " + str(balls_rem) + " balls"
	else:
		lbl_target_info.text = ""
	
	# Striker
	if GameManager.striker:
		var s = GameManager.striker
		var form_icon = "🔥" if s.form > Constants.HOT_FORM_THRESHOLD else ("❄️" if s.form < Constants.COLD_FORM_THRESHOLD else "")
		lbl_striker.text = "► " + s.player_name + " *  " + str(s.match_runs) + "(" + str(s.match_balls) + ")  " + str(s.match_fours) + "x4  " + str(s.match_sixes) + "x6  SR:" + str(snapped(s.get_strike_rate(), 0.1)) + "  " + form_icon
	
	# Non-striker
	if GameManager.non_striker:
		var n = GameManager.non_striker
		lbl_non_striker.text = "  " + n.player_name + "  " + str(n.match_runs) + "(" + str(n.match_balls) + ")"
	
	# Bowler
	if GameManager.current_bowler:
		var b = GameManager.current_bowler
		var rhythm_icon = "🔥" if b.rhythm > Constants.HIGH_RHYTHM_THRESHOLD else ("💨" if b.rhythm < Constants.LOW_RHYTHM_THRESHOLD else "")
		lbl_bowler.text = "► " + b.player_name + "  " + str(b.match_overs_bowled) + "-" + str(b.match_maidens) + "-" + str(b.match_runs_conceded) + "-" + str(b.match_wickets) + "  Eco:" + str(snapped(b.get_economy(), 0.1)) + "  " + rhythm_icon
	
	# Partnership & rates
	lbl_crr.text = "CRR: " + str(snapped(GameManager.get_current_run_rate(), 0.01))
	lbl_rrr.text = "RRR: " + str(snapped(GameManager.get_required_run_rate(), 0.01))
	lbl_partnership.text = "Partnership: " + str(GameManager.get_partnership_runs())
	
	# Status bar
	lbl_weather.text = "☁️ " + _weather_pitch.get_weather_name(GameManager.weather)
	lbl_pitch.text = "🏟️ " + _weather_pitch.get_pitch_name(GameManager.pitch_type)
	lbl_pressure.text = "📊 Pressure: " + str(snapped(GameManager.batting_pressure * 100, 1)) + "%"
	var max_reviews = GameManager.get_max_reviews()
	lbl_drs.text = "DRS: " + "🟢".repeat(GameManager.drs_reviews_batting) + "🔴".repeat(maxi(0, max_reviews - GameManager.drs_reviews_batting))
	
	# Momentum bar
	var mom = GameManager.momentum
	if mom > 0.1:
		lbl_momentum.text = "⚡ " + GameManager.batting_team.team_name
	elif mom < -0.1:
		lbl_momentum.text = "⚡ " + GameManager.bowling_team.team_name
	else:
		lbl_momentum.text = "⚡ Even"

func _add_over_dot(outcome: Dictionary) -> void:
	var dot_label = Label.new()
	var runs = outcome.get("runs", 0)
	
	if outcome.get("is_wicket", false):
		dot_label.text = " W "
		dot_label.add_theme_color_override("font_color", Constants.COLOR_WICKET_RED)
	elif outcome.get("is_wide", false):
		dot_label.text = " Wd"
		dot_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SECONDARY)
	elif outcome.get("is_no_ball", false):
		dot_label.text = " Nb"
		dot_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SECONDARY)
	elif runs == 0:
		dot_label.text = " ● "
		dot_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SECONDARY)
	elif runs == 4:
		dot_label.text = " ④ "
		dot_label.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GREEN)
	elif runs == 6:
		dot_label.text = " ⑥ "
		dot_label.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GOLD)
	else:
		dot_label.text = " " + str(runs) + " "
		dot_label.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GREEN)
	
	over_dots_container.add_child(dot_label)

func _show_commentary(outcome: Dictionary) -> void:
	var key = outcome.get("commentary_key", "DOT")
	var ctx = {}
	if key == "WICKET":
		ctx["wicket_type"] = outcome.get("wicket_type", "BOWLED")
	var text = CommentaryManager.get_commentary(key, ctx)
	
	# Dropped catch flavor — name the culprit
	if key == "DROPPED_CATCH":
		var culprit = outcome.get("dropped_by", "")
		if culprit != "":
			text = "DROPPED by " + culprit + "! " + text
	# Boundary zone flavor ("raced away through the covers")
	if key == "FOUR" and outcome.has("zone"):
		var zname = Constants.ZONE_NAMES.get(outcome["zone"], "")
		if zname != "":
			text += " Raced away through " + zname + "!"
	
	# DRS review outcomes
	if key == "DRS_NOT_OUT":
		if outcome.get("drs_commentary", "") != "":
			text += "\n" + outcome.get("drs_commentary", "")
	elif key == "WICKET" and outcome.get("drs_reviewed", false):
		text += "\n" + CommentaryManager.get_commentary("DRS_LOST")
	
	# Dismissal display text ("c Fielder b Bowler")
	if key == "WICKET" and outcome.get("dismissal_display", "") != "":
		text += "\n(" + outcome.get("dismissal_display", "") + ")"
	
	# Hat-trick completed!
	if outcome.get("hat_trick_completed", false):
		text += "\n🏆 " + CommentaryManager.get_commentary("HAT_TRICK_BALL")
	
	# Add delivery and shot info
	var del_name = outcome.get("delivery_name", "")
	var shot_name = outcome.get("shot_name", "")
	if del_name != "" and shot_name != "":
		text = del_name + " → " + shot_name + "  |  " + text
	
	# Milestone commentary
	var milestone = outcome.get("milestone", "")
	if milestone == "FIFTY":
		text += "\n" + CommentaryManager.get_commentary("MILESTONE_50")
	elif milestone == "HUNDRED":
		text += "\n" + CommentaryManager.get_commentary("MILESTONE_100")
	
	var bowl_milestone = outcome.get("bowl_milestone", "")
	if bowl_milestone == "FIFER":
		text += "\n" + CommentaryManager.get_commentary("FIFER")
	
	# Close finish
	if outcome.get("close_finish", false):
		text += "\n" + CommentaryManager.get_commentary("CLOSE_FINISH")
	
	# In the zone
	if outcome.get("in_the_zone", false):
		text += "\n" + CommentaryManager.get_commentary("IN_THE_ZONE")
	
	# Color coding
	if key == "WICKET":
		commentary_label.add_theme_color_override("font_color", Constants.COLOR_WICKET_RED)
	elif key in ["FOUR", "SIX", "DRS_NOT_OUT"]:
		commentary_label.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GREEN)
	elif key == "DROPPED_CATCH":
		commentary_label.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GOLD)
	else:
		commentary_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_PRIMARY)
	
	# Typewriter effect
	commentary_label.text = text
	commentary_label.visible_characters = 0
	if commentary_tween:
		commentary_tween.kill()
	commentary_tween = create_tween()
	commentary_tween.tween_property(commentary_label, "visible_characters", text.length(), text.length() * Constants.TYPEWRITER_SPEED)

func _on_over_ended(summary: Dictionary) -> void:
	# Clear over dots
	for child in over_dots_container.get_children():
		child.queue_free()
	
	# Show summary popup
	over_summary_popup.visible = true
	var text = "END OF OVER " + str(summary.get("over_number", 0))
	text += "\n" + summary.get("bowler", "") + ": " + str(summary.get("runs", 0)) + " runs, " + str(summary.get("wickets", 0)) + " wickets"
	text += "\nEconomy: " + str(snapped(summary.get("economy", 0.0), 0.01))
	
	# Over event flavor
	for ev in summary.get("events", []):
		match ev:
			"MAIDEN":
				text += "\n🎯 " + CommentaryManager.get_commentary("MAIDEN")
			"BIG_OVER":
				text += "\n💥 " + CommentaryManager.get_commentary("CROWD_SIX")
			"WEATHER_CHANGE":
				text += "\n" + CommentaryManager.get_commentary("WEATHER_CHANGE") + " (Now: " + _weather_pitch.get_weather_name(GameManager.weather) + ")"
			"DRINKS_BREAK":
				text += "\n🥤 Drinks break — players refresh."
	lbl_over_summary.text = text
	AudioManager.play_click()
	
	await get_tree().create_timer(0.3 if MatchEngine.fast_forward else 2.0).timeout
	over_summary_popup.visible = false

func _on_second_innings_starting() -> void:
	# Show innings break overlay
	innings_break_popup.visible = true
	var target = GameManager.state.get("total_runs", 0) + 1
	var tail = "AI batting in progress..."
	if MatchEngine.is_human_bowling:
		tail = "AI batting — you bowl!"
	lbl_innings_break.text = "INNINGS BREAK\n\n" + GameManager.bowling_team.team_name + " need " + str(target) + " to win!\n\n" + tail
	
	await get_tree().create_timer(0.5 if MatchEngine.fast_forward else 3.0).timeout
	innings_break_popup.visible = false

# Field-view side of the innings break: fresh wagon wheel + partnership tracker.
func _on_second_innings_for_field() -> void:
	if field_view:
		field_view.clear_wagon()
	_partnership_milestone_shown = 0

# Super over round: banner + fresh wagon wheel for the shootout.
func _on_super_over_for_field(round_no: int) -> void:
	if field_view:
		field_view.clear_wagon()
	_partnership_milestone_shown = 0
	innings_break_popup.visible = true
	var msg := "⚡ SUPER OVER ⚡\n\nScores level — sudden death!\n\n%s bat first" % GameManager.batting_team.team_name
	if round_no > 1:
		msg = "⚡ SUPER OVER %d ⚡\n\nTied again — sudden death!\n\n%s bat first" % [round_no, GameManager.batting_team.team_name]
	lbl_innings_break.text = msg
	await get_tree().create_timer(0.5 if MatchEngine.fast_forward else 2.5).timeout
	innings_break_popup.visible = false

func _on_innings_ended(scorecard: Dictionary) -> void:
	# Don't transition away — MatchEngine handles the flow
	# Just update the display
	_update_display()

func _on_match_ended(winner: String) -> void:
	await get_tree().create_timer(1.5).timeout
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	GameManager.set_meta("match_winner", winner)
	GameManager.set_meta("last_scorecard", GameManager._build_scorecard())
	get_tree().change_scene_to_file("res://scenes/ui/Scorecard.tscn")
