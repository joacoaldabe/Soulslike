extends Node

signal settings_changed

const DEFAULT_SETTINGS_PATH := "user://soulslike_settings.cfg"
const COMMON_RESOLUTIONS := [
	Vector2i(1152, 648),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

var settings_path := DEFAULT_SETTINGS_PATH
var resolution := Vector2i(1280, 720)
var fullscreen := false
var vsync := true

func _ready():
	load_settings()
	apply_settings()

func get_resolution_options() -> Array:
	var monitor_size := DisplayServer.screen_get_size()
	var result: Array = []
	for option in COMMON_RESOLUTIONS:
		if monitor_size.x <= 0 or monitor_size.y <= 0 or (option.x <= monitor_size.x and option.y <= monitor_size.y):
			result.append(option)
	if not result.has(resolution):
		result.append(resolution)
	result.sort_custom(func(a, b): return a.x * a.y < b.x * b.y)
	return result

func set_resolution(value: Vector2i):
	resolution = _clamp_resolution_to_monitor(Vector2i(max(640, value.x), max(360, value.y)))
	_apply_resolution()
	save_settings()
	settings_changed.emit()

func set_fullscreen(value: bool):
	fullscreen = value
	_apply_window_mode()
	if not fullscreen:
		_apply_resolution()
	save_settings()
	settings_changed.emit()

func set_vsync(value: bool):
	vsync = value
	_apply_vsync()
	save_settings()
	settings_changed.emit()

func apply_settings():
	if DisplayServer.get_name() == "headless":
		return
	_apply_window_mode()
	_apply_resolution()
	_apply_vsync()

func _apply_window_mode():
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func _apply_resolution():
	if DisplayServer.get_name() == "headless" or fullscreen:
		return
	DisplayServer.window_set_size(resolution)

func _apply_vsync():
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("display", "width", resolution.x)
	config.set_value("display", "height", resolution.y)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "vsync", vsync)
	var error := config.save(settings_path)
	if error != OK:
		push_error("AppSettings: no se pudo guardar la configuracion (error %d)." % error)
	return error == OK

func load_settings() -> bool:
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error == ERR_FILE_NOT_FOUND:
		return save_settings()
	if error != OK:
		push_warning("AppSettings: configuracion invalida; se usan valores predeterminados.")
		return false
	resolution = _clamp_resolution_to_monitor(Vector2i(
		max(640, int(config.get_value("display", "width", resolution.x))),
		max(360, int(config.get_value("display", "height", resolution.y)))
	))
	fullscreen = bool(config.get_value("display", "fullscreen", fullscreen))
	vsync = bool(config.get_value("display", "vsync", vsync))
	return true

func set_settings_path_for_tests(path: String):
	settings_path = path if path != "" else DEFAULT_SETTINGS_PATH

func reset_settings_path():
	settings_path = DEFAULT_SETTINGS_PATH

func _clamp_resolution_to_monitor(value: Vector2i) -> Vector2i:
	var monitor_size := DisplayServer.screen_get_size()
	if monitor_size.x <= 0 or monitor_size.y <= 0:
		return value
	return Vector2i(min(value.x, monitor_size.x), min(value.y, monitor_size.y))
