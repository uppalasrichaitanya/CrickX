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

# ─── Status indicators ───
@onready var lbl_weather := $StatusBar/Weather
@onready var lbl_pitch := $StatusBar/Pitch
@onready var lbl_pressure := $StatusBar/Pressure
@onready var lbl_momentum := $StatusBar/Momentum
@onready var lbl_drs := $StatusBar/DRS

# ─── Over Summary Popup ───
@onready var over_summary_popup := $OverSummaryPopup
@onready var lbl_over_summary := $OverSummaryPopup/Content

# ─── Innings Break Popup ───
@onready var innings_break_popup := $InningsBreakPopup
@onready var lbl_innings_break := $InningsBreakPopup/BreakContent

var selection_timer: Timer = null
var is_waiting_for_input: bool = false

func _ready() -> void:
	modulate.a = 0.0
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Constants.SCENE_FADE_DURATION)
	
	# Connect signals from MatchEngine
	MatchEngine.ball_result_ready.connect(_on_ball_result)
	MatchEngine.request_shot_selection.connect(_show_shot_selection)
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
	
	# Selection timer (4 seconds to react)
	selection_timer = Timer.new()
	selection_timer.wait_time = 4.0
	selection_timer.one_shot = true
	selection_timer.timeout.connect(_on_selection_timeout)
	add_child(selection_timer)
	
	shot_panel.visible = false
	over_summary_popup.visible = false
	delivery_alert.visible = false
	innings_break_popup.visible = false
	
	_update_display()

func _unhandled_input(event: InputEvent) -> void:
	if not is_waiting_for_input:
		return
	if event.is_action_pressed("shot_1"): _select_shot(Constants.ShotType.AGGRESSIVE_DRIVE)
	elif event.is_action_pressed("shot_2"): _select_shot(Constants.ShotType.PULL_SHOT)
	elif event.is_action_pressed("shot_3"): _select_shot(Constants.ShotType.SWEEP_SHOT)
	elif event.is_action_pressed("shot_4"): _select_shot(Constants.ShotType.LOFT_SLOG)
	elif event.is_action_pressed("shot_5"): _select_shot(Constants.ShotType.DEFENSIVE_BLOCK)
	elif event.is_action_pressed("shot_6"): _select_shot(Constants.ShotType.LEAVE_BALL)

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
	
	timer_bar.value = 100.0
	selection_timer.start()
	# Animate timer bar (4 seconds)
	var tw = create_tween()
	tw.tween_property(timer_bar, "value", 0.0, 4.0)

func _select_shot(shot: int) -> void:
	if not is_waiting_for_input:
		return
	is_waiting_for_input = false
	shot_panel.visible = false
	delivery_alert.visible = false
	selection_timer.stop()
	MatchEngine.receive_shot_input(shot)

func _on_selection_timeout() -> void:
	# Auto-select defensive block if timeout — you froze!
	_select_shot(Constants.ShotType.DEFENSIVE_BLOCK)

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
	var ws = WeatherPitchSystem.new()
	lbl_weather.text = "☁️ " + ws.get_weather_name(GameManager.weather)
	lbl_pitch.text = "🏟️ " + ws.get_pitch_name(GameManager.pitch_type)
	lbl_pressure.text = "📊 Pressure: " + str(snapped(GameManager.batting_pressure * 100, 1)) + "%"
	lbl_drs.text = "DRS: " + "🟢".repeat(GameManager.drs_reviews_batting) + "🔴".repeat(maxi(0, (2 if GameManager.state.get("format", 0) == Constants.MatchFormat.ODI else 1) - GameManager.drs_reviews_batting))
	
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
	elif key in ["FOUR", "SIX"]:
		commentary_label.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GREEN)
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
	lbl_over_summary.text = text
	
	await get_tree().create_timer(2.0).timeout
	over_summary_popup.visible = false

func _on_second_innings_starting() -> void:
	# Show innings break overlay
	innings_break_popup.visible = true
	var target = GameManager.state.get("total_runs", 0) + 1
	lbl_innings_break.text = "INNINGS BREAK\n\n" + GameManager.bowling_team.team_name + " need " + str(target) + " to win!\n\nAI batting in progress..."
	
	await get_tree().create_timer(3.0).timeout
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
