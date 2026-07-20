extends SceneTree

class ImpactProbe:
	extends Node
	var impact_count := 0
	var last_impact_type := ""

	func spawn_combat_impact(_position: Vector3, _direction: Vector3, impact_type: String):
		impact_count += 1
		last_impact_type = impact_type

	func request_hit_stop(_duration: float):
		pass

var failures: Array[String] = []
var game_state
var inventory
var database
var world: Node3D
var player
var impact_probe: ImpactProbe

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
	impact_probe = ImpactProbe.new()
	root.add_child(impact_probe)
	impact_probe.add_to_group("game")
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
	_expect(player.max_poise == player.player_base_poise + inventory.get_total_poise(), "equipped armor contributes its explicit poise value to the player")

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
	await create_timer(0.15).timeout
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
	await create_timer(dodge_enemy.data.attack_windup - 0.14).timeout
	player._start_roll()
	health_before = game_state.health
	await create_timer(0.38).timeout
	_expect(game_state.health == health_before, "intentional roll avoids telegraphed enemy attack")
	dodge_enemy.set_physics_process(false)

	var poise_hollow = _spawn_enemy("hollow_sword", Vector3(8,0,-8))
	var light_hit = CombatHit.new(player,0,12,Vector3.FORWARD,poise_hollow.global_position,1,"light",201)
	var heavy_hit = CombatHit.new(player,0,36,Vector3.FORWARD,poise_hollow.global_position,4,"heavy",202)
	var poise_start = poise_hollow.poise
	poise_hollow.receive_hit(light_hit)
	var light_loss = poise_start - poise_hollow.poise
	var poise_after_light = poise_hollow.poise
	poise_hollow.receive_hit(heavy_hit)
	var heavy_loss = poise_after_light - poise_hollow.poise
	_expect(heavy_hit.poise_damage >= light_hit.poise_damage * 3.0, "heavy attack carries three times the light poise value")
	_expect(heavy_loss > 0.0 and poise_hollow.state == "stagger", "heavy poise damage breaks the remaining enemy poise")
	poise_hollow.action.cancel()
	poise_hollow.state = "idle"
	poise_hollow.poise = poise_hollow.max_poise - 10.0
	poise_hollow.poise_recovery_timer = poise_hollow.data.poise_recovery_delay
	var hollow_poise_before_recovery = poise_hollow.poise
	poise_hollow._update_poise(poise_hollow.data.poise_recovery_delay * 0.5)
	_expect(poise_hollow.poise == hollow_poise_before_recovery, "enemy poise does not regenerate during its recovery delay")
	poise_hollow._update_poise(poise_hollow.data.poise_recovery_delay)
	poise_hollow._update_poise(10.0)
	_expect(is_equal_approx(poise_hollow.poise, poise_hollow.max_poise), "enemy poise regenerates completely after the delay")
	for weapon in database.list_weapons():
		var weapon_light_damage = game_state.calculate_weapon_damage(weapon, "light")
		var weapon_heavy_damage = game_state.calculate_weapon_damage(weapon, "heavy")
		_expect(weapon_heavy_damage >= weapon_light_damage * 1.65 and weapon_heavy_damage <= weapon_light_damage * 1.75, "%s heavy damage is 1.7x light damage" % weapon.display_name)
		_expect(weapon.heavy_stamina_cost > weapon.light_stamina_cost, "%s keeps its higher heavy stamina cost" % weapon.display_name)
		_expect(weapon.light_poise_damage > 0.0 and weapon.heavy_poise_damage > weapon.light_poise_damage, "%s defines distinct light and heavy poise damage" % weapon.display_name)
	var heavy_guard = _spawn_enemy("axe_brute", Vector3(9,0,-9))
	_expect(heavy_guard.max_poise > poise_hollow.max_poise, "heavy guard has more poise than a weak enemy")
	for weak_enemy_id in ["ash_hound", "hollow_sword"]:
		var weak_enemy = _spawn_enemy(weak_enemy_id, Vector3(10, 0, -10))
		weak_enemy.receive_hit(CombatHit.new(player, 1, 18.0, Vector3.FORWARD, weak_enemy.global_position, 1.0, "light", 230 + weak_enemy.get_instance_id()))
		_expect(weak_enemy.state == "stagger", "%s staggers from one light hit" % weak_enemy_id)
	for strong_enemy_id in ["spear_guard", "axe_brute"]:
		var strong_enemy = _spawn_enemy(strong_enemy_id, Vector3(11, 0, -11))
		strong_enemy.receive_hit(CombatHit.new(player, 1, 30.0, Vector3.FORWARD, strong_enemy.global_position, 1.0, "light", 240 + strong_enemy.get_instance_id()))
		_expect(strong_enemy.state != "stagger", "%s resists the first light hit" % strong_enemy_id)
		strong_enemy.receive_hit(CombatHit.new(player, 1, 30.0, Vector3.FORWARD, strong_enemy.global_position, 1.0, "light", 250 + strong_enemy.get_instance_id()))
		_expect(strong_enemy.state == "stagger", "%s staggers from the second light hit" % strong_enemy_id)

	_reset_player_action()
	player.poise = player.max_poise
	player._start_attack("light")
	player.receive_hit(CombatHit.new(heavy_guard, 0, player.max_poise - 1.0, Vector3.BACK, player.global_position, 1.0, "light", 250))
	_expect(player.action_kind == "attack" and player.is_attacking, "a hit below the player's poise threshold does not interrupt an attack")
	player.receive_hit(CombatHit.new(heavy_guard, 0, 2.0, Vector3.BACK, player.global_position, 1.0, "light", 251))
	_expect(player.action_kind == "stagger" and not player.is_attacking, "accumulated poise damage breaks poise and interrupts the player")
	_reset_player_action()
	player.poise = player.max_poise - 10.0
	player.poise_recovery_timer = player.poise_recovery_delay
	var player_poise_before_recovery = player.poise
	player._update_poise(player.poise_recovery_delay * 0.5)
	_expect(player.poise == player_poise_before_recovery, "player poise does not regenerate while the recovery delay is active")
	player._update_poise(player.poise_recovery_delay)
	player._update_poise(10.0)
	_expect(is_equal_approx(player.poise, player.max_poise), "player poise regenerates completely after avoiding further hits")

	_reset_player_action()
	player.global_position = Vector3(-8.0,0.0,-8.0)
	player.attack_type = "heavy"
	player.attack_direction = Vector3.FORWARD
	player.current_attack_id += 1
	var impact_count_before = impact_probe.impact_count
	_expect(not player._apply_attack_hit() and impact_probe.impact_count == impact_count_before, "missed heavy attack creates no enemy impact")
	var impact_enemy = _spawn_enemy("hollow_sword", player.global_position + Vector3.FORWARD * 1.45)
	player.current_attack_id += 1
	_expect(player._apply_attack_hit(), "heavy attack reports contact with an enemy")
	_expect(impact_probe.impact_count == impact_count_before + 1 and impact_probe.last_impact_type == "heavy", "heavy contact creates exactly one heavy impact")
	impact_enemy.global_position = Vector3(12.0,0.0,-12.0)
	player.global_position = Vector3.ZERO

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

	var ash_victim = _spawn_enemy("hollow_sword", Vector3(4,0,-4))
	ash_victim.receive_hit(CombatHit.new(player,9999,999,Vector3.FORWARD,ash_victim.global_position,9,"heavy",601))
	_expect(ash_victim.is_dead and ash_victim.collision_layer == 0 and ash_victim.collision_mask == 0, "dead enemy keeps a non-colliding corpse")
	_expect(ash_victim.ash_particles != null and not ash_victim.ash_particles.emitting, "ash particles wait for the corpse to settle")
	ash_victim._process(ash_victim.ASH_DISSOLVE_DELAY + 0.5)
	_expect(ash_victim.ash_particles.emitting and ash_victim.dissolve_meshes[0].transparency > 0.0, "corpse dissolves while gray ash rises")
	var ash_process = ash_victim.ash_particles.process_material
	_expect(ash_process.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_BOX and ash_process.emission_box_extents.z >= 1.0, "ash emits across the full fallen body")
	_expect(ash_victim.ash_particles.draw_pass_1 is BoxMesh and ash_victim.ash_particles.draw_pass_1.size.x <= 0.04, "ash uses small irregular fragments instead of spheres")
	_expect(ash_victim.visual_model.scale.is_equal_approx(Vector3.ONE), "ash dissolution keeps the corpse scale unchanged")
	var lingering_ash = ash_victim.ash_particles
	ash_victim.death_elapsed = ash_victim.ASH_DISSOLVE_DURATION - 0.01
	ash_victim._process(0.02)
	_expect(ash_victim.is_queued_for_deletion(), "enemy is removed after the ten second ash cycle")
	_expect(is_instance_valid(lingering_ash) and not lingering_ash.emitting and lingering_ash.get_parent() == world, "existing ash lingers after new emission stops")

	if failures.is_empty():
		print("COMBAT_CORE_OK")
		quit(0)
	else:
		print("COMBAT_CORE_FAILED: ", failures)
		quit(1)
