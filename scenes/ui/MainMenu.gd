# MainMenu.gd — Professional main menu with dark theme and animated elements.
extends Control

@onready var btn_quick_match := $VBoxContainer/BtnQuickMatch
@onready var btn_tournament := $VBoxContainer/BtnTournament
@onready var btn_multiplayer := $VBoxContainer/BtnMultiplayer
@onready var btn_records := $VBoxContainer/BtnRecords
@onready var btn_settings := $VBoxContainer/BtnSettings
@onready var btn_quit := $VBoxContainer/BtnQuit
@onready var anim_ball := $AnimatedBall

var _tween: Tween = null

func _ready() -> void:
	# Fade in
	modulate.a = 0.0
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Constants.SCENE_FADE_DURATION)
	
	# Connect buttons
	btn_quick_match.pressed.connect(_on_quick_match)
	btn_tournament.pressed.connect(_on_tournament)
	btn_multiplayer.pressed.connect(_on_multiplayer)
	btn_records.pressed.connect(_on_records)
	btn_settings.pressed.connect(_on_settings)
	btn_quit.pressed.connect(_on_quit)
	
	# Button hover effects
	for btn in [btn_quick_match, btn_tournament, btn_multiplayer, btn_records, btn_settings, btn_quit]:
		btn.mouse_entered.connect(_on_btn_hover.bind(btn))
		btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
	
	# Start ball rolling animation
	_animate_ball()

func _on_btn_hover(btn: Button) -> void:
	var tw = create_tween()
	tw.tween_property(btn, "modulate", Constants.COLOR_ACCENT_GREEN, 0.2)

func _on_btn_unhover(btn: Button) -> void:
	var tw = create_tween()
	tw.tween_property(btn, "modulate", Color.WHITE, 0.2)

func _animate_ball() -> void:
	if anim_ball == null:
		return
	anim_ball.position = Vector2(-50, 600)
	_tween = create_tween().set_loops()
	_tween.tween_property(anim_ball, "position:x", 1330.0, 8.0)
	_tween.tween_property(anim_ball, "position:x", -50.0, 0.0)

func _fade_to_scene(scene_path: String) -> void:
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	get_tree().change_scene_to_file(scene_path)

func _on_quick_match() -> void:
	_fade_to_scene("res://scenes/ui/TeamSelect.tscn")

func _on_tournament() -> void:
	# Resume a saved tournament if one exists, else start fresh via the hub
	# (the hub shows a team picker when no tournament is active).
	_fade_to_scene("res://scenes/ui/TournamentHub.tscn")

func _on_multiplayer() -> void:
	pass  # Planned: LAN multiplayer (see implementation_plan.md Phase 5)

func _on_records() -> void:
	_fade_to_scene("res://scenes/ui/CareerRecords.tscn")

func _on_settings() -> void:
	_fade_to_scene("res://scenes/ui/Settings.tscn")

func _on_quit() -> void:
	get_tree().quit()
