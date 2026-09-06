extends SceneTree
# Loopback test HOST: hosts a LAN match, plays India (auto-answered), serves
# ball/over/match events to the client. Run alongside net_client.gd.
# Usage: godot --headless --path . -s res://tests/net_host.gd -- --port=54123

var _port := 54123
var _eng = null
var _gm = null
var _net = null
var _balls := 0
var _overs := 0
var _started := false
var _hosting := false
var _t0 := 0
var _failures: Array = []

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--port="):
			_port = int(a.get_slice("=", 1))

func _initialize() -> void:
	_parse_args()
	_eng = root.get_node("MatchEngine")
	_gm = root.get_node("GameManager")
	_net = root.get_node("NetworkManager")
	_net.player_connected.connect(_on_peer)
	_net.action_received.connect(_on_action)
	# Auto-answer the host's own turns (India bats first).
	_eng.request_shot_selection.connect(func(_n): _eng.receive_shot_input(randi_range(0, 5)))
	_eng.request_bowl_selection.connect(func(): _eng.receive_bowl_input(0))
	_eng.request_drs_review.connect(func(_w, _l): _eng.receive_drs_input(randi_range(0, 1) == 0))
	_eng.over_ended.connect(func(_s): _overs += 1)
	_eng.ball_result_ready.connect(func(_o): _balls += 1)
	_eng.match_ended_signal.connect(_on_end)
	_eng.fast_forward = true
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	if not _hosting:
		_hosting = true
		var err = _net.host_game(_port)
		print("HOST: hosting on ", _port, " err=", err)
		if err != OK:
			_fail("host_game failed")
			_finish()
		return
	if _started and (Time.get_ticks_msec() - _t0) > 150000:
		_fail("host timeout waiting for match end")
		_finish()

func _on_peer(id: int) -> void:
	print("HOST: peer joined id=", id)
	var A = _gm.all_teams[0].team_name
	var B = _gm.all_teams[1].team_name
	_net.host_team_name = A
	_net.client_team_name = B
	_net.online = true
	_net.rpc_id(id, "lobby_assign", A, B, 0)

func _on_action(a: Dictionary) -> void:
	if a.get("kind", "") == "ready" and not _started:
		_started = true
		_t0 = Time.get_ticks_msec()
		print("HOST: client ready, starting match")
		var home = _gm.all_teams[0]
		var away = _gm.all_teams[1]
		_eng.start_match(home, away, 0, home, true)
		_gm.state["max_overs"] = 2
		await process_frame
		_eng.note_hud_ready()

func _on_end(winner: String) -> void:
	var secs := (Time.get_ticks_msec() - _t0) / 1000.0
	print("HOST: match over winner=", winner, " balls=", _balls, " overs=", _overs, " t=", secs, "s")
	if winner == "":
		_fail("empty winner")
	if _balls < 10:
		_fail("too few balls bowled (%d)" % _balls)
	if _overs < 2:
		_fail("too few overs (%d)" % _overs)
	if _eng.net_fallbacks != 0:
		_fail("watchdog fallbacks fired %d times (lost inputs)" % _eng.net_fallbacks)
	if _net.remote_id == 0:
		_fail("no peer ever joined")
	# Linger so ENet can flush reliable packets + ACKs before the process dies.
	await create_timer(5.0).timeout
	_finish()

func _fail(msg: String) -> void:
	_failures.append(msg)

func _finish() -> void:
	if _failures.is_empty():
		print("NET-RESULT: PASS (host)")
	else:
		for f in _failures:
			print("NET-FAIL (host): ", f)
		print("NET-RESULT: FAIL (host)")
	quit(0 if _failures.is_empty() else 1)
