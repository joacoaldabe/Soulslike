extends SceneTree

const TEST_SAVE_PATH := "user://bonfire_fog_transition_test.json"

var failures: Array[String] = []
var game_state
var save_manager

func _initialize():
	call_deferred("_run")

func _expect(condition: bool, message: String):
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _wait_for_phase(transition, expected_phase: String, max_frames := 240) -> bool:
	for _frame in range(max_frames):
		if transition.phase == expected_phase:
			return true
		await process_frame
	return false

func _wait_for_finish(transition, max_frames := 360) -> bool:
	for _frame in range(max_frames):
		if not transition.is_active():
			return true
		await process_frame
	return false

func _run():
	game_state = root.get_node("GameState")
	save_manager = root.get_node("SaveManager")
	save_manager.set_save_path_for_tests(TEST_SAVE_PATH)
	save_manager.delete_save()
	_expect(game_state.create_character("knight"), "fog transition test character is created")
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame
	var transition = main_scene.fog_transition
	transition.entrance_duration = 0.30
	transition.full_coverage_pause = 0.05
	transition.exit_duration = 0.14
	_expect(transition.entrance_duration > 0.0 and transition.exit_duration > 0.0 and transition.expansion_radius >= 1.0 and transition.smoke_speed > 0.0, "main fog controls are exposed and have valid values")
	_expect((transition.overlay.material as ShaderMaterial).shader.code.contains("fog_noise"), "fog uses layered animated noise instead of a flat color screen")

	var source_bonfire = main_scene._find_bonfire("ash_camp")
	var target_bonfire = main_scene._find_bonfire("ruined_gate")
	var player = main_scene.player
	game_state.discover_bonfire("ash_camp", source_bonfire.global_position)
	game_state.discover_bonfire("ruined_gate", target_bonfire.global_position)
	source_bonfire.interact(player)
	game_state.health = game_state.max_health - 40
	var health_before_rest: int = game_state.health
	main_scene._on_rest_requested()
	await process_frame
	_expect(transition.is_active() and player.transition_locked and not main_scene.ui.bonfire_panel.visible, "rest starts one fog transition, hides its menu and locks the player")
	var camera := root.get_camera_3d()
	var viewport_size := root.get_visible_rect().size
	var expected_origin := camera.unproject_position(source_bonfire.global_position + Vector3.UP * 0.65) / viewport_size
	var shader_origin: Vector2 = (transition.overlay.material as ShaderMaterial).get_shader_parameter("origin_uv")
	_expect(shader_origin.distance_to(expected_origin.clamp(Vector2.ZERO, Vector2.ONE)) < 0.03, "fog expansion is projected from the active bonfire")
	_expect(not transition.begin(source_bonfire), "an active fog transition cannot be started twice")
	_expect(game_state.health == health_before_rest, "rest state is not applied before full screen coverage")
	var locked_position: Vector3 = player.global_position
	Input.action_press("move_forward")
	Input.action_press("light_attack")
	await physics_frame
	await physics_frame
	Input.action_release("move_forward")
	Input.action_release("light_attack")
	_expect(player.global_position.distance_to(locked_position) < 0.01 and not player.is_attacking, "movement and attacks remain blocked during fog coverage")
	_expect(await _wait_for_phase(transition, "covered"), "rest fog reaches complete coverage")
	await process_frame
	_expect(transition.is_fully_opaque() and game_state.health == game_state.max_health, "rest executes only while the screen is completely covered")
	_expect(await _wait_for_finish(transition), "rest fog reveals the original bonfire and finishes")
	_expect(not player.transition_locked and not transition.overlay.visible and transition.phase == "idle" and main_scene.ui.bonfire_panel.visible, "rest restores control, menu state and removes the fog overlay")

	main_scene._on_travel_requested("ruined_gate")
	await process_frame
	_expect(transition.is_active() and main_scene.player.transition_locked, "travel starts the shared fog transition and locks the current player")
	_expect(game_state.current_bonfire_id == "ash_camp", "travel does not reposition before complete coverage")
	_expect(await _wait_for_phase(transition, "covered"), "travel fog reaches complete coverage")
	await process_frame
	await process_frame
	var destination_player = main_scene.player
	_expect(transition.is_fully_opaque() and game_state.current_bonfire_id == "ruined_gate", "travel changes destination only behind fully opaque fog")
	_expect(destination_player.transition_locked and destination_player.global_position.distance_to(target_bonfire.global_position) < 2.2, "destination player remains locked while the new camera settles")
	var destination_locked_position: Vector3 = destination_player.global_position
	Input.action_press("move_forward")
	await physics_frame
	Input.action_release("move_forward")
	_expect(destination_player.global_position.distance_to(destination_locked_position) < 0.01, "destination movement stays blocked until fog reveal is complete")
	_expect(await _wait_for_finish(transition), "destination fog disperses and finishes")
	_expect(not destination_player.transition_locked and not transition.overlay.visible and transition.phase == "idle" and not main_scene.ui.bonfire_panel.visible, "travel restores control without leaving fog, menu or blocked state")

	save_manager.delete_save()
	save_manager.reset_save_path()
	if failures.is_empty():
		print("BONFIRE_FOG_TRANSITION_OK")
		quit(0)
	else:
		print("BONFIRE_FOG_TRANSITION_FAILED: ", failures)
		quit(1)
