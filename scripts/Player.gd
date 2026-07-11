extends CharacterBody3D

const WALK_SPEED = 4.0
const RUN_SPEED = 6.5
const ROLL_SPEED = 11.0
const GRAVITY = 24.0
const STAMINA_REGEN = 28.0
const RUN_STAMINA_PER_SECOND = 12.0
const ROLL_COST = 28
const LOGICAL_FORWARD = Vector3.FORWARD
const PlayerModelScene = preload("res://scenes/PlayerModel.tscn")

@export_group("Camera")
@export var camera_normal_distance := 5.35
@export var camera_lock_distance := 6.25
@export var camera_pivot_height := 1.62
@export var camera_focus_height := 1.15
@export var camera_lateral_offset := 0.42
@export var camera_lock_yaw_offset := -10.5
@export var camera_horizontal_sensitivity := 0.0038
@export var camera_vertical_sensitivity := 0.0030
@export var camera_pitch_min := -42.0
@export var camera_pitch_max := 18.0
@export var camera_follow_speed := 18.0
@export var camera_rotation_speed := 7.5
@export var camera_collision_recovery_speed := 9.0
@export var camera_collision_min_distance := 1.05
@export var combat_debug := false

@export_group("Combat")
@export var player_max_poise := 58.0
@export var poise_recovery_delay := 1.15
@export var poise_recovery_rate := 34.0
@export var stagger_duration := 0.52

var camera_pivot: Node3D = null
var camera_pitch: Node3D = null
var spring_arm: SpringArm3D = null
var camera: Camera3D = null
var visual_model: PlayerModel = null
var debug_label: Label3D = null
var lock_target = null

var action := CombatAction.new()
var action_kind := ""
var is_rolling := false
var is_attacking := false
var attack_type := "light"
var attack_direction := Vector3.FORWARD
var roll_direction := Vector3.FORWARD
var attack_has_hit := false
var attack_sequence := 0
var current_attack_id := 0
var buffered_attack := ""
var last_move_direction := Vector3.FORWARD
var last_move_age := 999.0
var desired_facing := Vector3.FORWARD

var max_poise := 58.0
var poise := 58.0
var poise_recovery_timer := 0.0
var stagger_immunity_timer := 0.0
var camera_shake_strength := 0.0

func _ready():
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	_setup_body()
	_update_equipment_visuals()
	Inventory.equipment_changed.connect(_update_equipment_visuals)
	max_poise = player_max_poise + Inventory.get_total_defense() * 1.4
	poise = max_poise
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_body():
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.height = 1.8
	capsule.radius = 0.35
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

	visual_model = PlayerModelScene.instantiate()
	visual_model.name = "VisualModel"
	add_child(visual_model)

	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraRig"
	camera_pivot.top_level = true
	add_child(camera_pivot)
	camera_pivot.global_position = global_position + Vector3.UP * camera_pivot_height
	camera_pivot.rotation_degrees.y = rotation_degrees.y

	camera_pitch = Node3D.new()
	camera_pitch.name = "CameraPitch"
	camera_pitch.rotation_degrees.x = -14.0
	camera_pivot.add_child(camera_pitch)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm"
	spring_arm.spring_length = camera_normal_distance
	spring_arm.margin = 0.22
	spring_arm.collision_mask = 1
	spring_arm.position.x = camera_lateral_offset
	camera_pitch.add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.fov = 68.0
	camera.near = 0.08
	spring_arm.add_child(camera)

	debug_label = Label3D.new()
	debug_label.name = "CombatDebug"
	debug_label.position = Vector3(0.0, 2.35, 0.0)
	debug_label.font_size = 32
	debug_label.outline_size = 6
	debug_label.no_depth_test = true
	debug_label.visible = combat_debug
	add_child(debug_label)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_pivot.rotate_y(-event.relative.x * camera_horizontal_sensitivity)
		camera_pitch.rotate_x(-event.relative.y * camera_vertical_sensitivity)
		camera_pitch.rotation.x = clamp(camera_pitch.rotation.x, deg_to_rad(camera_pitch_min), deg_to_rad(camera_pitch_max))
	if event.is_action_pressed("inventory"):
		get_tree().call_group("ui", "toggle_inventory")
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("lock_on"):
		_toggle_lock_target()
	if event.is_action_pressed("use_item"):
		var item_id = Inventory.equipment["consumable"]
		if item_id != "" and Inventory.use_consumable(item_id):
			get_tree().call_group("ui", "notify", "Usaste %s." % Database.get_item(item_id).display_name)

