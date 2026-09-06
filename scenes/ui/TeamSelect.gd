# TeamSelect.gd — Team selection screen before a quick match.
extends Control

var selected_team_a: int = 0
var selected_team_b: int = 1
var selected_format: int = Constants.MatchFormat.T20
var full_match: bool = false
var hotseat_mode: bool = false

@onready var team_a_list := $HBoxContainer/TeamAPanel/TeamAList
@onready var team_b_list := $HBoxContainer/TeamBPanel/TeamBList
@onready var format_btn := $SetupRow/FormatBtn
@onready var mode_btn := $SetupRow/ModeBtn
@onready var warning_label := $WarningLabel
@onready var btn_start := $BtnStart
@onready var btn_back := $BtnBack

func _ready() -> void:
	modulate.a = 0.0
	var fade = create_tween()
	fade.tween_property(self, "modulate.a", 1.0, Constants.SCENE_FADE_DURATION)
	
	_populate_teams()
	_populate_options()
	btn_start.pressed.connect(_on_start)
	btn_back.pressed.connect(_on_back)

func _populate_teams() -> void:
	for i in range(GameManager.all_teams.size()):
		var t = GameManager.all_teams[i]
		team_a_list.add_item(t.team_name)
		team_b_list.add_item(t.team_name)
	team_a_list.select(0)
	team_b_list.select(1)
	team_a_list.item_selected.connect(func(idx): selected_team_a = idx)
	team_b_list.item_selected.connect(func(idx): selected_team_b = idx)

func _populate_options() -> void:
	format_btn.clear()
	format_btn.add_item("T20", Constants.MatchFormat.T20)
	format_btn.add_item("ODI", Constants.MatchFormat.ODI)
	format_btn.selected = selected_format
	format_btn.item_selected.connect(func(idx: int) -> void:
		selected_format = format_btn.get_item_id(idx)
	)
	
	mode_btn.clear()
	mode_btn.add_item("Bat vs AI", 0)
	mode_btn.add_item("Full Match (Bat + Bowl)", 1)
	mode_btn.add_item("Hot-Seat (2 Players)", 2)
	mode_btn.selected = 0
	mode_btn.item_selected.connect(func(idx: int) -> void:
		var id: int = mode_btn.get_item_id(idx)
		full_match = id == 1
		hotseat_mode = id == 2
	)

func _on_start() -> void:
	if selected_team_a == selected_team_b:
		warning_label.visible = true
		return
	warning_label.visible = false
	AudioManager.play_click()
	var team_a = GameManager.all_teams[selected_team_a]
	var team_b = GameManager.all_teams[selected_team_b]
	var fade = create_tween()
	fade.tween_property(self, "modulate.a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	# Route through the XI picker: it starts the match on confirm.
	GameManager.set_meta("xi_team", team_a)
	GameManager.set_meta("xi_return", "res://scenes/ui/TeamSelect.tscn")
	GameManager.set_meta("xi_start_match", true)
	GameManager.set_meta("xi_team_b", team_b)
	GameManager.set_meta("xi_bat_first", team_a)
	GameManager.set_meta("xi_format", selected_format)
	GameManager.set_meta("xi_full", full_match)
	GameManager.set_meta("xi_hotseat", hotseat_mode)
	GameManager.set_meta("xi_hotseat_b_done", false)
	get_tree().change_scene_to_file("res://scenes/ui/XIPicker.tscn")

func _on_back() -> void:
	AudioManager.play_click()
	var fade = create_tween()
	fade.tween_property(self, "modulate.a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
