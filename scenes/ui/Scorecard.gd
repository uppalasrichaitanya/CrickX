# Scorecard.gd — Full scrollable innings scorecard display.
extends Control

@onready var scroll := $ScrollContainer
@onready var content := $ScrollContainer/VBoxContainer
@onready var btn_continue := $BtnContinue
@onready var winner_label := $WinnerLabel

func _ready() -> void:
	modulate.a = 0.0
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Constants.SCENE_FADE_DURATION)
	
	btn_continue.pressed.connect(_on_continue)
	_build_scorecard()

func _build_scorecard() -> void:
	var scorecard = GameManager.get_meta("last_scorecard") if GameManager.has_meta("last_scorecard") else {}
	var winner = GameManager.get_meta("match_winner") if GameManager.has_meta("match_winner") else ""
	
	# Winner display
	if winner != "":
		if GameManager.has_meta("match_tied"):
			winner_label.text = "🤝 MATCH TIED 🤝"
		else:
			winner_label.text = "🏆 " + winner + " WINS! 🏆"
		winner_label.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GOLD)
		# Man of the Match
		var atm = AtmosphereSystem.new()
		var mom = atm.get_man_of_match(GameManager.batting_team, GameManager.bowling_team)
		if mom:
			_add_header("⭐ Man of the Match: " + mom.player_name)
	else:
		winner_label.text = "END OF INNINGS"
	
	# Batting scorecard
	_add_header("BATTING — " + scorecard.get("team_name", ""))
	_add_separator()
	_add_row("Batsman", "Dismissal", "R", "B", "4s", "6s", "SR", true)
	_add_separator()
	
	var batsmen = scorecard.get("batsmen", [])
	for b in batsmen:
		var dismissal = b.get("dismissal", "")
		if not b.get("is_out", false) and b.get("balls", 0) > 0:
			dismissal = "not out"
		elif not b.get("is_out", false):
			dismissal = "DNB"
		_add_row(
			b.get("name", ""),
			dismissal,
			str(b.get("runs", 0)),
			str(b.get("balls", 0)),
			str(b.get("fours", 0)),
			str(b.get("sixes", 0)),
			str(snapped(b.get("sr", 0.0), 0.1)),
			false
		)
	
	# Extras & Total
	var extras = scorecard.get("extras", {})
	var extras_total = extras.get("wides", 0) + extras.get("no_balls", 0) + extras.get("byes", 0)
	_add_separator()
	_add_text("Extras: " + str(extras_total) + " (w:" + str(extras.get("wides", 0)) + " nb:" + str(extras.get("no_balls", 0)) + " b:" + str(extras.get("byes", 0)) + ")")
	_add_text("Total: " + str(scorecard.get("total_runs", 0)) + "/" + str(scorecard.get("total_wickets", 0)) + " (" + str(scorecard.get("total_overs", "0.0")) + " overs)")
	
	# Fall of Wickets
	var fow = scorecard.get("fall_of_wickets", [])
	if fow.size() > 0:
		_add_separator()
		var fow_text = "Fall of Wickets: "
		for i in range(fow.size()):
			fow_text += str(i + 1) + "-" + str(fow[i].get("score", 0)) + "(" + str(fow[i].get("over", "")) + ") "
		_add_text(fow_text)
	
	# Bowling scorecard
	_add_separator()
	_add_header("BOWLING")
	_add_separator()
	_add_row("Bowler", "", "O", "M", "R", "W", "Eco", true)
	_add_separator()
	
	var bowlers = scorecard.get("bowlers", [])
	for b in bowlers:
		_add_row(
			b.get("name", ""),
			"",
			str(b.get("overs", 0)),
			str(b.get("maidens", 0)),
			str(b.get("runs", 0)),
			str(b.get("wickets", 0)),
			str(snapped(b.get("economy", 0.0), 0.01)),
			false
		)
	
	# First innings scorecard (if second innings)
	if GameManager.first_innings_scorecard.size() > 0 and winner != "":
		var fi = GameManager.first_innings_scorecard
		_add_separator()
		_add_separator()
		_add_header("FIRST INNINGS — " + fi.get("team_name", ""))
		
		# Batting table
		_add_row("Batsman", "Dismissal", "R", "B", "4s", "6s", "SR", true)
		for b in fi.get("batsmen", []):
			var dismissal = b.get("dismissal", "")
			if not b.get("is_out", false) and b.get("balls", 0) > 0:
				dismissal = "not out"
			elif not b.get("is_out", false):
				dismissal = "DNB"
			_add_row(
				b.get("name", ""), dismissal,
				str(b.get("runs", 0)), str(b.get("balls", 0)),
				str(b.get("fours", 0)), str(b.get("sixes", 0)),
				str(snapped(b.get("sr", 0.0), 0.1)), false
			)
		var fx = fi.get("extras", {})
		_add_text("Extras: " + str(fx.get("wides", 0) + fx.get("no_balls", 0) + fx.get("byes", 0)) +
			" (w:" + str(fx.get("wides", 0)) + " nb:" + str(fx.get("no_balls", 0)) + ")")
		_add_text("Total: " + str(fi.get("total_runs", 0)) + "/" + str(fi.get("total_wickets", 0)) + " (" + str(fi.get("total_overs", "0.0")) + " ov)")
		
		# Bowling table
		var fi_bowlers = fi.get("bowlers", [])
		if fi_bowlers.size() > 0:
			_add_separator()
			_add_row("Bowler", "", "O", "M", "R", "W", "Eco", true)
			for b in fi_bowlers:
				_add_row(
					b.get("name", ""), "",
					str(b.get("overs", 0)), str(b.get("maidens", 0)),
					str(b.get("runs", 0)), str(b.get("wickets", 0)),
					str(snapped(b.get("economy", 0.0), 0.01)), false
				)

	# MAIN MATCH section for shootout-decided games (super-over runs excluded)
	if scorecard.get("super_over", false) and winner != "":
		var main_innings = scorecard.get("main_innings", [])
		if main_innings.size() >= 2:
			_render_mini_innings("MAIN MATCH — 1ST INNINGS", main_innings[0])
			_render_mini_innings("MAIN MATCH — 2ND INNINGS", main_innings[1])

