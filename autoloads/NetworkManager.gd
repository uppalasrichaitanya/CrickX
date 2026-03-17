# NetworkManager.gd — Handles LAN multiplayer using Godot 4 ENet (Autoload).
# Stub for Phase 5 — provides the interface now so other systems can reference it.
extends Node

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed()
signal connection_succeeded()
signal action_received(action: Dictionary)

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_connected: bool = false

func host_game(port: int = Constants.DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		is_host = true
		is_connected = true
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return err

func join_game(ip: String, port: int = Constants.DEFAULT_PORT) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err == OK:
		multiplayer.multiplayer_peer = peer
		is_host = false
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_connection_failed)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return err

func disconnect_gracefully() -> void:
	if peer:
		multiplayer.multiplayer_peer = null
		peer = null
	is_connected = false
	is_host = false

@rpc("any_peer", "reliable")
func send_action(action: Dictionary) -> void:
	action_received.emit(action)

func _on_peer_connected(id: int) -> void:
	is_connected = true
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	player_disconnected.emit(id)

func _on_connected() -> void:
	is_connected = true
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	is_connected = false
	connection_failed.emit()
