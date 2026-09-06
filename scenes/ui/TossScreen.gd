# TossScreen.gd — Coin toss before a match: call heads/tails, choose bat/bowl.
extends Control

@onready var lbl_title := $Title
@onready var lbl_home := $Teams/HomeTeam
@onready var lbl_vs := $Teams/VS
@onready var lbl_away := $Teams/AwayTeam
@onready var coin := $Coin
@onready var lbl_result := $Result
@onready var btn_heads := $CallRow/BtnHeads
@onready var btn_tails := $CallRow/BtnTails
@onready var choice_row := $ChoiceRow
@onready var btn_bat := $ChoiceRow/BtnBat
@onready var btn_bowl := $ChoiceRow/BtnBowl
@onready var btn_back := $StartRow/BtnBack
@onready var btn_start := $StartRow/BtnStart

var home: TeamData = null
var away: TeamData = null
var human: TeamData = null
var fixture_kind: String = "group"
var toss_winner: TeamData = null
var human_called := false
var toss_result := ""   # "HEADS" / "TAILS"
var bats_first: TeamData = null

func _ready() -> void:
	modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Constants.SCENE_FADE_DURATION)
	
	home = GameManager.get_meta("toss_home")
	away = GameManager.get_meta("toss_away")
	human = GameManager.get_meta("toss_human")
	if GameManager.has_meta("toss_fixture"):
		fixture_kind = str(GameManager.get_meta("toss_fixture"))
	if home == null or away == null:
		# Opened outside the tournament flow — nothing to toss for.
		lbl_home.text = "—"
		lbl_away.text = "—"
		lbl_result.text = "No fixture loaded."
		btn_heads.disabled = true
		btn_tails.disabled = true
		return
	
	lbl_home.text = home.team_name
	lbl_away.text = away.team_name
	
	btn_heads.pressed.connect(func(): _make_call("HEADS"))
	btn_tails.pressed.connect(func(): _make_call("TAILS"))
	btn_bat.pressed.connect(_choose_bat)
	btn_bowl.pressed.connect(_choose_bowl)
	btn_back.pressed.connect(_on_back)
	btn_start.pressed.connect(_start_match)
	
	choice_row.visible = false
	btn_start.visible = false
	lbl_result.text = ""
	
	# Spin the coin idly
	coin.text = "🪙"

func _make_call(call: String) -> void:
	human_called = true
	toss_result = "HEADS" if randf() < 0.5 else "TAILS"
	var human_won := (call == toss_result)
	toss_winner = human if human_won else (away if human == home else home)
	btn_heads.visible = false
	btn_tails.visible = false
	lbl_result.text = "%s! %s won the toss" % [toss_result, toss_winner.team_name]
	# Animate the coin flip
	var tw := create_tween()
	tw.tween_property(coin, "scale", Vector2(1.6, 1.6), 0.2).set_trans(Tween.TRANS_BACK)
	tw.tween_property(coin, "scale", Vector2(1.0, 1.0), 0.2)
	tw.tween_callback(func() -> void:
		coin.text = "🪙"
		_after_toss())
	AudioManager.play_click()

func _after_toss() -> void:
	if toss_winner == human:
		# Human won the toss — they choose
		choice_row.visible = true
		lbl_result.text += "  —  you choose!"
	else:
		# AI decides: strong teams prefer chasing in T20
		var ai_bats_first: bool = randf() < 0.3
		bats_first = toss_winner if ai_bats_first else (away if toss_winner == home else home)
		lbl_result.text += "  —  %s will bat first" % bats_first.team_name
		btn_start.visible = true
		btn_start.text = "▶ Start Match"

func _choose_bat() -> void:
	bats_first = human
	_choice_made()

func _choose_bowl() -> void:
	bats_first = away if human == home else home
	_choice_made()

func _choice_made() -> void:
	choice_row.visible = false
	lbl_result.text = "%s won the toss — %s bat first" % [toss_winner.team_name, bats_first.team_name]
	btn_start.visible = true
	btn_start.text = "▶ Start Match"
	AudioManager.play_click()

func _on_back() -> void:
	# Toss is only reachable from the tournament flow — cancel back to the Hub.
	# (Safe at any point: no match has started, nothing to clean up.)
	AudioManager.play_click()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/ui/TournamentHub.tscn")

func _start_match() -> void:
	# Stash the fixture context so the Hub records the result when we return.
	GameManager.set_meta("pending_fixture_result", {
		"kind": fixture_kind,
		"home": home.team_name,
		"away": away.team_name,
	})
	# Start with the toss winners' chosen batting order, routing back to the Hub.
	GameManager.return_scene = "res://scenes/ui/TournamentHub.tscn"
	var batting = bats_first
	var bowling = away if batting == home else home
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	MatchEngine.start_match(batting, bowling, Constants.MatchFormat.T20, human, true)
	get_tree().change_scene_to_file("res://scenes/ui/MatchHUD.tscn")
