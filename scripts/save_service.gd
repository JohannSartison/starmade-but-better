## SaveService – Autoload
## Verwaltet Spielstände (World-Slots) und Spieler-Persistenz.
extends Node

const SAVE_VERSION := 1
const INDEX_PATH := "user://worlds/index.json"
const WORLDS_DIR := "user://worlds/"

var _active_world_id: String = ""
var _save_data: Dictionary = {}

# -----------------------------------------------------------------------
# Öffentliche API
# -----------------------------------------------------------------------

func get_active_world_id() -> String:
	return _active_world_id

func set_active_world(world_id: String) -> void:
	_active_world_id = world_id

func load_world(world_id: String) -> Dictionary:
	var path := WORLDS_DIR + world_id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveService: Konnte %s nicht öffnen." % path)
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("SaveService: JSON-Fehler in %s" % path)
		return {}
	var data: Dictionary = json.data
	if data.get("save_version", -1) != SAVE_VERSION:
		push_warning("SaveService: Save-Version inkompatibel, ignoriere Save.")
		return {}
	return data

func save_world(world_id: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLDS_DIR))
	data["save_version"] = SAVE_VERSION
	var path := WORLDS_DIR + world_id + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: Konnte %s nicht schreiben." % path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func get_world_index() -> Array:
	if not FileAccess.file_exists(INDEX_PATH):
		return []
	var file := FileAccess.open(INDEX_PATH, FileAccess.READ)
	if file == null:
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return []
	file.close()
	return json.data if json.data is Array else []

func create_world(world_name: String) -> String:
	var world_id := _generate_id()
	var index := get_world_index()
	index.append({
		"id": world_id,
		"name": world_name,
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"last_played_at_unix": int(Time.get_unix_time_from_system()),
	})
	_write_index(index)
	return world_id

func delete_world(world_id: String) -> void:
	var index := get_world_index()
	index = index.filter(func(e): return e["id"] != world_id)
	_write_index(index)
	var path := WORLDS_DIR + world_id + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# -----------------------------------------------------------------------
# Intern
# -----------------------------------------------------------------------

func _generate_id() -> String:
	return "%x" % [randi(), randi()]

func _write_index(index: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORLDS_DIR))
	var file := FileAccess.open(INDEX_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: Konnte Index nicht schreiben.")
		return
	file.store_string(JSON.stringify(index, "\t"))
	file.close()
