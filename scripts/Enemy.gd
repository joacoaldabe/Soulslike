extends CharacterBody3D

const GRAVITY = 24.0
const ASH_DISSOLVE_DURATION := 10.0
const ASH_DISSOLVE_DELAY := 1.20

@export var enemy_id = "hollow_sword"
@export var combat_debug := false

var data = null
var health := 1
var visual_model: EnemyModel = null
var debug_label: Label3D = null
var action := CombatAction.new()
var state := "idle"
var attack_cooldown := 0.0
var attack_direction := Vector3.FORWARD
var attack_lunge_distance := 0.0
var attack_retreat_distance := 0.0
var attack_has_hit := false
var attack_sequence := 0
var current_attack_id := 0
var is_dead := false
var max_poise := 1.0
var poise := 1.0
var poise_recovery_timer := 0.0
var stagger_immunity_timer := 0.0
var received_attack_ids := {}
var death_elapsed := 0.0
var ash_particles: GPUParticles3D = null
var dissolve_meshes: Array[MeshInstance3D] = []

func _ready():
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	data = Database.get_enemy(enemy_id)
	if data == null:
		push_warning("Missing enemy data: %s" % enemy_id)
		queue_free()
		return
	health = data.max_health
	max_poise = data.max_poise
	poise = max_poise
	_setup_visuals()

func _setup_visuals():
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.height = 1.6
	capsule.radius = 0.35
	collision.shape = capsule
	collision.position.y = 0.8
	add_child(collision)

	visual_model = EnemyModel.new()
	visual_model.name = "VisualModel"
	add_child(visual_model)
	visual_model.build(data.moveset)

	debug_label = Label3D.new()
	debug_label.position = Vector3(0.0, 2.55, 0.0)
	debug_label.font_size = 28
	debug_label.outline_size = 6
	debug_label.no_depth_test = true
	debug_label.visible = combat_debug
	add_child(debug_label)

func _physics_process(delta):
	if data == null or is_dead:
		return
	attack_cooldown = max(0.0, attack_cooldown - delta)
	stagger_immunity_timer = max(0.0, stagger_immunity_timer - delta)
	_update_poise(delta)
	_apply_gravity(delta)
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		_stop_horizontal(delta)
		move_and_slide()
		return
	if player.get("is_resting_at_bonfire") == true:
		action.cancel()
		attack_has_hit = false
		state = "idle"
		_stop_horizontal(delta, 16.0)
		move_and_slide()
		_update_visual_state()
		return

	if action.is_active():
		_update_action(delta, player)
	else:
		_update_ai(delta, player)
	move_and_slide()
	_update_visual_state()
	_update_debug_label()

func _process(delta):
	if not is_dead:
		return
	death_elapsed += delta
	if death_elapsed < ASH_DISSOLVE_DELAY:
		return
	var dissolve_progress = clamp((death_elapsed - ASH_DISSOLVE_DELAY) / (ASH_DISSOLVE_DURATION - ASH_DISSOLVE_DELAY), 0.0, 1.0)
	if ash_particles != null:
		ash_particles.emitting = true
	for mesh in dissolve_meshes:
		if is_instance_valid(mesh):
			mesh.transparency = dissolve_progress
	if death_elapsed >= ASH_DISSOLVE_DURATION:
		_release_ash_particles()
		queue_free()

func _update_ai(delta: float, player):
	var offset = player.global_position - global_position
	offset.y = 0.0
	var distance = offset.length()
	if distance > data.aggro_range:
		state = "idle"
		_stop_horizontal(delta)
		return
	var preferred_distance = _preferred_combat_distance()
	if distance < preferred_distance:
		state = "reposition"
		var retreat_direction = -offset.normalized()
		_turn_toward(offset.normalized(), delta, 9.0)
		velocity.x = retreat_direction.x * data.move_speed * 0.72
		velocity.z = retreat_direction.z * data.move_speed * 0.72
		return
	var engagement_range = data.attack_range + min(0.45, data.move_speed * 0.16)
	if distance > engagement_range:
		state = "chase"
		var direction = offset.normalized()
		_turn_toward(direction, delta, 8.0)
		velocity.x = direction.x * data.move_speed
		velocity.z = direction.z * data.move_speed
	else:
		state = "idle"
		_stop_horizontal(delta, 12.0)
		_turn_toward(offset.normalized(), delta, 9.0)
		if attack_cooldown <= 0.0:
			_begin_attack(player)