func _physics_process(delta):
	if not GameState.character_ready:
		return
	last_move_age += delta
	_update_camera(delta)
	_update_poise(delta)
	_update_action(delta)
	_apply_gravity(delta)
	_validate_lock_target()

	if _ui_blocks_gameplay():
		_stop_horizontal(delta)
		GameState.regen_stamina(STAMINA_REGEN * delta)
	elif action_kind == "roll":
		_update_roll_motion()
	elif action_kind == "attack":
		_update_attack_motion(delta)
	elif action_kind == "stagger":
		_stop_horizontal(delta, 16.0)
	else:
		_handle_movement(delta)
		_handle_actions()

	move_and_slide()
	_update_visual_state()
	_update_debug_label()

func _update_camera(delta: float):
	if camera_pivot == null:
		return
	var target_position = global_position + Vector3.UP * camera_pivot_height
	var follow_weight = 1.0 - exp(-camera_follow_speed * delta)
	camera_pivot.global_position = camera_pivot.global_position.lerp(target_position, follow_weight)
	var target_distance = camera_normal_distance
	if _has_lock_target():
		var target_point = lock_target.global_position + Vector3.UP * camera_focus_height
		var planar = target_point - target_position
		planar.y = 0.0
		if planar.length_squared() > 0.001:
			var desired_yaw = atan2(-planar.x, -planar.z) + deg_to_rad(camera_lock_yaw_offset)
			camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, desired_yaw, 1.0 - exp(-camera_rotation_speed * delta))
		target_distance = clamp(camera_lock_distance + global_position.distance_to(lock_target.global_position) * 0.12, camera_lock_distance, camera_lock_distance + 1.0)
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_distance, 1.0 - exp(-camera_collision_recovery_speed * delta))
	var actual_distance = spring_arm.get_hit_length()
	if actual_distance <= 0.0:
		actual_distance = spring_arm.spring_length
	var collision_blend = smoothstep(camera_collision_min_distance, target_distance, actual_distance)
	spring_arm.position.x = camera_lateral_offset * 0.55 * collision_blend
	camera.fov = lerp(74.0, 68.0, collision_blend)
	camera_shake_strength = move_toward(camera_shake_strength, 0.0, delta * 2.8)
	camera.h_offset = camera_lateral_offset * 0.45 * collision_blend + sin(Time.get_ticks_msec() * 0.047) * camera_shake_strength
	camera.v_offset = cos(Time.get_ticks_msec() * 0.061) * camera_shake_strength * 0.65

func _apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1

func get_camera_planar_forward() -> Vector3:
	if camera_pivot == null:
		return get_logical_forward()
	var forward = -camera_pivot.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.001 else get_logical_forward()

func get_logical_forward() -> Vector3:
	var forward = -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()

func _get_camera_planar_right() -> Vector3:
	var right = camera_pivot.global_transform.basis.x
	right.y = 0.0
	return right.normalized()

func _get_input_direction() -> Vector3:
	var input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction = _get_camera_planar_right() * input_vector.x + get_camera_planar_forward() * -input_vector.y
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO

func _handle_movement(delta: float):
	var direction = _get_input_direction()
	var running = Input.is_action_pressed("run") and direction.length_squared() > 0.001 and GameState.stamina > 3.0
	var speed = RUN_SPEED if running else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if direction.length_squared() > 0.001:
		last_move_direction = direction
		last_move_age = 0.0
		desired_facing = _direction_to_lock_target() if _has_lock_target() else direction
		_turn_toward_direction(desired_facing, delta, 12.0)
	elif _has_lock_target():
		_turn_toward_direction(_direction_to_lock_target(), delta, 10.0)
	if running:
		GameState.spend_stamina(RUN_STAMINA_PER_SECOND * delta)
	else:
		GameState.regen_stamina(STAMINA_REGEN * delta)

func _handle_actions():
	if Input.is_action_just_pressed("roll"):
		_start_roll()
	elif Input.is_action_just_pressed("heavy_attack"):
		_start_attack("heavy")
	elif Input.is_action_just_pressed("light_attack"):
		_start_attack("light")

