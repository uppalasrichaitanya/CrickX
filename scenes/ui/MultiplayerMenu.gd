# MultiplayerMenu.gd — LAN lobby: host or join, team/format setup, handshake.
extends Control

var sel_a: int = 0
var sel_b: int = 1
var sel_format: int = Constants.MatchFormat.T20
var hosting: bool = false
var joining: bool = false
var host_teams: Array = []
var host_format: int = 0

@onready var team_a_list := $Teams/TeamAPanel/TeamAList
@onready var team_b_list := $Teams/TeamBPanel/TeamBList
@onready var format_btn := $FormatRow/FormatBtn
@onready var ip_edit := $NetRow/IPEdit
@onready var port_edit := $NetRow/PortEdit
@onready var btn_host := $BtnRow/BtnHost
@onready var btn_join := $BtnRow/BtnJoin
@onready var lbl_status := $Status
@onready var btn_back := $BtnBack

func _ready() -> void:
	modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, Constants.SCENE_FADE_DURATION)
	
	for i in range(GameManager.all_teams.size()):
		team_a_list.add_item(GameManager.all_teams[i].team_name)
		team_b_list.add_item(GameManager.all_teams[i].team_name)
	team_a_list.select(0)
	team_b_list.select(1)
	team_a_list.item_selected.connect(func(idx): sel_a = idx)
	team_b_list.item_selected.connect(func(idx): sel_b = idx)
	
	format_btn.clear()
	format_btn.add_item("T20", Constants.MatchFormat.T20)
	format_btn.add_item("ODI", Constants.MatchFormat.ODI)
	format_btn.selected = 0
	format_btn.item_selected.connect(func(idx: int) -> void:
		sel_format = format_btn.get_item_id(idx))
	
	btn_host.pressed.connect(_on_host)
	btn_join.pressed.connect(_on_join)
	btn_back.pressed.connect(_on_back)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_left)
	NetworkManager.connection_succeeded.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_conn_failed)
	NetworkManager.lobby_ready.connect(_on_lobby_ready)
	NetworkManager.action_received.connect(_on_action)

func _port() -> int:
	var p := int(port_edit.text) if port_edit.text.is_valid_int() else Constants.DEFAULT_PORT
	return clampi(p, 1024, 65535)

func _on_host() -> void:
	if sel_a == sel_b:
		_set_status("Pick two different teams!")
		return
	hosting = true
	joining = false
	host_teams = [GameManager.all_teams[sel_a].team_name, GameManager.all_teams[sel_b].team_name]
	host_format = sel_format
	var err := NetworkManager.host_game(_port())
	if err != OK:
		hosting = false
		_set_status("Could not host (port busy?). Error %d" % err)
		return
	AudioManager.play_click()
	_set_status("Hosting on port %d as %s — waiting for player…" % [_port(), host_teams[0]])

func _on_join() -> void:
	hosting = false
	joining = true
	var err := NetworkManager.join_game(ip_edit.text.strip_edges(), _port())
	if err != OK:
		joining = false
		_set_status("Could not start client. Error %d" % err)
		return
	AudioManager.play_click()
	_set_status("Connecting to %s:%d…" % [ip_edit.text.strip_edges(), _port()])

func _on_player_connected(id: int) -> void:
	if not hosting:
		return
	# Assign sides: host plays team A, guest plays team B.
	NetworkManager.host_team_name = host_teams[0]
	NetworkManager.client_team_name = host_teams[1]
	NetworkManager.online = true
	NetworkManager.rpc_id(id, "lobby_assign", host_teams[0], host_teams[1], host_format)
	_set_status("%s joined! Waiting for them to be ready…" % host_teams[1])
	AudioManager.play_click()

func _on_player_left(_id: int) -> void:
	if hosting or joining:
		_set_status("Player left. You can host or join again.")
		hosting = false
		joining = false

func _on_connected() -> void:
	_set_status("Connected — waiting for the host to start…")

func _on_conn_failed() -> void:
	joining = false
	_set_status("Connection failed. Check the IP/port and try again.")

func _on_lobby_ready() -> void:
	# Client side: the host assigned teams — go to the HUD (net mode).
	AudioManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/MatchHUD.tscn")

func _on_action(action: Dictionary) -> void:
	# Host side: the client's MatchHUD signals readiness here.
	if hosting and action.get("kind", "") == "ready":
		_start_host_match()

func _start_host_match() -> void:
	var a := _team_by_name(NetworkManager.host_team_name)
	var b := _team_by_name(NetworkManager.client_team_name)
	if a == null or b == null:
		_set_status("Team lookup failed — aborting.")
		return
	GameManager.return_scene = "res://scenes/ui/MainMenu.tscn"
	MatchEngine.start_match(a, b, host_format, a, true)
	_set_status("Starting match…")
	get_tree().change_scene_to_file("res://scenes/ui/MatchHUD.tscn")

func _team_by_name(n: String) -> TeamData:
	for t in GameManager.all_teams:
		if t.team_name == n:
			return t
	return null

func _set_status(t: String) -> void:
	lbl_status.text = t

func _on_back() -> void:
	NetworkManager.disconnect_gracefully()
	hosting = false
	joining = false
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, Constants.SCENE_FADE_DURATION)
	await fade.finished
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
