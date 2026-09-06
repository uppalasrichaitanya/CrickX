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
	_run()
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
