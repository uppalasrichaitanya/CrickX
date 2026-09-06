extends SceneTree
# Loopback test CLIENT: joins the host, instantiates the real MatchHUD in net
# mode, answers input requests immediately, and verifies the mirrored match.
# Usage: godot --headless --path . -s res://tests/net_client.gd -- --port=54123

var _port := 54123
var _net = null
var _hud = null
var _balls := 0
var _overs := 0
var _ended := ""
var _t0 := 0
var _failures: Array = []
var _done := false
var _counts := {}

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			_port = int(a.get_slice("=", 1))

func _initialize() -> void:
	_parse_args()
	_net = root.get_node("NetworkManager")
	_net.connection_succeeded.connect(func(): print("CLIENT: connected, waiting for lobby"))
	_net.connection_failed.connect(func(): _fail("connection failed"); _finish())
	_net.lobby_ready.connect(_on_lobby)
	_net.net_event.connect(_on_event)
	_t0 = Time.get_ticks_msec()
	process_frame.connect(_on_frame)

var _joined := false

func _on_frame() -> void:
	if not _joined:
		_joined = true
		var err = _net.join_game("127.0.0.1", _port)
		print("CLIENT: joining err=", err)
		if err != OK:
			_fail("join_game failed")
			_finish()
		return
	if _done:
		return
	if _ended != "":
		_done = true
		var secs := (Time.get_ticks_msec() - _t0) / 1000.0
		print("CLIENT: match over winner=", _ended, " balls=", _balls, " overs=", _overs, " t=", secs, "s")
		print("CLIENT: event counts=", _counts)
		if _balls < 10:
			_fail("too few ball events (%d)" % _balls)
		if _overs < 2:
			_fail("too few over events (%d)" % _overs)
		if _hud != null and _hud.lbl_score.text == "":
			_fail("HUD score label never populated (snapshot path broken)")
		_finish()
		return
	if (Time.get_ticks_msec() - _t0) > 150000:
		_done = true
		_fail("client timeout waiting for match end")
		_finish()

func _on_lobby() -> void:
	print("CLIENT: lobby assigned, my team=", _net.my_team_name())
	_hud = load("res://scenes/ui/MatchHUD.tscn").instantiate()
	root.add_child(_hud)
	await process_frame
	await process_frame
	if _hud.lbl_score == null:
		_fail("HUD failed to build")

func _on_event(e: Dictionary) -> void:
	_counts[e.get("type", "?")] = int(_counts.get(e.get("type", "?"), 0)) + 1
	match e.get("type", ""):
		"request_shot":
			_net.send_action({"kind": "shot", "value": randi_range(0, 5)})
		"request_bowl":
			_net.send_action({"kind": "bowl", "value": 0})
		"request_drs":
			_net.send_action({"kind": "drs", "value": false})
		"ball":
			_balls += 1
		"over":
			_overs += 1
		"match_end":
			_ended = e.get("winner", "")

func _fail(msg: String) -> void:
	_failures.append(msg)

func _finish() -> void:
	if _failures.is_empty():
		print("NET-RESULT: PASS (client)")
	else:
		for f in _failures:
			print("NET-FAIL (client): ", f)
		print("NET-RESULT: FAIL (client)")
	quit(0 if _failures.is_empty() else 1)
