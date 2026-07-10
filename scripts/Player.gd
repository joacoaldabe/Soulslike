extends CharacterBody3D

const WALK_SPEED = 4.0
const RUN_SPEED = 6.5
const ROLL_SPEED = 9.5
const GRAVITY = 24.0
const STAMINA_REGEN = 28.0
const RUN_STAMINA_PER_SECOND = 12.0
const ROLL_COST = 28
const PlayerModelScene = preload("res://scenes/PlayerModel.tscn")

var camera_pivot = null
var camera = null
var visual_model = null
var lock_target = null
var is_rolling = false
var roll_timer = 0.0
var roll_direction = Vector3.ZERO
var is_attacking = false
var attack_timer = 0.0
var attack_duration = 0.0
var attack_has_hit = false
var attack_type = "light"
var invulnerable_timer = 0.0

func _ready():
	add_to_group("player")
	_setup_body()
	_update_weapon_visual()
	Inventory.equipment_changed.connect(_update_weapon_visual)
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
	add_child(visual_model)

	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 1.35, 0)
	add_child(camera_pivot)
	var spring_arm = SpringArm3D.new()
	spring_arm.spring_length = 4.2
	spring_arm.rotation_degrees.x = -18
	camera_pivot.add_child(spring_arm)
	camera = Camera3D.new()
	camera.current = true
	spring_arm.add_child(camera)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.004)
		camera_pivot.rotate_x(-event.relative.y * 0.003)
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-45), deg_to_rad(20))
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
	_update_timers(delta)
	_apply_gravity(delta)
	if _ui_blocks_gameplay():
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * delta * 8.0)
		GameState.regen_stamina(STAMINA_REGEN * delta)
		move_and_slide()
		_update_visual_state()
		return
	if is_rolling:
		velocity.x = roll_direction.x * ROLL_SPEED
		velocity.z = roll_direction.z * ROLL_SPEED
	elif is_attacking:
		velocity.x = move_toward(velocity.x, 0.0, WALK_SPEED * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, WALK_SPEED * delta * 8.0)
	else:
		_handle_movement(delta)
	_handle_actions()
	move_and_slide()
	_update_lock_rotation(delta)
	_update_visual_state()

func _update_timers(delta):
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0.0:
			is_rolling = false
	if is_attacking:
		attack_timer -= delta
		if not attack_has_hit and attack_timer <= attack_duration * 0.55:
			_apply_attack_hit()
			attack_has_hit = true
		if attack_timer <= 0.0:
			is_attacking = false

func _apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1

func _handle_movement(delta):
	var input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward = -global_transform.basis.z
	var right = global_transform.basis.x
	var direction = (right * input_vector.x + forward * -input_vector.y)
	if direction.length() > 0.01:
		direction = direction.normalized()
	var running = Input.is_action_pressed("run") and direction.length() > 0.01 and GameState.stamina > 3.0
	var speed = RUN_SPEED if running else WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
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
	if is_attacking or is_rolling or not GameState.spend_stamina(ROLL_COST):
		return
	var input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward = -global_transform.basis.z
	var right = global_transform.basis.x
	roll_direction = (right * input_vector.x + forward * -input_vector.y)
	if roll_direction.length() < 0.01:
		roll_direction = -global_transform.basis.z
	roll_direction = roll_direction.normalized()
	is_rolling = true
	roll_timer = 0.48
	invulnerable_timer = 0.42
	if visual_model != null:
		visual_model.set_roll_state(true, roll_timer)

func _start_attack(kind):
	var weapon = Inventory.get_equipped_weapon()
	var cost = 16
	if weapon != null:
		cost = weapon.heavy_stamina_cost if kind == "heavy" else weapon.light_stamina_cost
	if is_rolling or is_attacking or not GameState.spend_stamina(cost):
		return
	attack_type = kind
	is_attacking = true
	attack_has_hit = false
	attack_duration = weapon.attack_time if weapon != null else 0.42
	if kind == "heavy":
		attack_duration *= 1.25
	attack_timer = attack_duration
	if visual_model != null:
		var family = weapon.weapon_family if weapon != null else "sword"
		visual_model.play_attack(kind, family, attack_duration)

func _apply_attack_hit():
	var weapon = Inventory.get_equipped_weapon()
	var reach = weapon.attack_reach if weapon != null else 1.6
	var arc = deg_to_rad(weapon.attack_arc if weapon != null else 80.0)
	var forward = (-global_transform.basis.z).normalized()
	var damage = GameState.calculate_weapon_damage(weapon, attack_type)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset = enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() <= reach:
			var angle = forward.angle_to(offset.normalized())
			if angle <= arc * 0.5:
				enemy.take_damage(damage, self)

func _update_visual_state():
	if visual_model == null:
		return
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	visual_model.set_locomotion(horizontal_speed / RUN_SPEED, horizontal_speed > WALK_SPEED + 0.4)
	visual_model.set_roll_state(is_rolling, roll_timer)
	visual_model.set_attack_state(is_attacking, attack_type, attack_timer, attack_duration)

func _update_weapon_visual():
	if visual_model == null:
		return
	var weapon = Inventory.get_equipped_weapon()
	visual_model.set_equipped_weapon(weapon)

func _toggle_lock_target():
	if lock_target != null and is_instance_valid(lock_target):
		lock_target = null
		return
	var best = null
	var best_distance = 999.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance = global_position.distance_to(enemy.global_position)
		if distance < best_distance and distance <= 12.0:
			best = enemy
			best_distance = distance
	lock_target = best

func _update_lock_rotation(delta):
	if lock_target == null or not is_instance_valid(lock_target):
		return
	var target = lock_target.global_position
	target.y = global_position.y
	var direction = target - global_position
	if direction.length() <= 0.01:
		return
	var desired_y = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_y, delta * 10.0)

func _try_interact():
	var best = null
	var best_distance = 999.0
	for node in get_tree().get_nodes_in_group("interactable"):
		var distance = global_position.distance_to(node.global_position)
		if distance < best_distance and distance <= 2.5:
			best = node
			best_distance = distance
	if best != null and best.has_method("interact"):
		best.interact(self)

func take_damage(amount):
	if invulnerable_timer > 0.0 or health_is_empty():
		return 0
	var damage = GameState.take_damage(amount)
	if visual_model != null:
		visual_model.play_hit()
	if GameState.health <= 0:
		if visual_model != null:
			visual_model.play_death()
		GameState.die(global_position)
		set_physics_process(false)
		set_process_unhandled_input(false)
		collision_layer = 0
		collision_mask = 0
	return damage

func health_is_empty():
	return GameState.health <= 0

func _ui_blocks_gameplay():
	var ui = get_tree().get_first_node_in_group("ui")
	return ui != null and ui.has_method("is_blocking_gameplay") and ui.is_blocking_gameplay()
