extends SceneTree
# Headless UI smoke test: instantiates every scene, verifies key control wiring
# (toggle modes, quit dialog, back paths) and the abort_match contract.
# Run: Godot_v4.2.2-stable_win64_console.exe --headless --path . -s res://tests/ui_smoke.gd
# Exit code 0 = all checks passed, 1 = failure.

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	process_frame.connect(_on_frame_once)

func _on_frame_once() -> void:
	process_frame.disconnect(_on_frame_once)
	# _run() awaits frames — without await here only section 1 would execute
	# before the pass/fail print (silent false-green). Await the coroutine.
	await _run()
	if _failures.is_empty():
		print("UI SMOKE: all %d checks passed" % _checks)
	else:
		for f in _failures:
			print("UI SMOKE FAIL: ", f)
		print("UI SMOKE: %d failures" % _failures.size())
	quit(1 if not _failures.is_empty() else 0)

func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(label)

func _load_inst(path: String) -> Node:
	var packed: PackedScene = load(path)
	if packed == null:
		_failures.append("load failed: " + path)
		return null
	_checks += 1
	var inst: Node = packed.instantiate()
	root.add_child(inst)
	return inst

func _run() -> void:
	# 1. Every scene instantiates (catches bad @onready paths at _ready time).
	var hud = _load_inst("res://scenes/ui/MatchHUD.tscn")
	_load_inst("res://scenes/ui/MainMenu.tscn")
	_load_inst("res://scenes/ui/TeamSelect.tscn")
	_load_inst("res://scenes/ui/XIPicker.tscn")
	_load_inst("res://scenes/ui/TossScreen.tscn")
	_load_inst("res://scenes/ui/Scorecard.tscn")
	_load_inst("res://scenes/ui/TournamentHub.tscn")
	_load_inst("res://scenes/ui/CareerRecords.tscn")
	_load_inst("res://scenes/ui/Settings.tscn")
	_load_inst("res://scenes/ui/MultiplayerMenu.tscn")
	_load_inst("res://scenes/match/FieldView.tscn")
	if hud == null:
		return
	await process_frame
	await process_frame
	# 2. Fast-forward + wagon buttons must be toggle buttons (toggled signal).
	var ff: Button = hud.get_node("StatusBar/FFBtn")
	var wagon: Button = hud.get_node("StatusBar/WagonBtn")
	_check(ff.toggle_mode, "FFBtn must have toggle_mode=true or toggled never fires")
	_check(wagon.toggle_mode, "WagonBtn must have toggle_mode=true")
	# 3. Quit flow controls exist and start hidden.
	_check(hud.has_node("StatusBar/QuitBtn"), "StatusBar/QuitBtn missing")
	_check(hud.has_node("QuitConfirm"), "QuitConfirm dialog missing")
	_check(hud.has_node("QuitConfirm/QuitPanel/QuitVBox/QuitBtns/QuitYesBtn"), "QuitYesBtn missing")
	_check(hud.has_node("QuitConfirm/QuitPanel/QuitVBox/QuitBtns/QuitNoBtn"), "QuitNoBtn missing")
	_check(not hud.get_node("QuitConfirm").visible, "QuitConfirm must start hidden")
	# 4. TossScreen back path exists (dead-end regression).
	var toss = load("res://scenes/ui/TossScreen.tscn").instantiate()
	_checks += 1
	_check(toss.has_node("StartRow/BtnBack"), "TossScreen StartRow/BtnBack missing")
	root.add_child(toss)
	# 5. abort_match contract: IDLE state + generation bump kills pending flows.
	var engine = root.get_node("MatchEngine")
	var gen_before: int = engine._match_gen
	engine.abort_match()
	_check(engine.current_state == 0, "abort_match must leave engine IDLE")
	_check(engine._match_gen == gen_before + 1, "abort_match must bump _match_gen")
	_check(not engine.is_human_batting and not engine.is_human_bowling, "abort_match must clear input flags")
	# 6. Human-control UX: coach overlay starts hidden, countdowns + legend exist,
	#    reaction window follows the difficulty slider (Easy 8s / Med 6s / Hard 4s).
	_check(hud.has_node("CoachPopup"), "CoachPopup missing")
	_check(not hud.get_node("CoachPopup").visible, "CoachPopup must start hidden")
	_check(hud.has_node("CoachPopup/CoachPanel/CoachVBox/CoachTitle"), "CoachTitle missing")
	_check(hud.has_node("CoachPopup/CoachPanel/CoachVBox/CoachBody"), "CoachBody missing")
	_check(hud.has_node("CoachPopup/CoachPanel/CoachVBox/CoachBtn"), "CoachBtn missing")
	_check(hud.has_node("ShotSelectionPanel/ShotVBox/Countdown"), "Shot Countdown label missing")
	_check(hud.has_node("BowlSelectionPanel/BowlVBox/BowlCountdown"), "BowlCountdown label missing")
	_check(hud.has_node("StatusBar/ControlsHint"), "ControlsHint legend missing")
	var consts = root.get_node("Constants")
	_check(consts.human_input_timeout(0) == 8.0, "Easy timeout must be 8s")
	_check(consts.human_input_timeout(1) == 6.0, "Medium timeout must be 6s")
	_check(consts.human_input_timeout(2) == 4.0, "Hard timeout must be 4s")
	_check(hud._human_timeout() >= 4.0, "HUD human timeout below sane minimum")
	# 7. TeamSelect: mode description + YOU/OPPONENT clarity + Start guard.
	var ts = load("res://scenes/ui/TeamSelect.tscn").instantiate()
	_checks += 1
	root.add_child(ts)
	await process_frame
	_check(ts.has_node("ModeDesc"), "TeamSelect ModeDesc missing")
	_check(ts.get_node("ModeDesc").text != "", "ModeDesc must show the default mode text")
	_check(not ts.get_node("BtnStart").disabled, "BtnStart must start enabled (default teams differ)")
	ts.selected_team_b = ts.selected_team_a
	ts._validate()
	_check(ts.get_node("BtnStart").disabled, "BtnStart must disable on same-team picks")