func _start_roll():
	if action.is_active() or not GameState.spend_stamina(ROLL_COST):
		return
	roll_direction = _get_input_direction()
	if roll_direction.length_squared() < 0.001:
		roll_direction = -get_logical_forward() if _has_lock_target() else get_logical_forward()
	roll_direction = roll_direction.normalized()
	if visual_model != null:
		visual_model.set_roll_direction(global_transform.basis.inverse() * roll_direction)
	desired_facing = roll_direction
	action_kind = "roll"
	is_rolling = true
	is_attacking = false
	action.begin("roll", [
		{"name":"prepare", "duration":0.065, "allow_rotation":true, "allow_movement":false, "invulnerable":false, "interruptible":false},
		{"name":"impulse", "duration":0.065, "allow_rotation":false, "allow_movement":true, "invulnerable":false, "interruptible":false},
		{"name":"invulnerable", "duration":0.33, "allow_rotation":false, "allow_movement":true, "invulnerable":true, "interruptible":false},
		{"name":"travel", "duration":0.14, "allow_rotation":false, "allow_movement":true, "invulnerable":false, "interruptible":false},
		{"name":"landing", "duration":0.10, "allow_rotation":false, "allow_movement":true, "invulnerable":false, "interruptible":false},
		{"name":"recovery", "duration":0.06, "allow_rotation":false, "allow_movement":false, "invulnerable":false, "interruptible":false}
	])

func _start_attack(kind: String):
	if action.is_active():
		return
	var weapon = Inventory.get_equipped_weapon()
	var cost = 16 if weapon == null else (weapon.heavy_stamina_cost if kind == "heavy" else weapon.light_stamina_cost)
	if not GameState.spend_stamina(cost):
		return
	attack_type = kind
	attack_direction = _choose_attack_direction()
	desired_facing = attack_direction
	attack_has_hit = false
	attack_sequence += 1
	current_attack_id = attack_sequence
	action_kind = "attack"
	is_attacking = true
	is_rolling = false
	var base_time = weapon.attack_time if weapon != null else 0.46
	var total = base_time * (1.72 if kind == "heavy" else 1.18)
	var windup_ratio = 0.48 if kind == "heavy" else 0.34
	var active_ratio = 0.18 if kind == "heavy" else 0.20
	action.begin("attack", [
		{"name":"windup", "duration":total * windup_ratio, "allow_rotation":true, "allow_movement":false, "hitbox_active":false, "can_chain":false, "invulnerable":false, "interruptible":true},
		{"name":"active", "duration":total * active_ratio, "allow_rotation":false, "allow_movement":true, "hitbox_active":true, "can_chain":false, "invulnerable":false, "interruptible":kind != "heavy"},
		{"name":"recovery", "duration":total * (1.0 - windup_ratio - active_ratio), "allow_rotation":false, "allow_movement":false, "hitbox_active":false, "can_chain":true, "invulnerable":false, "interruptible":true}
	])
	if visual_model != null:
		visual_model.play_attack(kind, weapon.weapon_family if weapon != null else "sword", total)

func _choose_attack_direction() -> Vector3:
	if _has_lock_target():
		return _direction_to_lock_target()
	var input_direction = _get_input_direction()
	if input_direction.length_squared() > 0.001:
		return input_direction
	if last_move_age <= 0.40:
		return last_move_direction
	return get_camera_planar_forward()

func _update_action(delta: float):
	if not action.is_active():
		return
	action.update(delta)
	if action.finished:
		_finish_action()
		return
	if action_kind == "attack":
		if action.get_phase() == "recovery" and action.get_phase_progress() >= 0.42:
			if Input.is_action_just_pressed("light_attack"):
				buffered_attack = "light"
			elif Input.is_action_just_pressed("heavy_attack"):
				buffered_attack = "heavy"
		if action.get_phase() == "windup":
			if _has_lock_target():
				var target_direction = _direction_to_lock_target()
				attack_direction = attack_direction.slerp(target_direction, min(1.0, delta * 5.5)).normalized()
			_turn_toward_direction(attack_direction, delta, 11.0)
		elif action.get_phase() == "active" and not attack_has_hit:
			attack_has_hit = _apply_attack_hit()
	elif action_kind == "roll" and action.allows_rotation():
		_turn_toward_direction(roll_direction, delta, 15.0)

