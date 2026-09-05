# AudioManager.gd — Handles all game audio (Autoload).
# Streams are generated placeholders — see tools/gen_audio.ps1 to regenerate.
extends Node

const SFX_BAT_HIT := preload("res://assets/audio/bat_hit.wav")
const SFX_CROWD_CHEER := preload("res://assets/audio/crowd_cheer.wav")
const SFX_WICKET := preload("res://assets/audio/wicket.wav")
const SFX_AMBIENT := preload("res://assets/audio/crowd_ambient.wav")
const SFX_CLICK := preload("res://assets/audio/ui_click.wav")

var master_bus := "Master"

@onready var sfx_bat_hit := AudioStreamPlayer.new()
@onready var sfx_crowd_cheer := AudioStreamPlayer.new()
@onready var sfx_wicket := AudioStreamPlayer.new()
@onready var sfx_ambient_crowd := AudioStreamPlayer.new()
@onready var sfx_click := AudioStreamPlayer.new()

func _ready() -> void:
	sfx_bat_hit.name = "SFX_BatHit"
	sfx_crowd_cheer.name = "SFX_CrowdCheer"
	sfx_wicket.name = "SFX_Wicket"
	sfx_ambient_crowd.name = "SFX_AmbientCrowd"
	sfx_click.name = "SFX_Click"
	
	sfx_bat_hit.stream = SFX_BAT_HIT
	sfx_crowd_cheer.stream = SFX_CROWD_CHEER
	sfx_wicket.stream = SFX_WICKET
	sfx_ambient_crowd.stream = SFX_AMBIENT
	sfx_click.stream = SFX_CLICK
	sfx_ambient_crowd.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	add_child(sfx_bat_hit)
	add_child(sfx_crowd_cheer)
	add_child(sfx_wicket)
	add_child(sfx_ambient_crowd)
	add_child(sfx_click)
	
	# Apply volumes persisted by GameManager (loads before this autoload).
	set_master_volume(GameManager.master_volume)
	set_sfx_volume(GameManager.sfx_volume)

func play_bat_hit() -> void:
	if sfx_bat_hit.stream:
		sfx_bat_hit.play()

func play_crowd_cheer() -> void:
	if sfx_crowd_cheer.stream:
		sfx_crowd_cheer.play()

func play_wicket() -> void:
	if sfx_wicket.stream:
		sfx_wicket.play()

func play_click() -> void:
	if sfx_click.stream:
		sfx_click.play()

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
	sfx_click.volume_db = linear_to_db(vol)
