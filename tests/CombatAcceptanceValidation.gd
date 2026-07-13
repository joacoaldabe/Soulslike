extends SceneTree

var failures: Array[String] = []
var game_state
var world: Node3D
var player
var attack_id := 1000

func _initialize():
	call_deferred("_run")

func _expect(condition: bool, message: String):
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _spawn_enemy(enemy_id: String, position: Vector3, active := false):
	var enemy = load("res://scenes/Enemy.tscn").instantiate()
	enemy.enemy_id = enemy_id
	enemy.position = position
	world.add_child(enemy)
	enemy.set_physics_process(active)
	return enemy

func _reset_player(position := Vector3.ZERO):
	Input.action_release("move_forward")
	Input.action_release("move_back")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("run")
	player._release_lock_target()
	player.action.cancel()
	player._finish_action()
	player.global_position = position
	player.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.camera_pivot.rotation = Vector3.ZERO
	player.camera_pitch.rotation_degrees.x = -14.0
	player.camera_pivot.global_position = position + Vector3.UP * player.camera_pivot_height
	player.last_move_age = 999.0
	player.last_move_direction = Vector3.FORWARD
	player.poise = player.max_poise
	player.poise_recovery_timer = 0.0
	player.stagger_immunity_timer = 0.0
	game_state.health = game_state.max_health
	game_state.stamina = game_state.max_stamina
	await physics_frame

func _hold(action_name: String, duration: float):
	Input.action_press(action_name)
	await create_timer(duration).timeout
	Input.action_release(action_name)
	await physics_frame

func _wait_for_phase(owner, phase: String, max_frames := 240) -> bool:
	for _frame in range(max_frames):
		if owner.action.get_phase() == phase:
			return true
		if not owner.action.is_active():
			return false
		await physics_frame
	return false

func _wait_for_action(owner, max_frames := 360):
	for _frame in range(max_frames):
		if not owner.action.is_active():
			return
		await physics_frame

func _next_hit(attacker, damage: int, poise_damage: float, direction: Vector3, impact := "light") -> CombatHit:
	attack_id += 1
	return CombatHit.new(attacker, damage, poise_damage, direction, Vector3.ZERO, 3.0, impact, attack_id)