func _update_roll_motion():
	var speed := 0.0
	match action.get_phase():
		"prepare": speed = ROLL_SPEED * 0.18
		"impulse": speed = ROLL_SPEED * 1.08
		"invulnerable": speed = ROLL_SPEED
		"travel": speed = ROLL_SPEED * lerp(0.82, 0.48, action.get_phase_progress())
		"landing": speed = ROLL_SPEED * lerp(0.35, 0.12, action.get_phase_progress())
		"recovery": speed = ROLL_SPEED * lerp(0.10, 0.0, action.get_phase_progress())
	velocity.x = roll_direction.x * speed
	velocity.z = roll_direction.z * speed

func _update_attack_motion(delta: float):
	var target_speed = 0.0
	if action.get_phase() == "active":
		target_speed = 1.35 if attack_type == "heavy" else 0.85
	velocity.x = move_toward(velocity.x, attack_direction.x * target_speed, delta * 11.0)
	velocity.z = move_toward(velocity.z, attack_direction.z * target_speed, delta * 11.0)

func _finish_action():
	var chained_attack = buffered_attack if action_kind == "attack" else ""
	buffered_attack = ""
	action_kind = ""
	is_rolling = false
	is_attacking = false
	attack_has_hit = false
	if visual_model != null:
		visual_model.set_action_phase("none", "none", 0.0)
	if chained_attack != "":
		_start_attack(chained_attack)

func _apply_attack_hit() -> bool:
	var weapon = Inventory.get_equipped_weapon()
	var reach = weapon.attack_reach if weapon != null else 1.6
	var arc = deg_to_rad(weapon.attack_arc if weapon != null else 80.0)
	var damage = GameState.calculate_weapon_damage(weapon, attack_type)
	var poise_damage = damage * (0.72 if attack_type == "heavy" else 0.32)
	var impact_force = 5.2 if attack_type == "heavy" else 2.4
	var connected := false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var offset = enemy.global_position - global_position
		offset.y = 0.0
		if combat_debug:
			print("PLAYER_HIT_CHECK enemy=",enemy.enemy_id," distance=",offset.length()," angle=",rad_to_deg(attack_direction.angle_to(offset.normalized())) if offset.length_squared() > 0.001 else 0.0," reach=",reach)
		if offset.length_squared() < 0.0001 or offset.length() > reach:
			continue
		if attack_direction.angle_to(offset.normalized()) > arc * 0.5:
			continue
		var hit = CombatHit.new(self, damage, poise_damage, attack_direction, enemy.global_position + Vector3.UP, impact_force, attack_type, current_attack_id)
		if enemy.has_method("receive_hit"):
			if enemy.receive_hit(hit) > 0:
				connected = true
				add_camera_shake(0.055 if attack_type == "heavy" else 0.025)
		else:
			enemy.take_damage(damage, self)
			connected = true
	return connected

func receive_hit(hit: CombatHit) -> int:
	if health_is_empty() or _is_invulnerable():
		return 0
	var damage = GameState.take_damage(hit.damage)
	poise = max(0.0, poise - hit.poise_damage)
	poise_recovery_timer = poise_recovery_delay
	var staggered = poise <= 0.0 and stagger_immunity_timer <= 0.0
	if visual_model != null:
		visual_model.play_hit(hit.direction, "stagger" if staggered else hit.impact_type)
	add_camera_shake(0.11 if staggered or hit.impact_type.contains("brute") else 0.055)
	get_tree().call_group("game", "spawn_combat_impact", global_position + Vector3.UP, hit.direction, hit.impact_type)
	get_tree().call_group("game", "request_hit_stop", 0.065 if hit.impact_type == "heavy" else 0.035)
	if GameState.health <= 0:
		_die()
	elif staggered:
		_start_stagger()
	return damage

func take_damage(amount):
	return receive_hit(CombatHit.new(null, int(amount), 12.0, -get_logical_forward(), global_position + Vector3.UP, 1.0, "light", 0))

func add_camera_shake(strength: float):
	camera_shake_strength = max(camera_shake_strength, strength)

func _start_stagger():
	action.cancel()
	action_kind = "stagger"
	is_attacking = false
	is_rolling = false
	poise = max_poise * 0.35
	stagger_immunity_timer = stagger_duration + 0.3
	action.begin("stagger", [{"name":"stagger", "duration":stagger_duration, "interruptible":false}])

func _die():
	action.cancel()
	action_kind = "dead"
	is_attacking = false
	is_rolling = false
	_release_lock_target()
	if visual_model != null:
		visual_model.play_death()
	GameState.die(global_position)
	set_physics_process(false)
	set_process_unhandled_input(false)
	collision_layer = 0
	collision_mask = 0

