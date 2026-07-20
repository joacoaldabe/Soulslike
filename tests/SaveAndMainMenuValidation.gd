extends SceneTree

const TEST_SAVE_PATH := "user://soulslike_save_test.json"
const TEST_SETTINGS_PATH := "user://soulslike_settings_test.cfg"

var failures: Array[String] = []

func _initialize():
	call_deferred("_run")

func _expect(condition: bool, message: String):
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _write_test_file(content: String):
	var file := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	_expect(file != null, "test save file can be written")
	if file != null:
		file.store_string(content)
		file.close()

func _same_instances(left: Array, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for instance in left:
		if not instance is Dictionary:
			return false
		var instance_id := str(instance.get("instance_id", ""))
		if not right.has(instance_id) or right[instance_id] != instance:
			return false
	return true

func _run():
	var save_manager = root.get_node("SaveManager")
	var game_session = root.get_node("GameSession")
	var game_state = root.get_node("GameState")
	var inventory = root.get_node("Inventory")
	var database = root.get_node("Database")
	var app_settings = root.get_node("AppSettings")
	save_manager.set_save_path_for_tests(TEST_SAVE_PATH)
	save_manager.delete_save()
	app_settings.set_settings_path_for_tests(TEST_SETTINGS_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	_expect(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/MainMenu.tscn", "project starts in the main menu")

	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	_expect(menu != null and menu.menu_panel != null, "main menu instantiates without errors")
	_expect(menu.load_game_button.disabled, "load game is disabled without a save")
	_expect([
		menu.new_game_button.text,
		menu.load_game_button.text,
		menu.settings_button.text,
		menu.exit_button.text
	] == ["Nuevo juego", "Cargar juego", "Configuracion", "Salir"], "main menu options keep the required order")
	menu._show_settings()
	_expect(menu.settings_panel.visible and not menu.menu_panel.visible, "settings opens its functional section")
	_expect(menu.settings_controls.resolution_selector.item_count > 0 and menu.settings_controls.window_mode_selector.item_count == 2, "main menu exposes resolution and window mode settings")
	app_settings.set_resolution(Vector2i(1366, 768))
	app_settings.set_fullscreen(false)
	app_settings.set_vsync(false)
	app_settings.resolution = Vector2i(1280, 720)
	app_settings.vsync = true
	_expect(app_settings.load_settings() and app_settings.resolution == Vector2i(1366, 768) and not app_settings.vsync, "display settings persist through the shared configuration source")
	menu._hide_settings()

	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(360, 480)]:
		root.size = resolution
		await process_frame
		await process_frame
		var panel_rect: Rect2 = menu.menu_panel.get_global_rect()
		var expected_center := Vector2(resolution) * 0.5
		_expect(panel_rect.get_center().distance_to(expected_center) < 3.0, "menu stays centered at %dx%d" % [resolution.x, resolution.y])
		_expect(panel_rect.size.x <= 460.0 and panel_rect.position.x >= 24.0 and panel_rect.end.x <= resolution.x - 24.0, "menu keeps responsive width and safe margins at %dx%d" % [resolution.x, resolution.y])
		menu._show_settings()
		await process_frame
		var settings_rect: Rect2 = menu.settings_panel.get_global_rect()
		_expect(settings_rect.position.y >= 24.0 and settings_rect.end.y <= resolution.y - 24.0, "settings remain inside the viewport at %dx%d" % [resolution.x, resolution.y])
		menu._hide_settings()

	menu._begin_new_game(false)
	_expect(game_session.start_mode == game_session.StartMode.NEW_GAME and not game_state.character_ready, "new game prepares a clean session")
	game_session.finish_new_game_start()
	_expect(game_state.create_character("knight"), "new game creates a valid initial character")
	menu.queue_free()
	await process_frame

	var main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	main_scene.fog_transition.entrance_duration = 0.01
	main_scene.fog_transition.full_coverage_pause = 0.0
	main_scene.fog_transition.exit_duration = 0.01
	var player = get_first_node_in_group("player")
	_expect(player != null, "new game reaches the playable scene")
	game_state.level = 8
	game_state.souls = 2345
	game_state.attributes["strength"] = 19
	game_state._recalculate_derived_stats()
	game_state.health = game_state.max_health - 37
	game_state.stamina = game_state.max_stamina - 13
	var axe_instances = inventory.add_item("battle_axe", 1)
	inventory.add_item("green_estus", 4)
	_expect(not axe_instances.is_empty() and inventory.equip_instance("right_weapon", axe_instances[0]), "equipment stores an owned item instance")
	game_state.discover_bonfire("ash_camp", Vector3.ZERO)
	var rest_bonfire = get_nodes_in_group("bonfires").filter(func(node): return node.bonfire_id == "ruined_gate")[0]
	rest_bonfire.interact(player)
	await process_frame
	main_scene._on_rest_requested()
	for _frame in range(30):
		if not main_scene.fog_transition.is_active():
			break
		await process_frame
	_expect(save_manager.has_save_file(), "resting at a bonfire creates the save file")
	var saved_data = save_manager.load_game()
	_expect(saved_data != null and int(saved_data["save_version"]) == 2, "save contains its version")
	_expect(saved_data["player"].has("level") and saved_data["player"].has("souls") and saved_data["player"].has("attributes"), "save contains level, souls and attributes")
	_expect(saved_data["player"].has("health") and saved_data["player"].has("stamina") and saved_data["player"].has("souls_to_next_level"), "save contains current resources and next level cost")
	_expect(_same_instances(saved_data["inventory"]["instances"], inventory.item_instances), "save contains every independent item instance")
	_expect(saved_data["world"]["last_bonfire_id"] == "ruined_gate", "save contains the last rested bonfire id")
	var saved_level: int = game_state.level
	var saved_souls: int = game_state.souls
	var saved_strength := int(game_state.attributes["strength"])
	var saved_inventory: Dictionary = inventory.item_instances.duplicate(true)
	var saved_equipment: Dictionary = inventory.equipment.duplicate(true)

	main_scene.queue_free()
	await process_frame
	game_state.level = 1
	game_state.souls = 0
	game_state.attributes["strength"] = 1
	inventory.clear_all()
	_expect(game_session.request_load_game(), "valid save can be requested for loading")
	var loaded_main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(loaded_main)
	await process_frame
	await process_frame
	var loaded_player = get_first_node_in_group("player")
	var expected_spawn: Vector3 = rest_bonfire.global_position if is_instance_valid(rest_bonfire) else database.get_bonfire("ruined_gate").position
	_expect(game_state.current_bonfire_id == "ruined_gate" and loaded_player.global_position.distance_to(expected_spawn + Vector3(0, 0, -1.7)) < 0.1, "loaded player appears at the saved bonfire")
	_expect(game_state.level == saved_level and game_state.souls == saved_souls and int(game_state.attributes["strength"]) == saved_strength, "loaded stats match saved stats")
	_expect(inventory.item_instances == saved_inventory and inventory.equipment == saved_equipment, "loaded instances and equipment ids match the save")

	var duplicate_ids = inventory.add_item("longsword", 3)
	_expect(duplicate_ids.size() == 3 and duplicate_ids[0] != duplicate_ids[1] and duplicate_ids[1] != duplicate_ids[2], "repeated items receive stable independent ids")
	var legacy_data := {
		"save_version": 1,
		"player": game_state.get_save_data(),
		"inventory": {
			"item_counts": {"longsword": 2, "life_ring": 2, "green_estus": 3},
			"equipment": {"right_weapon": "longsword", "ring_1": "life_ring", "ring_2": "life_ring", "consumable": "green_estus"}
		},
		"world": game_state.get_world_save_data()
	}
	_write_test_file(JSON.stringify(legacy_data))
	var loaded_legacy = save_manager.load_game()
	_expect(loaded_legacy != null and inventory.apply_save_data(loaded_legacy["inventory"]), "version 1 inventory migrates without data loss")
	_expect(inventory.get_item_count("longsword") == 2 and inventory.get_item_count("life_ring") == 2 and inventory.get_item_count("green_estus") == 3, "legacy counts become independent instances")
	_expect(inventory.get_equipped_item_id("right_weapon") == "longsword" and inventory.get_equipped_item_id("ring_1") == "life_ring" and inventory.get_equipped_item_id("ring_2") == "life_ring", "legacy equipment maps to compatible unique instances")

	loaded_main.queue_free()
	await process_frame
	_write_test_file("{broken json")
	_expect(save_manager.load_game() == null, "corrupt save is rejected without closing the game")
	var corrupt_menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(corrupt_menu)
	await process_frame
	_expect(corrupt_menu.load_game_button.disabled, "corrupt save cannot enable load game")
	corrupt_menu.queue_free()
	await process_frame
	var malformed_data := {
		"save_version": 1,
		"player": {"level": {}, "attributes": {"strength": []}, "bloodstain_position": [{}, 0, 0]},
		"inventory": {"item_counts": {"longsword": "many"}, "equipment": {"right_weapon": 42}},
		"world": {"discovered_bonfires": [42], "last_bonfire_id": 7}
	}
	_write_test_file(JSON.stringify(malformed_data))
	_expect(game_session.request_load_game(), "save with malformed optional fields can use safe defaults")
	var malformed_main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(malformed_main)
	await process_frame
	await process_frame
	_expect(game_state.character_ready and game_state.level >= 1 and game_state.current_bonfire_id == "ash_camp", "malformed fields do not close the game or replace safe defaults")
	malformed_main.queue_free()
	await process_frame

	var fallback_data: Dictionary = saved_data.duplicate(true)
	fallback_data["world"]["last_bonfire_id"] = "missing_bonfire"
	_write_test_file(JSON.stringify(fallback_data))
	_expect(game_session.request_load_game(), "save with missing bonfire remains loadable")
	var fallback_main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(fallback_main)
	await process_frame
	await process_frame
	var fallback_player = get_first_node_in_group("player")
	var initial_position: Vector3 = database.get_bonfire("ash_camp").position + Vector3(0, 0, -1.7)
	_expect(game_state.current_bonfire_id == "ash_camp" and fallback_player.global_position.distance_to(initial_position) < 0.1, "missing bonfire id uses the initial bonfire fallback")
	fallback_main.queue_free()
	await process_frame

	_write_test_file(JSON.stringify(saved_data))
	var overwrite_menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(overwrite_menu)
	await process_frame
	overwrite_menu._on_new_game_pressed()
	_expect(overwrite_menu.overwrite_dialog.visible and save_manager.has_save_file(), "new game asks before overwriting an existing save")
	overwrite_menu._begin_new_game(false)
	_expect(not save_manager.has_save_file(), "confirmed new game replaces the previous save")
	overwrite_menu.queue_free()
	await process_frame

	save_manager.delete_save()
	save_manager.reset_save_path()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	app_settings.reset_settings_path()
	root.size = Vector2i(1152, 648)
	if failures.is_empty():
		print("SAVE_AND_MAIN_MENU_OK")
		quit(0)
	else:
		print("SAVE_AND_MAIN_MENU_FAILED: ", failures)
		quit(1)
