# TeamSelect.gd — Team selection screen before a quick match.
extends Control

var selected_team_a: int = 0
var selected_team_b: int = 1

@onready var team_a_list := $HBoxContainer/TeamAPanel/TeamAList
@onready var team_b_list := $HBoxContainer/TeamBPanel/TeamBList
@onready var btn_start := $BtnStart
@onready var btn_back := $BtnBack

func _ready() -> void:
	modulate.a = 0.0
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Constants.SCENE_FADE_DURATION)
	
	_populate_teams()
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

func _on_start() -> void:
	if selected_team_a == selected_team_b:
		return  # Can't play same team
	var team_a = GameManager.all_teams[selected_team_a]
	var team_b = GameManager.all_teams[selected_team_b]
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	MatchEngine.start_match(team_a, team_b, Constants.MatchFormat.T20, true, false)
	get_tree().change_scene_to_file("res://scenes/ui/MatchHUD.tscn")

func _on_back() -> void:
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
