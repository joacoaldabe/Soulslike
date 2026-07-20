extends SceneTree

var main_scene
var player
var enemy

func _initialize():
	call_deferred("_run")

func _capture(file_name: String):
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var error = image.save_png("res://.godot/%s.png" % file_name)
	if error != OK:
		push_error("Could not save combat capture: " + file_name)

func _wait_for_phase(owner, expected: String, max_frames := 180):
	for _frame in range(max_frames):
		if owner.action.get_phase() == expected:
			return true
		await physics_frame
	return false

func _run():
	var game_state = root.get_node("GameState")
	game_state.create_character("knight")
	main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await create_timer(0.45).timeout
	player = get_first_node_in_group("player")
	var enemies = get_nodes_in_group("enemies")
	enemy = enemies.filter(func(candidate): return candidate.enemy_id == "hollow_sword")[0]
	for other in enemies:
		other.set_physics_process(false)
	var test_floor = StaticBody3D.new()
	var floor_collision = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(12.0, 0.2, 12.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	test_floor.add_child(floor_collision)
	main_scene.add_child(test_floor)
	player.global_position = Vector3(0,0,1.8)
	player.rotation.y = 0.0
	player.camera_pivot.rotation = Vector3.ZERO
	player.camera_pitch.rotation_degrees.x = -14.0
	player.camera_pivot.global_position = player.global_position + Vector3.UP * player.camera_pivot_height
	enemy.global_position = Vector3(0,0,-0.25)
	enemy.rotation.y = 0.0
	await create_timer(0.35).timeout
	await _capture("combat_camera_orientation")

	player._start_attack("light")
	await create_timer(player.action.get_phase_duration() * 0.62).timeout
	await _capture("combat_player_windup")
	await _wait_for_phase(player,"active")
	await create_timer(player.action.get_phase_duration() * 0.5).timeout
	await _capture("combat_player_active")
	await _wait_for_phase(player,"recovery")
	await _capture("combat_player_recovery")
	await create_timer(0.55).timeout

	player.action.cancel()
	player._finish_action()
	enemy.health = enemy.data.max_health
	enemy.poise = enemy.max_poise
	enemy.global_position = player.global_position + player.get_logical_forward() * 1.55
	player._start_attack("heavy")
	await _wait_for_phase(player,"active")
	await create_timer(0.06).timeout
	await _capture("combat_heavy_trail_impact")
	await create_timer(0.55).timeout

	player.action.cancel()
	player._finish_action()
	game_state.health = game_state.max_health
	enemy.health = enemy.data.max_health
	enemy.poise = enemy.max_poise
	enemy.set_physics_process(true)
	enemy.global_position = player.global_position + player.get_logical_forward() * 2.05 + player.global_transform.basis.x * 0.72
	enemy._begin_attack(player)
	await create_timer(enemy.data.attack_windup * 0.62).timeout
	await _capture("combat_enemy_windup")
	await _wait_for_phase(enemy,"active")
	await create_timer(enemy.action.get_phase_duration() * 0.45).timeout
	await _capture("combat_enemy_active")
	enemy.set_physics_process(false)
	enemy.global_position = player.global_position + player.get_logical_forward() * 4.0

	player.action.cancel()
	player._finish_action()
	player.lock_target = enemy
	player.roll_direction = -player.get_logical_forward()
	player._start_roll()
	await _wait_for_phase(player,"invulnerable")
	await create_timer(0.11).timeout
	await _capture("combat_roll_iframes")

	player.action.cancel()
	player._finish_action()
	player.receive_hit(CombatHit.new(enemy,1,player.max_poise + 5.0,Vector3.BACK,player.global_position + Vector3.UP,5.0,"enemy_brute",9001))
	await create_timer(0.13).timeout
	await _capture("combat_player_stagger")

	print("COMBAT_VISUAL_CAPTURE_OK")
	quit(0)
