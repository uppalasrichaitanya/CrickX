# Settings.gd — Settings scene with volume, difficulty, and fullscreen controls.
extends Control

@onready var master_slider := $PanelContainer/VBoxContainer/MasterVolume/HSlider
@onready var master_value := $PanelContainer/VBoxContainer/MasterVolume/ValueLabel
@onready var sfx_slider := $PanelContainer/VBoxContainer/SFXVolume/HSlider
@onready var sfx_value := $PanelContainer/VBoxContainer/SFXVolume/ValueLabel
@onready var difficulty_btn := $PanelContainer/VBoxContainer/Difficulty/OptionButton
@onready var fullscreen_check := $PanelContainer/VBoxContainer/Fullscreen/CheckButton
@onready var btn_back := $PanelContainer/VBoxContainer/BtnBack

func _ready() -> void:
	modulate.a = 0.0
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Constants.SCENE_FADE_DURATION)
	
	master_slider.value = GameManager.master_volume * 100.0
	sfx_slider.value = GameManager.sfx_volume * 100.0
	master_value.text = "%d%%" % int(GameManager.master_volume * 100.0)
	sfx_value.text = "%d%%" % int(GameManager.sfx_volume * 100.0)
	fullscreen_check.button_pressed = GameManager.is_fullscreen
	
	difficulty_btn.clear()
	difficulty_btn.add_item("Easy (%s to react)" % Constants.human_timeout_label(Constants.Difficulty.EASY), Constants.Difficulty.EASY)
	difficulty_btn.add_item("Medium (%s to react)" % Constants.human_timeout_label(Constants.Difficulty.MEDIUM), Constants.Difficulty.MEDIUM)
	difficulty_btn.add_item("Hard (%s to react)" % Constants.human_timeout_label(Constants.Difficulty.HARD), Constants.Difficulty.HARD)
	difficulty_btn.selected = GameManager.difficulty
	difficulty_btn.tooltip_text = "Reaction time per ball: how long you get to pick a shot or delivery"
	
	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	difficulty_btn.item_selected.connect(_on_difficulty_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	btn_back.pressed.connect(_on_back)

func _on_master_changed(val: float) -> void:
	GameManager.master_volume = val / 100.0
	master_value.text = "%d%%" % int(val)
	AudioManager.set_master_volume(GameManager.master_volume)
	GameManager.save_settings()

func _on_sfx_changed(val: float) -> void:
	GameManager.sfx_volume = val / 100.0
	sfx_value.text = "%d%%" % int(val)
	AudioManager.set_sfx_volume(GameManager.sfx_volume)
	GameManager.save_settings()

func _on_difficulty_changed(idx: int) -> void:
	GameManager.difficulty = difficulty_btn.get_item_id(idx)
	GameManager.save_settings()  # persist immediately — a crash must not lose it
	AudioManager.play_click()

func _on_fullscreen_toggled(pressed: bool) -> void:
	GameManager.is_fullscreen = pressed
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back() -> void:
	GameManager.save_settings()
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
