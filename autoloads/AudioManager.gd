# AudioManager.gd — Handles all game audio (Autoload).
# Placeholder AudioStreamPlayer nodes — sounds can be added later.
extends Node

var master_bus := "Master"

@onready var sfx_bat_hit := AudioStreamPlayer.new()
@onready var sfx_crowd_cheer := AudioStreamPlayer.new()
@onready var sfx_wicket := AudioStreamPlayer.new()
@onready var sfx_ambient_crowd := AudioStreamPlayer.new()

func _ready() -> void:
	sfx_bat_hit.name = "SFX_BatHit"
	sfx_crowd_cheer.name = "SFX_CrowdCheer"
	sfx_wicket.name = "SFX_Wicket"
	sfx_ambient_crowd.name = "SFX_AmbientCrowd"
	
	add_child(sfx_bat_hit)
	add_child(sfx_crowd_cheer)
	add_child(sfx_wicket)
	add_child(sfx_ambient_crowd)

func play_bat_hit() -> void:
	if sfx_bat_hit.stream:
		sfx_bat_hit.play()

func play_crowd_cheer() -> void:
	if sfx_crowd_cheer.stream:
		sfx_crowd_cheer.play()

func play_wicket() -> void:
	if sfx_wicket.stream:
		sfx_wicket.play()

func start_ambient() -> void:
	if sfx_ambient_crowd.stream and not sfx_ambient_crowd.playing:
		sfx_ambient_crowd.play()

func stop_ambient() -> void:
	if sfx_ambient_crowd.playing:
		sfx_ambient_crowd.stop()

func set_master_volume(vol: float) -> void:
	var bus_idx = AudioServer.get_bus_index(master_bus)
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(vol))

func set_sfx_volume(vol: float) -> void:
	sfx_bat_hit.volume_db = linear_to_db(vol)
	sfx_crowd_cheer.volume_db = linear_to_db(vol)
	sfx_wicket.volume_db = linear_to_db(vol)
	sfx_ambient_crowd.volume_db = linear_to_db(vol)