func _begin_attack(player):
	var direction = player.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	attack_direction = direction.normalized()
	var preferred_distance = _preferred_combat_distance()
	attack_lunge_distance = clamp(direction.length() - preferred_distance, 0.12, data.attack_lunge)
	attack_retreat_distance = 0.22 + attack_lunge_distance * 0.45
	attack_has_hit = false
	attack_sequence += 1
	current_attack_id = attack_sequence
	state = "windup"
	attack_cooldown = data.attack_cooldown
	action.begin("enemy_attack", [
		{"name":"windup", "duration":data.attack_windup, "tracking":true, "allow_rotation":true, "allow_movement":false, "hitbox_active":false, "interruptible":true},
		{"name":"active", "duration":data.attack_active_time, "tracking":false, "allow_rotation":false, "allow_movement":true, "hitbox_active":true, "interruptible":false},
		{"name":"recovery", "duration":data.attack_recovery, "tracking":false, "allow_rotation":false, "allow_movement":false, "hitbox_active":false, "interruptible":true}
	])

func _update_action(delta: float, player):
	action.update(delta)
	if action.finished:
		state = "idle"
		action.cancel()
		attack_has_hit = false
		return
	state = action.get_phase()
	match state:
		"windup":
			_stop_horizontal(delta, 14.0)
			var target_direction = player.global_position - global_position
			target_direction.y = 0.0
			if target_direction.length_squared() > 0.001:
				var tracking_weight = min(1.0, delta * data.attack_tracking_speed)
				attack_direction = attack_direction.slerp(target_direction.normalized(), tracking_weight).normalized()
				_turn_toward(attack_direction, delta, data.attack_tracking_speed)
		"active":
			var lunge_speed = attack_lunge_distance / max(0.05, data.attack_active_time)
			velocity.x = attack_direction.x * lunge_speed
			velocity.z = attack_direction.z * lunge_speed
			if not attack_has_hit:
				attack_has_hit = _apply_attack_hit(player)
		"recovery":
			var retreat_progress = action.get_phase_progress()
			if retreat_progress < 0.55:
				var retreat_speed = attack_retreat_distance / max(0.05, data.attack_recovery * 0.55)
				velocity.x = -attack_direction.x * retreat_speed
				velocity.z = -attack_direction.z * retreat_speed
			else:
				_stop_horizontal(delta, 10.0)
		"stagger":
			_stop_horizontal(delta, 18.0)

func _apply_attack_hit(player) -> bool:
	if player == null or not is_instance_valid(player) or player.health_is_empty():
		return false
	var offset = player.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.001 or offset.length() > data.attack_range + data.attack_lunge * 0.45:
		return false
	if attack_direction.angle_to(offset.normalized()) > deg_to_rad(data.attack_arc) * 0.5:
		return false
	var damage = data.damage
	if data.moveset == "brute":
		damage = int(round(damage * 1.35))
	elif data.moveset == "lancer":
		damage = int(round(damage * 1.1))
	var hit = CombatHit.new(self, damage, data.poise_damage, attack_direction, player.global_position + Vector3.UP, data.impact_force, "enemy_" + data.moveset, current_attack_id)
	player.receive_hit(hit)
	return true

func receive_hit(hit: CombatHit) -> int:
	if is_dead:
		return 0
	var hit_key = "%s:%d" % [str(hit.attacker.get_instance_id()) if hit.attacker != null else "world", hit.attack_id]
	if received_attack_ids.has(hit_key):
		return 0
	received_attack_ids[hit_key] = true
	if received_attack_ids.size() > 24:
		received_attack_ids.erase(received_attack_ids.keys()[0])
	health -= int(hit.damage)
	poise = max(0.0, poise - hit.poise_damage)
	poise_recovery_timer = data.poise_recovery_delay
	var staggered = poise <= 0.0 and stagger_immunity_timer <= 0.0
	if visual_model != null:
		visual_model.play_hit(hit.direction, "stagger" if staggered else hit.impact_type)
	get_tree().call_group("game", "spawn_combat_impact", global_position + Vector3.UP, hit.direction, hit.impact_type)
	get_tree().call_group("game", "request_hit_stop", 0.07 if hit.impact_type == "heavy" else 0.035)
	if health <= 0:
		_die()
	elif staggered:
		_start_stagger(hit.impact_type == "heavy")
	return hit.damage

func take_damage(amount, source):
	var direction = global_position - source.global_position if source != null else -global_transform.basis.z
	direction.y = 0.0
	return receive_hit(CombatHit.new(source, int(amount), float(amount) * 0.3, direction, global_position + Vector3.UP, 2.0, "light", int(Time.get_ticks_usec())))

func _start_stagger(from_heavy := false):
	action.cancel()
	state = "stagger"
	attack_has_hit = true
	poise = max_poise * 0.30
	stagger_immunity_timer = 0.90 if from_heavy else 0.65
	action.begin("stagger", [{"name":"stagger", "duration":0.70 if from_heavy else 0.46, "interruptible":false}])

