extends SceneTree

const TEST_SAVE_PATH := "user://inventory_menu_exit_test.json"

var failures: Array[String] = []

func _initialize():
	call_deferred("_run")

func _expect(condition: bool, message: String):
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _find_button_with_text(node: Node, text_value: String) -> Button:
	if node is Button and node.text == text_value:
		return node
	for child in node.get_children():
		var result := _find_button_with_text(child, text_value)
		if result != null:
			return result
	return null

func _run():
	var game_state = root.get_node("GameState")
	var inventory = root.get_node("Inventory")
	var save_manager = root.get_node("SaveManager")
	game_state.reset_runtime_state()
	_expect(game_state.create_character("knight"), "test character is created")
	var duplicate_weapons = inventory.add_item("longsword", 2)
	var rings = inventory.add_item("life_ring", 2)
	var consumables = inventory.add_item("green_estus", 2)
	_expect(duplicate_weapons.size() == 2 and duplicate_weapons[0] != duplicate_weapons[1], "duplicate weapons are independent instances")

	var ui = load("res://scenes/UI.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.show_hud()
	ui.toggle_inventory()
	await process_frame
	_expect(ui.inventory_panel.visible and ui.is_blocking_gameplay(), "inventory is centered and blocks gameplay")
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "inventory releases the mouse")
	_expect(_find_button_with_text(ui.inventory_panel, "Cerrar") == null, "inventory has no close button")
	_expect(ui.inventory_tab_button.text == "Inventario" and ui.settings_tab_button.text == "Configuracion", "only the two requested top tabs are present")
	for slot in ui.inventory_slot_buttons:
		var slot_button: Button = ui.inventory_slot_buttons[slot]
		var slot_frame: PanelContainer = ui.inventory_slot_visuals[slot]["frame"]
		var slot_icon: TextureRect = ui.inventory_slot_visuals[slot]["icon"]
		var frame_style: StyleBoxFlat = slot_frame.get_theme_stylebox("panel")
		_expect(slot_button.custom_minimum_size.y >= 90.0 and slot_frame.custom_minimum_size.x == slot_frame.custom_minimum_size.y and frame_style.get_border_width(SIDE_LEFT) == 1 and slot_icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "%s uses a square code-drawn frame around the uncropped item preview" % slot)

	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(640, 480)]:
		root.size = resolution
		await process_frame
		await process_frame
		var rect: Rect2 = ui.inventory_window.get_global_rect()
		_expect(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= resolution.x + 1.0 and rect.end.y <= resolution.y + 1.0, "inventory fits %dx%d" % [resolution.x, resolution.y])
		_expect(rect.get_center().distance_to(Vector2(resolution) * 0.5) < 3.0, "inventory remains centered at %dx%d" % [resolution.x, resolution.y])
		if resolution == Vector2i(1920, 1080):
			_expect(rect.size.x >= 1600.0, "inventory uses the available desktop space for easier reading")

	var previous_weapon: String = inventory.get_equipped_instance_id("right_weapon")
	ui._select_inventory_slot("right_weapon")
	var candidate_index := -1
	for index in range(ui.inventory_candidate_list.item_count):
		if ui.inventory_candidate_list.get_item_metadata(index) == duplicate_weapons[1]:
			candidate_index = index
			break
	_expect(candidate_index >= 0, "every weapon instance appears independently")
	ui._select_inventory_instance(candidate_index)
	_expect(inventory.get_equipped_instance_id("right_weapon") == previous_weapon, "single selection does not equip an item")
	ui._perform_inventory_action()
	_expect(inventory.get_equipped_instance_id("right_weapon") == duplicate_weapons[1], "explicit action equips the selected weapon instance")

	ui._select_inventory_slot("armor")
	ui._select_inventory_instance(0)
	ui._perform_inventory_action()
	_expect(inventory.get_equipped_item_id("armor") == "knight_set", "armor slot equips its category")
	ui._select_inventory_slot("ring_1")
	ui.selected_inventory_instance = rings[0]
	ui._perform_inventory_action()
	ui._select_inventory_slot("ring_2")
	ui.selected_inventory_instance = rings[1]
	ui._perform_inventory_action()
	_expect(inventory.get_equipped_instance_id("ring_1") == rings[0] and inventory.get_equipped_instance_id("ring_2") == rings[1], "ring slots equip distinct instances")

	ui._select_inventory_slot("consumable")
	var consumable_before: int = inventory.get_item_count("green_estus")
	ui.selected_inventory_instance = consumables[1]
	ui._refresh_inventory_details()
	_expect(inventory.get_item_count("green_estus") == consumable_before, "selecting a consumable never uses it")
	ui._perform_inventory_action()
	_expect(inventory.get_equipped_instance_id("consumable") == consumables[1] and inventory.get_item_count("green_estus") == consumable_before, "first explicit action equips the consumable")
	game_state.health = max(1, game_state.health - 50)
	ui._perform_inventory_action()
	_expect(inventory.get_item_count("green_estus") == consumable_before - 1, "second explicit action uses exactly the equipped consumable instance")

	_expect(ui.inventory_detail_icon.texture != null and IconCatalog.get_item_icon("future_unknown") != null, "all item rows have an icon and future items use a fallback")
	_expect(ui.inventory_stats_box.get_child_count() == 20, "status panel groups class, resources, defense, poise and all attributes with readable icons")
	ui._show_inventory_settings_tab()
	_expect(ui.inventory_settings_view.visible and ui.inventory_settings_controls.exit_to_menu_button != null, "inventory settings share display controls and include exit to menu")

	save_manager.set_save_path_for_tests("user://missing_inventory_directory/save.json")
	_expect(not ui._exit_to_main_menu(false) and ui.inventory_panel.visible, "failed exit save keeps the player in the game")
	save_manager.set_save_path_for_tests(TEST_SAVE_PATH)
	save_manager.delete_save()
	_expect(ui._exit_to_main_menu(false) and save_manager.has_valid_save(), "exit to menu succeeds only after a valid save")

	ui._show_inventory_tab()
	ui.toggle_inventory()
	_expect(not ui.inventory_panel.visible, "the inventory action toggles the same overlay closed")
	ui.queue_free()
	save_manager.delete_save()
	save_manager.reset_save_path()
	root.size = Vector2i(1152, 648)
	if failures.is_empty():
		print("INVENTORY_MENU_OK")
		quit(0)
	else:
		print("INVENTORY_MENU_FAILED: ", failures)
		quit(1)
