# SaveManager.gd — Handles save/load for tournaments and career stats (Autoload).
extends Node

const TOURNAMENT_SAVE_PATH := "user://saves/tournament.json"
const CAREER_SAVE_PATH := "user://saves/career.json"

func save_tournament(data: Dictionary) -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	var file = FileAccess.open(TOURNAMENT_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_tournament() -> Dictionary:
	if not FileAccess.file_exists(TOURNAMENT_SAVE_PATH):
		return {}
	var file = FileAccess.open(TOURNAMENT_SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		file.close()
		if err == OK:
			return json.data
	return {}

func has_tournament_save() -> bool:
	return FileAccess.file_exists(TOURNAMENT_SAVE_PATH)

func delete_tournament_save() -> void:
	if FileAccess.file_exists(TOURNAMENT_SAVE_PATH):
		DirAccess.remove_absolute(TOURNAMENT_SAVE_PATH)

func save_career(data: Dictionary) -> void:
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	var file = FileAccess.open(CAREER_SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func load_career() -> Dictionary:
	if not FileAccess.file_exists(CAREER_SAVE_PATH):
		return { "total_runs": 0, "total_wickets": 0, "matches_played": 0, "matches_won": 0 }
	var file = FileAccess.open(CAREER_SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		var err = json.parse(file.get_as_text())
		file.close()
		if err == OK:
			return json.data
	return { "total_runs": 0, "total_wickets": 0, "matches_played": 0, "matches_won": 0 }