func _update_poise(delta: float):
	if poise_recovery_timer > 0.0:
		poise_recovery_timer -= delta
	elif poise < max_poise and state != "stagger":
		poise = min(max_poise, poise + data.poise_recovery_rate * delta)

func _apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1

func _turn_toward(direction: Vector3, delta: float, speed: float):
	if direction.length_squared() < 0.001:
		return
	var desired_yaw = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-speed * delta))

func _stop_horizontal(delta: float, rate := 8.0):
	velocity.x = move_toward(velocity.x, 0.0, data.move_speed * delta * rate)
	velocity.z = move_toward(velocity.z, 0.0, data.move_speed * delta * rate)

func _preferred_combat_distance() -> float:
	return max(1.05, data.attack_range * 0.72)

func _update_visual_state():
	if visual_model == null:
		return
	visual_model.set_moving(state == "chase" or state == "reposition")
	visual_model.set_combat_state(state, action.get_phase_progress())

func set_lock_targeted(value: bool):
	if visual_model != null:
		visual_model.set_targeted(value)

func _die():
	if is_dead:
		return
	is_dead = true
	state = "dead"
	action.cancel()
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	if debug_label != null:
		debug_label.visible = false
	if visual_model != null:
		visual_model.set_targeted(false)
		visual_model.play_death()
		_prepare_dissolve_materials()
		_create_ash_particles()
	GameState.add_souls(data.souls_reward)
	for index in range(data.drop_ids.size()):
		var chance = float(data.drop_chances[index]) if index < data.drop_chances.size() else 0.0
		if randf() <= chance:
			var item_id = data.drop_ids[index]
			Inventory.add_item(item_id, 1)
			var item = Database.get_item(item_id)
			if item != null:
				get_tree().call_group("ui", "notify", "Obtuviste %s." % item.display_name)

func _prepare_dissolve_materials():
	dissolve_meshes.clear()
	for mesh in visual_model.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var source_material = mesh.get_active_material(surface)
			if source_material == null:
				continue
			var fade_material = source_material.duplicate()
			if fade_material is BaseMaterial3D:
				fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.set_surface_override_material(surface, fade_material)
		dissolve_meshes.append(mesh)

func _create_ash_particles():
	ash_particles = GPUParticles3D.new()
	ash_particles.name = "AshDissolve"
	ash_particles.emitting = false
	ash_particles.amount = 210
	ash_particles.lifetime = 3.6
	ash_particles.visibility_aabb = AABB(Vector3(-1.8, 0.0, -1.8), Vector3(3.6, 4.4, 3.6))
	var process = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.48, 0.28, 1.05)
	process.direction = Vector3(0.22, 1.0, 0.08).normalized()
	process.spread = 36.0
	process.initial_velocity_min = 0.65
	process.initial_velocity_max = 1.35
	process.gravity = Vector3(0.16, 0.28, 0.06)
	process.angular_velocity_min = -150.0
	process.angular_velocity_max = 150.0
	process.scale_min = 0.55
	process.scale_max = 1.15
	ash_particles.process_material = process
	var ash_mesh = BoxMesh.new()
	ash_mesh.size = Vector3(0.032, 0.009, 0.018)
	var ash_material = StandardMaterial3D.new()
	ash_material.albedo_color = Color(0.56, 0.59, 0.61, 0.86)
	ash_material.roughness = 1.0
	ash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ash_mesh.material = ash_material
	ash_particles.draw_pass_1 = ash_mesh
	ash_particles.position = Vector3(0.0, 0.34, 1.02)
	add_child(ash_particles)

func _release_ash_particles():
	if ash_particles == null or not is_instance_valid(ash_particles):
		return
	var lingering_particles = ash_particles
	ash_particles = null
	lingering_particles.emitting = false
	lingering_particles.reparent(get_parent(), true)
	get_tree().create_timer(lingering_particles.lifetime).timeout.connect(func():
		if is_instance_valid(lingering_particles):
			lingering_particles.queue_free()
	)

func get_combat_debug_state() -> Dictionary:
	return {
		"state": state,
		"phase": action.get_phase(),
		"hitbox_active": action.get_flag("hitbox_active", false),
		"poise": poise,
		"max_poise": max_poise,
		"attack_direction": attack_direction,
		"attack_id": current_attack_id
	}

func _update_debug_label():
	if debug_label == null:
		return
	debug_label.visible = combat_debug
	if combat_debug:
		debug_label.text = "%s %.0f%%\nPoise %.0f/%.0f\nHitbox %s" % [state, action.get_phase_progress() * 100.0, poise, max_poise, str(action.get_flag("hitbox_active", false))]
