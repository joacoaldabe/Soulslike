extends SceneTree

func _initialize():
	call_deferred("_run")

func _run():
	var game_state = root.get_node("GameState")
	var inventory = root.get_node("Inventory")
	game_state.reset_runtime_state()
	game_state.create_character("knight")
	for item_id in ["battle_axe", "winged_spear", "mace", "life_ring", "stamina_ring", "green_estus", "soul_shard"]:
		inventory.add_item(item_id, 1)
	var ui = load("res://scenes/UI.tscn").instantiate()
	root.add_child(ui)
	ui.show_hud()
	ui.toggle_inventory()
	ui._select_inventory_slot("right_weapon")
	for capture in [
		[Vector2i(1280, 720), "res://docs/screenshots/inventory_1280x720.png"],
		[Vector2i(1920, 1080), "res://docs/screenshots/inventory_1920x1080.png"],
		[Vector2i(640, 480), "res://docs/screenshots/inventory_640x480.png"]
	]:
		root.size = capture[0]
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var texture := root.get_texture()
		if texture == null or texture.get_image().save_png(capture[1]) != OK:
			push_error("InventoryVisualCapture: no se pudo guardar %s." % capture[1])
			quit(1)
			return
	ui._show_inventory_settings_tab()
	root.size = Vector2i(1280, 720)
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://docs/screenshots/inventory_settings_1280x720.png") != OK:
		quit(1)
		return
	ui.queue_free()
	await process_frame
	var menu = load("res://scenes/MainMenu.tscn").instantiate()
	root.add_child(menu)
	menu._show_settings()
	await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png("res://docs/screenshots/main_menu_settings_1280x720.png") != OK:
		quit(1)
		return
	print("INVENTORY_CAPTURES_OK")
	quit(0)