func _render_mini_innings(header: String, inn: Dictionary) -> void:
	_add_separator()
	_add_separator()
	_add_header(header + " — " + inn.get("team_name", ""))
	_add_row("Batsman", "Dismissal", "R", "B", "4s", "6s", "SR", true)
	for b in inn.get("batsmen", []):
		var dismissal = b.get("dismissal", "")
		if not b.get("is_out", false) and b.get("balls", 0) > 0:
			dismissal = "not out"
		elif not b.get("is_out", false):
			dismissal = "DNB"
		_add_row(
			b.get("name", ""), dismissal,
			str(b.get("runs", 0)), str(b.get("balls", 0)),
			str(b.get("fours", 0)), str(b.get("sixes", 0)),
			str(snapped(b.get("sr", 0.0), 0.1)), false
		)
	var ex = inn.get("extras", {})
	_add_text("Extras: " + str(ex.get("wides", 0) + ex.get("no_balls", 0) + ex.get("byes", 0)) +
		" (w:" + str(ex.get("wides", 0)) + " nb:" + str(ex.get("no_balls", 0)) + ")")
	_add_text("Total: " + str(inn.get("total_runs", 0)) + "/" + str(inn.get("total_wickets", 0)) +
		" (" + str(inn.get("total_overs", "0.0")) + " ov)")

func _add_header(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GOLD)
	lbl.add_theme_font_size_override("font_size", 18)
	content.add_child(lbl)

func _add_text(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Constants.COLOR_TEXT_PRIMARY)
	lbl.add_theme_font_size_override("font_size", 13)
	content.add_child(lbl)

func _add_separator() -> void:
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", Constants.COLOR_BORDER)
	content.add_child(sep)

func _add_row(c1: String, c2: String, c3: String, c4: String, c5: String, c6: String, c7: String, is_header: bool) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	
	var cols = [c1, c2, c3, c4, c5, c6, c7]
	var widths = [180, 150, 40, 40, 40, 40, 60]
	
	for i in range(cols.size()):
		var lbl = Label.new()
		lbl.text = cols[i]
		lbl.custom_minimum_size.x = widths[i]
		if is_header:
			lbl.add_theme_color_override("font_color", Constants.COLOR_ACCENT_GREEN)
			lbl.add_theme_font_size_override("font_size", 13)
		else:
			lbl.add_theme_color_override("font_color", Constants.COLOR_TEXT_PRIMARY)
			lbl.add_theme_font_size_override("font_size", 12)
		hbox.add_child(lbl)
	
	content.add_child(hbox)

func _on_continue() -> void:
	var fade = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	
	var winner = GameManager.get_meta("match_winner") if GameManager.has_meta("match_winner") else ""
	if winner != "":
		# Match over: go wherever the current mode wants (menu or tournament hub)
		get_tree().change_scene_to_file(GameManager.return_scene)
	else:
		# Innings break, return to HUD for second innings
		get_tree().change_scene_to_file("res://scenes/ui/MatchHUD.tscn")
