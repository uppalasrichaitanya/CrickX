# XIPicker.gd — Pick a playing XI (11) from the 15-man squad.
# Opened from TeamSelect (Quick Match) or TournamentHub (Squad button).
# Order follows the squad list (batting order). Confirm applies via TeamData.
extends Control

var team: TeamData = null
var return_scene: String = "res://scenes/ui/TeamSelect.tscn"
var start_after_confirm: bool = false   # Quick Match: start the match on confirm
var qm_team_b: TeamData = null
var qm_format: int = 0
var qm_full: bool = false
var qm_hotseat: bool = false

var picked: Array[PlayerData] = []

@onready var title := $Title
@onready var squad_list := $HBox/SquadPanel/SquadList
@onready var xi_list := $HBox/XIPanel/XIList
@onready var xi_label := $HBox/XIPanel/XILabel
@onready var warning := $BottomBar/Warning
@onready var btn_add := $HBox/BtnCol/BtnAdd
@onready var btn_remove := $HBox/BtnCol/BtnRemove
@onready var btn_auto := $HBox/BtnCol/BtnAuto
@onready var btn_back := $BottomBar/BtnBack
@onready var btn_confirm := $BottomBar/BtnConfirm

func _ready() -> void:
	modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Constants.SCENE_FADE_DURATION)
	
	team = GameManager.get_meta("xi_team")
	if team == null:
		_fade_to("res://scenes/ui/MainMenu.tscn")
		return
	if GameManager.has_meta("xi_return"):
		return_scene = str(GameManager.get_meta("xi_return"))
	start_after_confirm = bool(GameManager.get_meta("xi_start_match", false))
	if GameManager.has_meta("xi_team_b"):
		qm_team_b = GameManager.get_meta("xi_team_b")
	if GameManager.has_meta("xi_format"):
		qm_format = int(GameManager.get_meta("xi_format"))
	if GameManager.has_meta("xi_full"):
		qm_full = bool(GameManager.get_meta("xi_full"))
	if GameManager.has_meta("xi_hotseat"):
		qm_hotseat = bool(GameManager.get_meta("xi_hotseat"))
	
	title.text = "PICK %s'S XI" % team.team_name.to_upper()
	# Prefill with the current XI (default or previously picked)
	picked = team.playing_xi.duplicate()
	
	squad_list.item_selected.connect(_on_squad_picked)
	xi_list.item_selected.connect(_on_xi_picked)
	btn_add.pressed.connect(_on_add)
	btn_remove.pressed.connect(_on_remove)
	btn_auto.pressed.connect(_on_auto)
	btn_back.pressed.connect(_on_back)
	btn_confirm.pressed.connect(_on_confirm)
	_refresh()

func _row_text(p: PlayerData) -> String:
	var bowl := p.bowling_type if p.bowling_type != "NONE" else "—"
	var mark := "  ✓" if p in picked else ""
	return "%s   Bat %d   Bowl %d   %s/%s%s" % [p.player_name, p.batting_skill, p.bowling_skill, p.batting_style, bowl, mark]

func _refresh() -> void:
	squad_list.clear()
	for p in team.squad:
		squad_list.add_item(_row_text(p))
	xi_list.clear()
	for p in picked:
		xi_list.add_item(_row_text(p))
	var bowlers := 0
	for p in picked:
		if p.bowling_type != "NONE":
			bowlers += 1
	xi_label.text = "PLAYING XI  (%d/11, bowlers: %d)" % [picked.size(), bowlers]
	var problems := TeamData.validate_xi(picked)
	if problems.is_empty():
		warning.text = "✓ Ready to go"
		btn_confirm.disabled = false
	else:
		warning.text = " • ".join(problems)
		btn_confirm.disabled = true

func _add_selected() -> void:
	var items: Array = squad_list.get_selected_items()
	if items.is_empty():
		return
	var p: PlayerData = team.squad[items[0]]
	if p in picked or picked.size() >= 11:
		return
	# Keep squad order (batting order)
	picked.append(p)
	picked.sort_custom(func(a, b): return team.squad.find(a) < team.squad.find(b))
	squad_list.deselect_all()
	AudioManager.play_click()
	_refresh()

func _remove_selected() -> void:
	var items: Array = xi_list.get_selected_items()
	if items.is_empty():
		return
	picked.remove_at(items[0])
	xi_list.deselect_all()
	AudioManager.play_click()
	_refresh()

func _on_squad_picked(_idx: int) -> void:
	_add_selected()

func _on_xi_picked(_idx: int) -> void:
	_remove_selected()

func _on_add() -> void:
	_add_selected()

func _on_remove() -> void:
	_remove_selected()

func _on_auto() -> void:
	picked.clear()
	for i in range(mini(11, team.squad.size())):
		picked.append(team.squad[i])
	AudioManager.play_click()
	_refresh()

func _on_back() -> void:
	# No changes applied — return where we came from
	_fade_to(return_scene)

func _on_confirm() -> void:
	var problems := team.set_playing_xi(picked)
	if not problems.is_empty():
		warning.text = " • ".join(problems)
		return
	AudioManager.play_click()
	# Persist custom XI into the active tournament save (tournament flow only)
	if TournamentManager.is_active() and TournamentManager.human_team_name == team.team_name:
		TournamentManager.save()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	if start_after_confirm and qm_team_b != null:
		# Hot-seat: team B picks its XI second, then the match starts.
		if qm_hotseat and not bool(GameManager.get_meta("xi_hotseat_b_done", false)):
			GameManager.set_meta("xi_hotseat_b_done", true)
			GameManager.set_meta("xi_team", qm_team_b)
			var fade2 := create_tween()
			fade2.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
			await fade2.finished
			get_tree().change_scene_to_file("res://scenes/ui/XIPicker.tscn")
			return
		GameManager.return_scene = "res://scenes/ui/MainMenu.tscn"
		var bat_first = GameManager.get_meta("xi_bat_first") if GameManager.has_meta("xi_bat_first") else team
		var other = qm_team_b if bat_first == team else team
		var human = null if qm_hotseat else team
		MatchEngine.start_match(bat_first, other, qm_format, human, qm_full, qm_hotseat)
		get_tree().change_scene_to_file("res://scenes/ui/MatchHUD.tscn")
	else:
		get_tree().change_scene_to_file(return_scene)

func _fade_to(scene_path: String) -> void:
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	get_tree().change_scene_to_file(scene_path)