func _is_invulnerable() -> bool:
	return action_kind == "roll" and action.is_active() and action.is_invulnerable()

func _update_poise(delta: float):
	stagger_immunity_timer = max(0.0, stagger_immunity_timer - delta)
	if poise_recovery_timer > 0.0:
		poise_recovery_timer -= delta
	elif poise < max_poise and action_kind != "stagger":
		poise = min(max_poise, poise + poise_recovery_rate * delta)

func _turn_toward_direction(direction: Vector3, delta: float, speed: float):
	if direction.length_squared() < 0.001:
		return
	var desired_yaw = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-speed * delta))

func _stop_horizontal(delta: float, deceleration := 8.0):
	velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * delta * deceleration)
	velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * delta * deceleration)

func _update_visual_state():
	if visual_model == null:
		return
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	visual_model.set_locomotion(horizontal_speed / RUN_SPEED, horizontal_speed > WALK_SPEED + 0.4)
	visual_model.set_action_phase(action_kind, action.get_phase(), action.get_phase_progress())

func _update_equipment_visuals():
	if visual_model == null:
		return
	visual_model.set_character_class(GameState.class_id)
	visual_model.set_equipped_weapon(Inventory.get_equipped_weapon())
	visual_model.set_equipped_armor(Inventory.get_equipped_armor())
	max_poise = player_max_poise + Inventory.get_total_defense() * 1.4
	poise = min(poise, max_poise)

func _toggle_lock_target():
	if _has_lock_target():
		_release_lock_target()
		return
	var best = null
	var best_score = INF
	var camera_forward = get_camera_planar_forward()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy) or enemy.get("is_dead") == true:
			continue
		var offset = enemy.global_position - global_position
		offset.y = 0.0
		var distance = offset.length()
		if distance > 14.0 or distance < 0.001:
			continue
		var angle = camera_forward.angle_to(offset.normalized())
		var score = distance + angle * 5.0
		if angle < deg_to_rad(70.0) and score < best_score:
			best = enemy
			best_score = score
	lock_target = best
	if _has_lock_target() and lock_target.has_method("set_lock_targeted"):
		lock_target.set_lock_targeted(true)

func _validate_lock_target():
	if lock_target == null:
		return
	if not is_instance_valid(lock_target) or lock_target.get("is_dead") == true or global_position.distance_to(lock_target.global_position) > 18.0:
		_release_lock_target()

func _release_lock_target():
	if lock_target != null and is_instance_valid(lock_target) and lock_target.has_method("set_lock_targeted"):
		lock_target.set_lock_targeted(false)
	lock_target = null

func _has_lock_target() -> bool:
	return lock_target != null and is_instance_valid(lock_target) and lock_target.get("is_dead") != true

func _direction_to_lock_target() -> Vector3:
	if not _has_lock_target():
		return get_logical_forward()
	var direction = lock_target.global_position - global_position
	direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.001 else get_logical_forward()

func _try_interact():
	var best = null
	var best_distance = INF
	for node in get_tree().get_nodes_in_group("interactable"):
		var distance = global_position.distance_to(node.global_position)
		if distance < best_distance and distance <= 2.5:
			best = node
			best_distance = distance
	if best != null and best.has_method("interact"):
		best.interact(self)

func health_is_empty() -> bool:
	return GameState.health <= 0

func get_combat_debug_state() -> Dictionary:
	return {
		"action": action_kind,
		"phase": action.get_phase(),
		"phase_progress": action.get_phase_progress(),
		"invulnerable": _is_invulnerable(),
		"poise": poise,
		"max_poise": max_poise,
		"attack_direction": attack_direction,
		"logical_forward": get_logical_forward(),
		"camera_forward": get_camera_planar_forward()
	}

func _update_debug_label():
	if debug_label == null:
		return
	debug_label.visible = combat_debug
	if combat_debug:
		debug_label.text = "%s / %s\nPoise %.0f/%.0f\nI-frames %s" % [action_kind, action.get_phase(), poise, max_poise, str(_is_invulnerable())]

func _ui_blocks_gameplay():
	var ui = get_tree().get_first_node_in_group("ui")
	return ui != null and ui.has_method("is_blocking_gameplay") and ui.is_blocking_gameplay()
