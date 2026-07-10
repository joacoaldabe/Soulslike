extends CharacterBody3D

const GRAVITY = 24.0

@export var enemy_id = "hollow_sword"

var data = null
var health = 1
var attack_cooldown = 0.0
var visual_model: EnemyModel = null

func _ready():
	add_to_group("enemies")
	data = Database.get_enemy(enemy_id)
	if data == null:
		push_warning("Missing enemy data: %s" % enemy_id)
		queue_free()
		return
	health = data.max_health
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

func _physics_process(delta):
	if data == null:
		return
	attack_cooldown = max(0.0, attack_cooldown - delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.1
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		velocity.x = move_toward(velocity.x, 0.0, delta * data.move_speed * 3.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * data.move_speed * 3.0)
		move_and_slide()
		return
	var offset = player.global_position - global_position
	offset.y = 0.0
	var distance = offset.length()
	if visual_model != null:
		visual_model.set_moving(distance <= data.aggro_range and distance > data.attack_range)
	if distance <= data.aggro_range:
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		if distance > data.attack_range:
			var direction = offset.normalized()
			velocity.x = direction.x * data.move_speed
			velocity.z = direction.z * data.move_speed
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_try_attack(player)
	move_and_slide()

func _try_attack(player):
	if attack_cooldown > 0.0:
		return
	attack_cooldown = data.attack_cooldown
	var damage = data.damage
	match data.moveset:
		"brute":
			damage = int(damage * 1.35)
		"lancer":
			damage = int(damage * 1.1)
		"hound":
			attack_cooldown *= 0.75
	player.take_damage(damage)

func take_damage(amount, _source):
	health -= int(amount)
	if visual_model != null:
		visual_model.flash_hit()
	if health <= 0:
		_die()

func _die():
	GameState.add_souls(data.souls_reward)
	for index in range(data.drop_ids.size()):
		var chance = 0.0
		if index < data.drop_chances.size():
			chance = float(data.drop_chances[index])
		if randf() <= chance:
			var item_id = data.drop_ids[index]
			Inventory.add_item(item_id, 1)
			var item = Database.get_item(item_id)
			if item != null:
				get_tree().call_group("ui", "notify", "Obtuviste %s." % item.display_name)
	queue_free()
