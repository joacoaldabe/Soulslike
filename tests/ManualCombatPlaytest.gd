extends SceneTree

var player
var command_path := ""
var last_command := ""
var command_busy := false
var selected_enemy = null

func _initialize():
	call_deferred("_start_session")

func _start_session():
	var game_state = root.get_node("GameState")
	game_state.create_character("knight")
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await create_timer(0.4).timeout
	player = get_first_node_in_group("player")
	player.combat_debug = true
	player.global_position = Vector3(0.0,0.0,1.8)
	player.rotation.y = 0.0
	player.camera_pivot.rotation = Vector3.ZERO
	player.camera_pitch.rotation_degrees.x = -14.0
	player.camera_pivot.global_position = player.global_position + Vector3.UP * player.camera_pivot_height
	var positions = {
		"hollow_sword": Vector3(0.0,0.0,-3.2),
		"axe_brute": Vector3(-5.0,0.0,-7.0),
		"spear_guard": Vector3(5.0,0.0,-8.5),
		"ash_hound": Vector3(-8.0,0.0,-12.0)
	}
	for enemy in get_nodes_in_group("enemies"):
		enemy.global_position = positions.get(enemy.enemy_id, enemy.global_position)
		enemy.set_physics_process(false)
	command_path = ProjectSettings.globalize_path("res://.godot/manual_command.txt")
	print("MANUAL_COMBAT_PLAYTEST_READY")
	while true:
		await process_frame
		_poll_command()

func _poll_command():
	if command_busy or command_path == "" or not FileAccess.file_exists(command_path):
		return
	var file = FileAccess.open(command_path,FileAccess.READ)
	var command = file.get_as_text().strip_edges()
	if command == "" or command == last_command:
		return
	last_command = command
	command_busy = true
	_execute_command(command)

func _execute_command(raw_command: String):
	var parts = raw_command.split("|")
	var command = parts[1] if parts.size() > 1 else ""
	var argument = parts[2] if parts.size() > 2 else ""
	match command:
		"move_forward", "move_back", "move_left", "move_right":
			Input.action_press(command)
			await create_timer(float(argument) if argument != "" else 0.35,true,false,true).timeout
			Input.action_release(command)
		"run_forward":
			Input.action_press("move_forward")
			Input.action_press("run")
			await create_timer(float(argument) if argument != "" else 0.45,true,false,true).timeout
			Input.action_release("run")
			Input.action_release("move_forward")
		"light_attack", "heavy_attack", "roll", "lock_on":
			var press = InputEventAction.new()
			press.action = command
			press.pressed = true
			Input.parse_input_event(press)
			await physics_frame
			var release = InputEventAction.new()
			release.action = command
			release.pressed = false
			Input.parse_input_event(release)
		"camera_yaw":
			player.camera_pivot.rotate_y(deg_to_rad(float(argument)))
		"reset_target":
			_reset_target(argument)
		"begin_target_attack":
			if selected_enemy != null and is_instance_valid(selected_enemy):
				selected_enemy.set_physics_process(true)
				selected_enemy._begin_attack(player)
		"debug_off":
			player.combat_debug = false
			if selected_enemy != null and is_instance_valid(selected_enemy):
				selected_enemy.combat_debug = false
		"engage":
			for enemy in get_nodes_in_group("enemies"):
				enemy.set_physics_process(true)
		"capture":
			await RenderingServer.frame_post_draw
			var image = root.get_texture().get_image()
			image.save_png("res://.godot/manual_%s.png" % argument)
		"status":
			var target_state = {}
			var target_distance = -1.0
			if player.lock_target != null and is_instance_valid(player.lock_target):
				target_state = player.lock_target.get_combat_debug_state()
				target_distance = player.global_position.distance_to(player.lock_target.global_position)
			print("MANUAL_STATUS player=",player.get_combat_debug_state()," target=",target_state," distance=",target_distance," health=",root.get_node("GameState").health)
		"quit":
			quit(0)
	print("MANUAL_COMMAND_DONE ",raw_command)
	command_busy = false

func _reset_target(enemy_id: String):
	player.action.cancel()
	player._finish_action()
	player._release_lock_target()
	player.global_position = Vector3(0.0, 0.0, 1.8)
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.camera_pivot.rotation = Vector3.ZERO
	player.camera_pitch.rotation_degrees.x = -14.0
	player.camera_pivot.global_position = player.global_position + Vector3.UP * player.camera_pivot_height
	player.poise = player.max_poise
	player.poise_recovery_timer = 0.0
	player.stagger_immunity_timer = 0.0
	root.get_node("GameState").health = root.get_node("GameState").max_health
	root.get_node("GameState").stamina = root.get_node("GameState").max_stamina
	selected_enemy = null
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.action.cancel()
		enemy.state = "idle"
		enemy.velocity = Vector3.ZERO
		enemy.attack_has_hit = false
		enemy.attack_cooldown = 0.0
		enemy.health = enemy.data.max_health
		enemy.poise = enemy.max_poise
		if enemy.enemy_id == enemy_id:
			selected_enemy = enemy
		else:
			enemy.global_position = Vector3(12.0, 0.0, -12.0)
	if selected_enemy != null:
		selected_enemy.global_position = player.global_position + Vector3.FORWARD * min(selected_enemy.data.attack_range * 0.92, 1.35)
		selected_enemy.rotation.y = PI
		player.lock_target = selected_enemy
		selected_enemy.set_lock_targeted(true)
