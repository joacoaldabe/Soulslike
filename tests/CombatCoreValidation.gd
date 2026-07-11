extends SceneTree

var failures: Array[String] = []
var game_state
var inventory
var database
var world: Node3D
var player

func _initialize():
	call_deferred("_run")

func _expect(condition: bool, message: String):
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _spawn_enemy(enemy_id: String, position: Vector3, active_physics := false):
	var enemy = load("res://scenes/Enemy.tscn").instantiate()
	enemy.enemy_id = enemy_id
	enemy.position = position
	world.add_child(enemy)
	enemy.set_physics_process(active_physics)
	return enemy

func _reset_player_action():
	player.action.cancel()
	player._finish_action()
	player.velocity = Vector3.ZERO
	game_state.stamina = game_state.max_stamina

func _run():
	game_state = root.get_node("GameState")
	inventory = root.get_node("Inventory")
	database = root.get_node("Database")
	_expect(game_state.create_character("knight"), "combat test character created")

	world = Node3D.new()
	root.add_child(world)
	var floor = StaticBody3D.new()
	var floor_collision = CollisionShape3D.new()
	var floor_shape = BoxShape3D.new()
	floor_shape.size = Vector3(30,0.2,30)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.1
	floor.add_child(floor_collision)
	world.add_child(floor)

	player = load("res://scenes/Player.tscn").instantiate()
	world.add_child(player)
	await physics_frame
	await physics_frame

	_expect(player.get_logical_forward().dot(Vector3.FORWARD) > 0.99, "logical forward is Godot -Z")
	_expect(player.visual_model.VISUAL_FORWARD == Vector3.FORWARD, "visual model uses the same -Z forward")
	_expect(player.visual_model.head.get_node("Nose").position.z < 0.0, "face geometry points toward visual forward")
	_expect(player.camera_normal_distance >= 4.5 and player.spring_arm.spring_length >= 4.5, "normal camera distance is souls-like scale")
	_expect(player.camera_pivot.top_level, "camera orbit is independent from body rotation")

	var front_enemy = _spawn_enemy("hollow_sword", Vector3(0,0,-1.45))
	var behind_enemy = _spawn_enemy("hollow_sword", Vector3(0,0,1.45))
	var front_health = front_enemy.health
	var behind_health = behind_enemy.health
	player.last_move_age = 999.0
	player.camera_pivot.rotation.y = 0.0
	player.rotation.y = 0.0
	player._start_attack("light")
	_expect(player.action.get_phase() == "windup", "light attack begins in wind-up")
	await create_timer(0.31).timeout
	_expect(front_enemy.health < front_health, "unlocked attack hits visible enemy in front")
	_expect(behind_enemy.health == behind_health, "unlocked attack does not hit enemy behind")
	await create_timer(0.45).timeout

	_reset_player_action()
	front_enemy.global_position = Vector3(2.0,0,0)
	player.lock_target = front_enemy
	front_enemy.set_lock_targeted(true)
	front_health = front_enemy.health
	player._start_attack("light")
	await create_timer(0.31).timeout
	_expect(player.attack_direction.dot(Vector3.RIGHT) > 0.80, "lock-on attack direction follows target")
	_expect(front_enemy.health < front_health, "lock-on attack reaches selected target")
	await create_timer(0.45).timeout
	player._release_lock_target()

	_reset_player_action()
	var health_before = game_state.health
	player._start_roll()
	var pre_iframe_hit = CombatHit.new(null,5,0,Vector3.FORWARD,player.global_position,0,"light",101)
	player.receive_hit(pre_iframe_hit)
	_expect(game_state.health < health_before, "damage applies before roll i-frames")
	await create_timer(0.10).timeout
	health_before = game_state.health
	var iframe_hit = CombatHit.new(null,8,0,Vector3.FORWARD,player.global_position,0,"light",102)
	player.receive_hit(iframe_hit)
	_expect(game_state.health == health_before, "damage is rejected during explicit i-frame phase")
	await create_timer(0.58).timeout
	health_before = game_state.health
	var post_iframe_hit = CombatHit.new(null,5,0,Vector3.FORWARD,player.global_position,0,"light",103)
	player.receive_hit(post_iframe_hit)
	_expect(game_state.health < health_before, "damage applies after roll i-frames")

	_reset_player_action()
	var telegraph_enemy = _spawn_enemy("hollow_sword", player.global_position + player.get_logical_forward() * 1.25, true)
	telegraph_enemy._begin_attack(player)
	health_before = game_state.health
	_expect(telegraph_enemy.state == "windup", "enemy attack starts with visible wind-up")
	await create_timer(telegraph_enemy.data.attack_windup * 0.65).timeout
	_expect(game_state.health == health_before, "enemy deals no damage during wind-up")
	await create_timer(telegraph_enemy.data.attack_windup * 0.45 + telegraph_enemy.data.attack_active_time * 0.5).timeout
	_expect(game_state.health < health_before, "enemy damage occurs in active window")
	telegraph_enemy.set_physics_process(false)

	for enemy_id in ["hollow_sword","axe_brute","spear_guard","ash_hound"]:
		var archetype = _spawn_enemy(enemy_id, Vector3(6,0,-6))
		archetype._begin_attack(player)
		_expect(archetype.state == "windup" and archetype.data.attack_windup >= 0.35, "%s has readable telegraph" % enemy_id)
		_expect(archetype.data.attack_active_time > 0.0 and archetype.data.attack_recovery > 0.0, "%s has active and recovery phases" % enemy_id)

	var dodge_enemy = _spawn_enemy("axe_brute", player.global_position + player.get_logical_forward() * 1.55, true)
	_reset_player_action()
	game_state.health = game_state.max_health
	dodge_enemy._begin_attack(player)
	await create_timer(dodge_enemy.data.attack_windup - 0.09).timeout
	player._start_roll()
	health_before = game_state.health
	await create_timer(0.38).timeout
	_expect(game_state.health == health_before, "intentional roll avoids telegraphed enemy attack")
	dodge_enemy.set_physics_process(false)

	var poise_hollow = _spawn_enemy("hollow_sword", Vector3(8,0,-8))
	var light_hit = CombatHit.new(player,0,12,Vector3.FORWARD,poise_hollow.global_position,1,"light",201)
	var heavy_hit = CombatHit.new(player,0,30,Vector3.FORWARD,poise_hollow.global_position,4,"heavy",202)
	var poise_start = poise_hollow.poise
	poise_hollow.receive_hit(light_hit)
	var light_loss = poise_start - poise_hollow.poise
	var poise_after_light = poise_hollow.poise
	poise_hollow.receive_hit(heavy_hit)
	var heavy_loss = poise_after_light - poise_hollow.poise
	_expect(heavy_loss > light_loss, "heavy attack deals more poise damage")
	var heavy_guard = _spawn_enemy("axe_brute", Vector3(9,0,-9))
	_expect(heavy_guard.max_poise > poise_hollow.max_poise * 2.0, "heavy guard has substantially more poise")

	var duplicate_enemy = _spawn_enemy("hollow_sword", Vector3(10,0,-10))
	var duplicate_hit = CombatHit.new(player,7,5,Vector3.FORWARD,duplicate_enemy.global_position,1,"light",301)
	var duplicate_health = duplicate_enemy.health
	duplicate_enemy.receive_hit(duplicate_hit)
	duplicate_enemy.receive_hit(duplicate_hit)
	_expect(duplicate_enemy.health == duplicate_health - 7, "same attack id cannot hit target twice")

	_reset_player_action()
	player._start_attack("heavy")
	var stagger_hit = CombatHit.new(dodge_enemy,1,player.max_poise + 10,Vector3.BACK,player.global_position,5,"enemy_brute",401)
	player.receive_hit(stagger_hit)
	_expect(player.action_kind == "stagger" and not player.is_attacking, "player stagger interrupts attack")

	var lock_death_enemy = _spawn_enemy("hollow_sword", Vector3(0,0,-1.4))
	player.lock_target = lock_death_enemy
	lock_death_enemy.set_lock_targeted(true)
	lock_death_enemy.receive_hit(CombatHit.new(player,9999,999,Vector3.FORWARD,lock_death_enemy.global_position,9,"heavy",501))
	player._validate_lock_target()
	_expect(player.lock_target == null, "lock-on releases immediately when target dies")

	if failures.is_empty():
		print("COMBAT_CORE_OK")
		quit(0)
	else:
		print("COMBAT_CORE_FAILED: ", failures)
		quit(1)
