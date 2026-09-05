# TeamSelect.gd — Team selection screen before a quick match.
extends Control

var selected_team_a: int = 0
var selected_team_b: int = 1
var selected_format: int = Constants.MatchFormat.T20
var full_match: bool = false

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
	mode_btn.selected = 0
	mode_btn.item_selected.connect(func(idx: int) -> void:
		full_match = mode_btn.get_item_id(idx) == 1
	)

func _on_start() -> void:
	if selected_team_a == selected_team_b:
		warning_label.visible = true
		return
	warning_label.visible = false
	var team_a = GameManager.all_teams[selected_team_a]
	var team_b = GameManager.all_teams[selected_team_b]
	var fade = create_tween()
	fade.tween_property(self, "modulate.a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	# Full Match: human plays both their team's innings (bat + bowl).
	# Bat vs AI: human bats, bowling is auto-simmed.
	GameManager.return_scene = "res://scenes/ui/MainMenu.tscn"
	MatchEngine.start_match(team_a, team_b, selected_format, team_a, full_match)
	get_tree().change_scene_to_file("res://scenes/ui/MatchHUD.tscn")

func _on_back() -> void:
	var fade = create_tween()
	fade.tween_property(self, "modulate.a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
