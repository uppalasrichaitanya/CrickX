# NetworkManager.gd — LAN multiplayer using Godot 4 ENet (Autoload).
# Authoritative-host model: the HOST runs the real MatchEngine. The client
# mirrors every event (delivery/ball/over/innings/match) and sends its inputs
# (shot/bowl/DRS) back via RPC. Sides are fixed at lobby time.
extends Node

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed()
signal connection_succeeded()
signal lobby_ready()            # Both sides present, match can start
signal net_event(event: Dictionary)  # Client-side: pushed engine events
signal action_received(action: Dictionary)  # Host-side: lobby-level client actions

const INPUT_WAIT_TIMEOUT: float = 25.0  # Host watchdog: AI-fills a missing remote input

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_connected: bool = false
var online: bool = false            # An online match is active (either side)
var host_team_name: String = ""     # Team played by the host
var client_team_name: String = ""   # Team played by the client
var remote_id: int = 0              # The other peer's multiplayer id

func my_team_name() -> String:
	if not online:
		return ""
	return host_team_name if is_host else client_team_name

func opponent_team_name() -> String:
	if not online:
		return ""
	return client_team_name if is_host else host_team_name

func host_game(port: int = Constants.DEFAULT_PORT) -> Error:
	_disconnect_peer()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		is_host = true
		is_connected = true
		if not multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.connect(_on_peer_connected)
		if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return err

func join_game(ip: String, port: int = Constants.DEFAULT_PORT) -> Error:
	_disconnect_peer()
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		is_host = false
		if not multiplayer.connected_to_server.is_connected(_on_connected):
			multiplayer.connected_to_server.connect(_on_connected)
		if not multiplayer.connection_failed.is_connected(_on_connection_failed):
			multiplayer.connection_failed.connect(_on_connection_failed)
		if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
			multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return err

func disconnect_gracefully() -> void:
	_disconnect_peer()
	is_connected = false
	is_host = false
	online = false
	host_team_name = ""
	client_team_name = ""
	remote_id = 0

func _disconnect_peer() -> void:
	if peer:
		multiplayer.multiplayer_peer = null
		peer = null

# ─── Lobby handshake ───
# Host tells the client the team assignment + match config; client confirms.
@rpc("authority", "reliable")
func lobby_assign(host_team: String, client_team: String, format: int) -> void:
	host_team_name = host_team
	client_team_name = client_team
	online = true
	lobby_ready.emit()

# ─── Client -> host inputs ───
@rpc("any_peer", "reliable")
func submit_action(action: Dictionary) -> void:
	if not is_host:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != remote_id and remote_id != 0:
		return  # Only the joined peer may act
	_route_action(action)

func _route_action(action: Dictionary) -> void:
	var kind: String = action.get("kind", "")
	var value = action.get("value", -1)
	match kind:
		"shot":
			MatchEngine.receive_shot_input(int(value))
		"bowl":
			MatchEngine.receive_bowl_input(int(value))
		"drs":
			MatchEngine.receive_drs_input(bool(value))
		_:
			action_received.emit(action)

func send_action(action: Dictionary) -> void:
	if is_host or not online:
		return
	rpc_id(1, "submit_action", action)

# ─── Host -> client events ───
@rpc("authority", "reliable")
func push_event(event: Dictionary) -> void:
	if is_host:
		return
	net_event.emit(event)

func broadcast(event: Dictionary) -> void:
	if not is_host or not online or remote_id == 0:
		return
	rpc_id(remote_id, "push_event", event)

# Snapshot of everything the client's HUD needs to render one frame.
func build_snapshot() -> Dictionary:
	var gm := GameManager
	var striker := {}
	if gm.striker:
		striker = {"name": gm.striker.player_name, "runs": gm.striker.match_runs,
			"balls": gm.striker.match_balls, "fours": gm.striker.match_fours,
			"sixes": gm.striker.match_sixes, "sr": gm.striker.get_strike_rate()}
	var nonstriker := {}
	if gm.non_striker:
		nonstriker = {"name": gm.non_striker.player_name, "runs": gm.non_striker.match_runs,
			"balls": gm.non_striker.match_balls}
	var bowler := {}
	if gm.current_bowler:
		bowler = {"name": gm.current_bowler.player_name,
			"overs": gm.current_bowler.match_overs_bowled,
			"maidens": gm.current_bowler.match_maidens,
			"runs": gm.current_bowler.match_runs_conceded,
			"wickets": gm.current_bowler.match_wickets,
			"economy": gm.current_bowler.get_economy()}
	return {
		"type": "state",
		"batting_team": gm.batting_team.team_name if gm.batting_team else "",
		"bowling_team": gm.bowling_team.team_name if gm.bowling_team else "",
		"total_runs": gm.state.get("total_runs", 0),
		"total_wickets": gm.state.get("total_wickets", 0),
		"current_over": gm.state.get("current_over", 0),
		"current_ball": gm.state.get("current_ball", 0),
		"target": gm.state.get("target", 0),
		"max_overs": gm.state.get("max_overs", 20),
		"format": gm.state.get("format", 0),
		"phase": gm.state.get("phase", 1),
		"is_first_innings": gm.state.get("is_first_innings", true),
		"striker": striker, "nonstriker": nonstriker, "bowler": bowler,
		"weather": gm.weather, "pitch_type": gm.pitch_type,
		"pressure": gm.batting_pressure,
		"momentum": gm.momentum,
		"partnership": gm.get_partnership_runs(),
		"drs_batting": gm.drs_reviews_batting,
		"drs_max": gm.get_max_reviews(),
		"crr": gm.get_current_run_rate(),
		"rrr": gm.get_required_run_rate(),
	}

# ─── Signal handlers ───
func _on_peer_connected(id: int) -> void:
	remote_id = id
	is_connected = true
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	is_connected = false
	player_disconnected.emit(id)
	if online:
		online = false

func _on_connected() -> void:
	remote_id = 1
	is_connected = true
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	is_connected = false
	connection_failed.emit()