func _run():
	game_state = root.get_node("GameState")
	_expect(game_state.create_character("knight"), "acceptance character created")
	world = Node3D.new()
	root.add_child(world)
	var floor = StaticBody3D.new()
	var floor_collision = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(40.0, 0.2, 40.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	floor.add_child(floor_collision)
	world.add_child(floor)
	player = load("res://scenes/Player.tscn").instantiate()
	world.add_child(player)
	await physics_frame
	await physics_frame

	# 1-2: camera-relative locomotion in every planar direction.
	await _reset_player()
	var origin = player.global_position
	await _hold("move_forward", 0.16)
	_expect((player.global_position - origin).dot(Vector3.FORWARD) > 0.35, "1 forward movement follows visible forward")
	await _reset_player()
	origin = player.global_position
	await _hold("move_back", 0.16)
	_expect((player.global_position - origin).dot(Vector3.BACK) > 0.35, "1 backward movement is correct")
	await _reset_player()
	origin = player.global_position
	await _hold("move_left", 0.16)
	_expect((player.global_position - origin).dot(Vector3.LEFT) > 0.35, "1 left movement is correct")
	await _reset_player()
	origin = player.global_position
	await _hold("move_right", 0.16)
	_expect((player.global_position - origin).dot(Vector3.RIGHT) > 0.35, "1 right movement is correct")
	await _reset_player()
	player.camera_pivot.rotation.y = deg_to_rad(62.0)
	var camera_forward = player.get_camera_planar_forward()
	origin = player.global_position
	await _hold("move_forward", 0.18)
	var camera_move = player.global_position - origin
	_expect(camera_move.normalized().dot(camera_forward) > 0.94, "2 rotating camera changes movement direction consistently")
	_expect(player.get_logical_forward().dot(camera_move.normalized()) > 0.90, "2 body and visual forward follow camera-relative movement")

	# 3-7: attack direction, lock-on and front/back discrimination.
	await _reset_player()
	var front = _spawn_enemy("hollow_sword", Vector3(0, 0, -1.45))
	var behind = _spawn_enemy("hollow_sword", Vector3(0, 0, 1.45))
	var front_health = front.health
	var behind_health = behind.health
	player._start_attack("light")
	_expect(player.attack_direction.dot(Vector3.FORWARD) > 0.99, "3 attack without movement uses camera forward")
	_expect(player.action.get_phase() == "windup" and not player.action.is_hitbox_active(), "3 light attack starts with inactive wind-up")
	_expect(await _wait_for_phase(player, "active"), "6 light attack reaches active phase")
	_expect(player.action.is_hitbox_active(), "6 player hitbox is active only during active phase")
	await physics_frame
	_expect(front.health < front_health, "6 enemy in front is hit")
	_expect(behind.health == behind_health, "7 enemy behind is not hit without turning")
	await _wait_for_action(player)

	await _reset_player()
	front.global_position = Vector3(2.0, 0, 0)
	player.lock_target = front
	front.set_lock_targeted(true)
	front_health = front.health
	player._start_attack("light")
	_expect(player.attack_direction.dot(Vector3.RIGHT) > 0.95, "5 lock-on attack points at selected target")
	await _wait_for_phase(player, "active")
	await physics_frame
	_expect(front.health < front_health, "5 lock-on attack reaches selected target")
	await _wait_for_action(player)
	front.global_position = Vector3(12, 0, -12)
	behind.global_position = Vector3(12, 0, 12)

	await _reset_player()
	Input.action_press("move_right")
	await physics_frame
	player._start_attack("light")
	Input.action_release("move_right")
	_expect(player.attack_direction.dot(Vector3.RIGHT) > 0.90, "4 attack with movement follows current input")
	await _wait_for_action(player)

	# 8-9: chaining and distinct heavy timing.
	await _reset_player()
	player._start_attack("light")
	var light_duration = player.action.get_total_duration()
	var first_sequence = player.current_attack_id
	await _wait_for_phase(player, "recovery")
	while player.action.is_active() and player.action.get_phase_progress() < 0.5:
		await physics_frame
	Input.action_press("light_attack")
	await physics_frame
	Input.action_release("light_attack")
	for _frame in range(90):
		if player.current_attack_id > first_sequence:
			break
		await physics_frame
	_expect(player.current_attack_id > first_sequence and player.action_kind == "attack", "8 late-recovery input chains consecutive light attacks")
	await _wait_for_action(player)
	await _reset_player()
	var stamina_before_heavy = game_state.stamina
	player._start_attack("heavy")
	var heavy_duration = player.action.get_total_duration()
	_expect(player.attack_type == "heavy" and heavy_duration >= light_duration * 1.65, "9 heavy attack is roughly 70 percent slower")
	_expect(player.action.get_phase_duration() > light_duration * 0.60, "9 heavy wind-up is visibly longer")
	_expect(game_state.stamina == stamina_before_heavy - root.get_node("Inventory").get_equipped_weapon().heavy_stamina_cost, "9 heavy attack spends the equipped weapon heavy stamina cost")
	await _wait_for_action(player)

	# 10-12: six-phase directional roll behavior.
	await _reset_player()
	Input.action_press("move_forward")
	await physics_frame
	origin = player.global_position
	player._start_roll()
	Input.action_release("move_forward")
	var forward_roll = player.roll_direction
	_expect(forward_roll.dot(Vector3.FORWARD) > 0.95, "10 forward roll follows input")
	_expect(player.action.phases.size() == 6, "10 roll exposes prepare, impulse, i-frames, travel, landing and recovery")
	await _wait_for_action(player)
	_expect((player.global_position - origin).dot(forward_roll) > 3.0, "10 roll produces the extended physical displacement")

	await _reset_player()
	var roll_target = _spawn_enemy("hollow_sword", Vector3(0, 0, -3))
	player.lock_target = roll_target
	roll_target.set_lock_targeted(true)
	player._start_roll()
	_expect(player.roll_direction.dot(Vector3.BACK) > 0.95, "11 neutral roll during lock-on moves backward")
	await _wait_for_action(player)
	await _reset_player()
	roll_target.global_position = Vector3(0, 0, -3)
	player.lock_target = roll_target
	roll_target.set_lock_targeted(true)
	Input.action_press("move_right")
	await physics_frame
	var camera_right = player._get_camera_planar_right()
	player._start_roll()
	Input.action_release("move_right")
	_expect(player.roll_direction.dot(camera_right) > 0.90, "12 lateral roll during lock-on follows input")
	await _wait_for_action(player)
	roll_target.global_position = Vector3(12, 0, -12)

	# 13-15: damage around i-frames and attack interruption.
	await _reset_player()
	var health_before = game_state.health
	player._start_roll()
	player.receive_hit(_next_hit(null, 5, 0, Vector3.FORWARD))
	_expect(game_state.health < health_before, "13 damage applies before i-frames")
	_expect(await _wait_for_phase(player, "invulnerable"), "14 roll reaches explicit i-frame phase")
	health_before = game_state.health
	player.receive_hit(_next_hit(null, 8, 0, Vector3.FORWARD))
	_expect(game_state.health == health_before, "14 damage is rejected during i-frames")
	await _wait_for_action(player)
	health_before = game_state.health
	player.receive_hit(_next_hit(null, 5, 0, Vector3.FORWARD))
	_expect(game_state.health < health_before, "13 damage applies after i-frames")

	await _reset_player()
	player._start_attack("heavy")
	player.receive_hit(_next_hit(roll_target, 1, player.max_poise + 1.0, Vector3.BACK, "enemy_brute"))
	_expect(player.action_kind == "stagger" and not player.is_attacking, "15 stagger interrupts an attack and cancels its hitbox")
	_expect(not player.action.is_hitbox_active(), "25 interrupted player attack cannot leave a hitbox active")
	await _wait_for_action(player)

	# 16-18: real light/heavy damage and heavy-enemy poise.
	await _reset_player()
	var hollow = _spawn_enemy("hollow_sword", Vector3(0, 0, -1.45))
	var hollow_health = hollow.health
	player._start_attack("light")
	await _wait_for_phase(player, "active")
	await physics_frame
	var light_damage = hollow_health - hollow.health
	_expect(light_damage > 0, "16 light attack damages a Hollow")
	await _wait_for_action(player)
	await _reset_player()
	hollow.global_position = Vector3(0, 0, -1.45)
	hollow_health = hollow.health
	player._start_attack("heavy")
	await _wait_for_phase(player, "active")
	await physics_frame
	var heavy_damage = hollow_health - hollow.health
	_expect(heavy_damage >= light_damage * 1.65, "17 heavy attack damages a Hollow by roughly 1.7x light")
	await _wait_for_action(player)
	if is_instance_valid(hollow):
		hollow.global_position = Vector3(12, 0, -10)

	var brute = _spawn_enemy("axe_brute", Vector3(8, 0, -8))
	var brute_start_poise = brute.poise
	for hit_index in range(3):
		brute.receive_hit(_next_hit(player, 1, 30.0, Vector3.FORWARD, "heavy"))
	_expect(brute.state != "stagger" and brute.poise < brute_start_poise, "18 heavy guard resists several heavy poise hits")
	brute.receive_hit(_next_hit(player, 1, 30.0, Vector3.FORWARD, "heavy"))
	_expect(brute.state == "stagger", "18 repeated heavy hits eventually stagger the guard")
	_expect(brute.action.get_phase_duration() >= 0.70, "18 heavy poise break produces a longer stagger")

	# 19: each archetype can be intentionally rolled through on its own timing.
	for enemy_id in ["hollow_sword", "axe_brute", "spear_guard", "ash_hound"]:
		await _reset_player()
		var dodge_enemy = _spawn_enemy(enemy_id, Vector3(0, 0, -1.15), true)
		dodge_enemy._begin_attack(player)
		await create_timer(max(0.01, dodge_enemy.data.attack_windup - 0.14)).timeout
		player._start_roll()
		health_before = game_state.health
		await create_timer(0.36).timeout
		_expect(game_state.health == health_before, "19 %s attack can be dodged from its telegraph" % enemy_id)
		dodge_enemy.set_physics_process(false)
		dodge_enemy.global_position = Vector3(14, 0, -14)
		await _wait_for_action(player)

	# Telegraph transforms are distinct for every archetype, including the hound.
	for enemy_id in ["hollow_sword", "axe_brute", "spear_guard", "ash_hound"]:
		var telegraph = _spawn_enemy(enemy_id, Vector3(10, 0, -10))
		telegraph.visual_model.set_combat_state("idle", 0.0)
		await process_frame
		var base_position = telegraph.visual_model.body_root.position
		var base_rotation = telegraph.visual_model.body_root.rotation
		var base_weapon_rotation = telegraph.visual_model.weapon_root.rotation if telegraph.visual_model.weapon_root != null else Vector3.ZERO
		telegraph.visual_model.set_combat_state("windup", 0.82)
		await process_frame
		var body_changed = not telegraph.visual_model.body_root.position.is_equal_approx(base_position) or not telegraph.visual_model.body_root.rotation.is_equal_approx(base_rotation)
		var weapon_changed = telegraph.visual_model.weapon_root != null and not telegraph.visual_model.weapon_root.rotation.is_equal_approx(base_weapon_rotation)
		_expect(body_changed or weapon_changed, "%s has a visible body/weapon telegraph" % enemy_id)

	# Enemy damage is confined to active phase and active tracking is locked.
	await _reset_player()
	var phase_enemy = _spawn_enemy("hollow_sword", Vector3(0, 0, -1.1), true)
	phase_enemy._begin_attack(player)
	health_before = game_state.health
	await create_timer(phase_enemy.data.attack_windup * 0.70).timeout
	_expect(game_state.health == health_before and not phase_enemy.action.is_hitbox_active(), "enemy wind-up cannot deal damage")
	var locked_direction = phase_enemy.attack_direction
	await _wait_for_phase(phase_enemy, "active")
	player.global_position += Vector3.RIGHT * 2.0
	await physics_frame
	_expect(phase_enemy.attack_direction.is_equal_approx(locked_direction), "enemy stops perfect tracking during active phase")
	phase_enemy.set_physics_process(false)

	# 20-22 and 25: death/cancellation state rules.
	await _reset_player()
	var windup_victim = _spawn_enemy("hollow_sword", Vector3(0, 0, -1.2), true)
	windup_victim._begin_attack(player)
	windup_victim.receive_hit(_next_hit(player, 9999, 999.0, Vector3.FORWARD, "heavy"))
	_expect(windup_victim.is_dead and not windup_victim.action.is_hitbox_active(), "20 killing during wind-up cancels attack immediately")

	var recovery_victim = _spawn_enemy("hollow_sword", Vector3(8, 0, -8), true)
	recovery_victim._begin_attack(player)
	_expect(await _wait_for_phase(recovery_victim, "recovery"), "21 enemy reaches exposed recovery")
	recovery_victim.receive_hit(_next_hit(player, 9999, 999.0, Vector3.FORWARD, "heavy"))
	_expect(recovery_victim.is_dead and not recovery_victim.action.is_hitbox_active(), "21 killing during recovery cancels every combat state")

	var lock_victim = _spawn_enemy("hollow_sword", Vector3(0, 0, -1.2))
	player.lock_target = lock_victim
	lock_victim.set_lock_targeted(true)
	lock_victim.receive_hit(_next_hit(player, 9999, 999.0, Vector3.FORWARD, "heavy"))
	player._validate_lock_target()
	_expect(player.lock_target == null, "22 lock-on releases when target dies")

	var cancelled = _spawn_enemy("spear_guard", Vector3(7, 0, -7))
	cancelled._begin_attack(player)
	cancelled.action.cancel()
	_expect(not cancelled.action.is_active() and not cancelled.action.is_hitbox_active(), "25 cancelled enemy action cannot retain an active hitbox")

	# Impact reactions are directional on both combatant types.
	await _reset_player()
	await process_frame
	var player_chest_before = player.visual_model.chest.rotation
	player.receive_hit(_next_hit(cancelled, 1, 2.0, Vector3.RIGHT, "light"))
	await process_frame
	_expect(not player.visual_model.chest.rotation.is_equal_approx(player_chest_before), "player shows a directional body reaction on impact")
	var reaction_enemy = _spawn_enemy("hollow_sword", Vector3(6, 0, -6))
	await process_frame
	var enemy_body_before = reaction_enemy.visual_model.body_root.rotation
	reaction_enemy.receive_hit(_next_hit(player, 1, 2.0, Vector3.LEFT, "light"))
	await process_frame
	_expect(not reaction_enemy.visual_model.body_root.rotation.is_equal_approx(enemy_body_before), "enemy shows a directional body reaction on impact")

	# Wind-up rotation is interpolated and never snaps by 180 degrees.
	await _reset_player()
	player.camera_pivot.rotation.y = deg_to_rad(90.0)
	player._start_attack("light")
	var previous_yaw = player.rotation.y
	var largest_yaw_step := 0.0
	while player.action.is_active():
		await physics_frame
		largest_yaw_step = max(largest_yaw_step, abs(angle_difference(previous_yaw, player.rotation.y)))
		previous_yaw = player.rotation.y
	_expect(largest_yaw_step < deg_to_rad(45.0), "attacks contain no sudden 180-degree rotation")

	# 23 is exercised with rendered SpringArm collision in VisualSmoke. 24 is
	# inspected in the generated active/wind-up captures because it is visual.
	_expect(player.spring_arm.collision_mask == 1 and player.spring_arm.margin > 0.0, "23 camera collision remains configured for scenario geometry")
	_expect(player.visual_model.get_armor_slot("right_weapon").get_child_count() > 0, "24 equipped weapon remains attached to the animated hand")

	if failures.is_empty():
		print("COMBAT_ACCEPTANCE_OK")
		quit(0)
	else:
		print("COMBAT_ACCEPTANCE_FAILED: ", failures)
		quit(1)
