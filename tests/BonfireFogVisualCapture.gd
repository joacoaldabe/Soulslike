extends SceneTree

var transition

func _initialize():
	call_deferred("_run")

func _capture(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	var texture := root.get_texture()
	if texture == null:
		return false
	return texture.get_image().save_png("res://.godot/%s.png" % file_name) == OK

func _wait_for_progress(expected_phase: String, minimum_progress: float, max_frames := 300) -> bool:
	for _frame in range(max_frames):
		if transition.phase == expected_phase and transition.phase_progress >= minimum_progress:
			return true
		await process_frame
	return false

func _run():
	var game_state = root.get_node("GameState")
	game_state.create_character("knight")
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await create_timer(0.4).timeout
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var bonfire = main_scene._find_bonfire("ash_camp")
	var player = main_scene.player
	bonfire.interact(player)
	main_scene.ui.hide_bonfire_menu_for_transition()
	await create_timer(0.65).timeout
	transition = main_scene.fog_transition
	transition.entrance_duration = 1.0
	transition.full_coverage_pause = 0.15
	transition.exit_duration = 1.0
	player.set_transition_locked(true)
	if not transition.begin(bonfire):
		quit(1)
		return
	if not await _wait_for_progress("covering", 0.32) or not await _capture("bonfire_fog_cover_32"):
		quit(1)
		return
	if not await _wait_for_progress("covering", 0.72) or not await _capture("bonfire_fog_cover_72"):
		quit(1)
		return
	if not await _wait_for_progress("covered", 1.0) or not await _capture("bonfire_fog_covered"):
		quit(1)
		return
	transition.reveal_from(bonfire)
	if not await _wait_for_progress("revealing", 0.42) or not await _capture("bonfire_fog_reveal_42"):
		quit(1)
		return
	if not await _wait_for_progress("idle", 0.0):
		quit(1)
		return
	player.set_transition_locked(false)
	print("BONFIRE_FOG_CAPTURES_OK")
	quit(0)
