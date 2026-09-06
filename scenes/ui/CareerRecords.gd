# CareerRecords.gd — All-time batting/bowling tables from CareerManager.
extends Control

@onready var bat_rows := $Scroll/VBox/BatPanel/BatVBox
@onready var bowl_rows := $Scroll/VBox/BowlPanel/BowlVBox
@onready var lbl_empty := $Scroll/VBox/EmptyLabel
@onready var btn_back := $BottomBar/BtnBack
@onready var btn_reset := $BottomBar/BtnReset

const BAT_COLS := ["BATSMAN", "TEAM", "M", "RUNS", "50s", "100s", "SR", "BEST"]
const BAT_W := [190, 130, 36, 56, 40, 44, 62, 52]
const BOWL_COLS := ["BOWLER", "TEAM", "M", "WKTS", "CATCH", "BEST"]
const BOWL_W := [190, 130, 36, 48, 52, 64]

func _ready() -> void:
	modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Constants.SCENE_FADE_DURATION)
	btn_back.pressed.connect(_on_back)
	btn_reset.pressed.connect(_on_reset)
	CareerManager.career_updated.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for c in bat_rows.get_children():
		c.queue_free()
	for c in bowl_rows.get_children():
		c.queue_free()
	var bat := CareerManager.batting_table()
	var bowl := CareerManager.bowling_table()
	lbl_empty.visible = bat.is_empty() and bowl.is_empty()
	if not bat.is_empty():
		_add_header_row(bat_rows, BAT_COLS, BAT_W)
		for r in bat:
			var e: Dictionary = r["data"]
			_add_row(bat_rows, BAT_W, [
				r["name"], str(e.get("team", "")),
				str(e.get("matches", 0)), str(e.get("runs", 0)),
				str(e.get("fifties", 0)), str(e.get("hundreds", 0)),
				"%.1f" % CareerManager.strike_rate(e),
				str(e.get("best_runs", 0)) + "*",
			], false)
	if not bowl.is_empty():
		_add_header_row(bowl_rows, BOWL_COLS, BOWL_W)
		for r in bowl:
			var e: Dictionary = r["data"]
			_add_row(bowl_rows, BOWL_W, [
				r["name"], str(e.get("team", "")),
				str(e.get("matches", 0)), str(e.get("wickets", 0)),
				str(e.get("catches", 0)),
				"%d/%d" % [int(e.get("best_wkts", 0)), int(e.get("best_bowl_runs", 0))],
			], false)

func _add_header_row(parent: Control, cols: Array, widths: Array) -> void:
	_add_row(parent, widths, cols, true)

func _add_row(parent: Control, widths: Array, cols: Array, is_header: bool) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	for i in range(cols.size()):
		var lbl := Label.new()
		lbl.text = str(cols[i])
		lbl.custom_minimum_size.x = widths[i]
		lbl.clip_text = true
		if is_header:
			lbl.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GOLD)
			lbl.add_theme_font_size_override("font_size", 12)
		else:
			lbl.add_theme_color_override("font_color", Constants.COLOR_TEXT_PRIMARY)
			lbl.add_theme_font_size_override("font_size", 12)
		hb.add_child(lbl)
	parent.add_child(hb)

func _on_reset() -> void:
	CareerManager.reset()
	AudioManager.play_click()

func _on_back() -> void:
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
