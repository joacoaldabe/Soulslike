extends Node

const SAVE_VERSION := 2
const DEFAULT_SAVE_PATH := "user://soulslike_save.json"

var save_path := DEFAULT_SAVE_PATH
var _is_saving := false

func has_save_file() -> bool:
	return FileAccess.file_exists(save_path)

func has_valid_save() -> bool:
	return _read_save(false) != null

func get_save_path() -> String:
	return save_path

func set_save_path_for_tests(path: String):
	save_path = path if path != "" else DEFAULT_SAVE_PATH

func reset_save_path():
	save_path = DEFAULT_SAVE_PATH

func build_save_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"player": GameState.get_save_data(),
		"inventory": Inventory.get_save_data(),
		"world": GameState.get_world_save_data()
	}

func save_game() -> bool:
	if _is_saving:
		push_warning("SaveManager: se ignoro un guardado simultaneo.")
		return false
	_is_saving = true
	var data := build_save_data()
	var result := _write_save_safely(JSON.stringify(data, "\t"))
	_is_saving = false
	return result

func load_game():
	return _read_save(true)

func delete_save() -> bool:
	var success := true
	for path in [save_path, save_path + ".tmp", save_path + ".bak"]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				push_error("SaveManager: no se pudo eliminar '%s' (error %d)." % [path, error])
				success = false
	return success

func validate_save_data(data, log_errors := true) -> bool:
	if not data is Dictionary:
		_log_validation_error("la raiz no es un diccionario", log_errors)
		return false
	if not data.has("save_version") or (not data["save_version"] is float and not data["save_version"] is int):
		_log_validation_error("falta save_version", log_errors)
		return false
	var version := int(data["save_version"])
	if version < 1 or version > SAVE_VERSION:
		_log_validation_error("version no soportada: %d" % version, log_errors)
		return false
	for section in ["player", "inventory", "world"]:
		if data.has(section) and not data[section] is Dictionary:
			_log_validation_error("la seccion '%s' es invalida" % section, log_errors)
			return false
	return true

func _read_save(log_errors: bool):
	if not FileAccess.file_exists(save_path):
		return null
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_log_validation_error("no se pudo abrir '%s' (error %d)" % [save_path, FileAccess.get_open_error()], log_errors)
		return null
	var content := file.get_as_text()
	if content.strip_edges().is_empty():
		_log_validation_error("el archivo esta vacio", log_errors)
		return null
	var json := JSON.new()
	var parse_error := json.parse(content)
	if parse_error != OK:
		_log_validation_error("JSON corrupto en linea %d: %s" % [json.get_error_line(), json.get_error_message()], log_errors)
		return null
	var data = json.data
	if not validate_save_data(data, log_errors):
		return null
	if not data.has("player"):
		data["player"] = {}
	if not data.has("inventory"):
		data["inventory"] = {}
	if not data.has("world"):
		data["world"] = {}
	return data

func _write_save_safely(content: String) -> bool:
	var temp_path := save_path + ".tmp"
	var backup_path := save_path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: no se pudo crear el archivo temporal (error %d)." % FileAccess.get_open_error())
		return false
	file.store_string(content)
	file.flush()
	file.close()
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(save_path):
		var backup_error := DirAccess.rename_absolute(absolute_save, absolute_backup)
		if backup_error != OK:
			push_error("SaveManager: no se pudo preparar el reemplazo seguro (error %d)." % backup_error)
			DirAccess.remove_absolute(absolute_temp)
			return false
	var replace_error := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if replace_error != OK:
		push_error("SaveManager: no se pudo publicar el guardado (error %d)." % replace_error)
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_save)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	return true

func _log_validation_error(message: String, enabled: bool):
	if enabled:
		push_error("SaveManager: %s." % message)
