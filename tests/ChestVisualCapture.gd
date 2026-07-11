extends SceneTree

func _initialize():
	call_deferred("_run")

func _capture(file_name: String):
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var error = image.save_png("res://.godot/%s.png" % file_name)
	if error != OK:
		push_error("Could not save chest capture: " + file_name)

func _run():
	var game_state = root.get_node("GameState")
	game_state.create_character("knight")
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await create_timer(0.4).timeout
	var player = get_first_node_in_group("player")
	var chest = get_nodes_in_group("chests").filter(func(node): return node.loot_mode == "random")[0]
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	player.global_position = chest.global_position + Vector3(0.0,0.0,3.1)
	player.rotation.y = 0.0
	player.camera_pivot.rotation = Vector3.ZERO
	player.camera_pitch.rotation_degrees.x = -17.0
	player.camera_pivot.global_position = player.global_position + Vector3.UP * player.camera_pivot_height
	await create_timer(0.4).timeout
	await _capture("chest_closed")
	chest.interact(player)
	await create_timer(0.65).timeout
	await _capture("chest_open")
	print("CHEST_VISUAL_CAPTURE_OK")
	quit(0)
