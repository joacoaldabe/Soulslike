extends Node3D

const PlayerScene = preload("res://scenes/Player.tscn")
const EnemyScene = preload("res://scenes/Enemy.tscn")
const BonfireScene = preload("res://scenes/Bonfire.tscn")
const BloodstainScene = preload("res://scenes/Bloodstain.tscn")
const ChestScene = preload("res://scenes/Chest.tscn")
const FinalAltarScene = preload("res://scenes/FinalAltar.tscn")
const UIScene = preload("res://scenes/UI.tscn")

var player = null
var ui = null
var environment_root: GothicChurchLevel = null
var hit_stop_serial := 0
var enemy_spawn_points = []
var chest_spawn_points = []

func _ready():
	add_to_group("game")
	randomize()
	_create_world()
	_spawn_bonfires()
	_spawn_chests()
	_spawn_final_altar()
	ui = UIScene.instantiate()
	add_child(ui)
	ui.character_selected.connect(_on_character_selected)
	ui.travel_requested.connect(_on_travel_requested)
	ui.rest_requested.connect(_on_rest_requested)
	GameState.player_died.connect(_on_player_died)
	GameState.bloodstain_changed.connect(_refresh_bloodstain)
	if GameState.character_ready:
		_start_level()
	else:
		ui.show_character_creator()

func _create_world():
	var world_environment = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("151b20")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("71808a")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("53616a")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.018
	environment.fog_height = 1.0
	environment.fog_height_density = 0.22
	world_environment.environment = environment
	add_child(world_environment)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("aabccc")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)
	environment_root = GothicChurchLevel.new()
	add_child(environment_root)
	environment_root.build()
	enemy_spawn_points = environment_root.enemy_spawns
	chest_spawn_points = environment_root.chest_spawns

func _build_ruined_courtyard():
	_create_paving()
	for wall in [
		[Vector3(-13, 1.5, -7), Vector3(1.2, 3.0, 18.0), 0.0],
		[Vector3(13, 1.5, -7), Vector3(1.2, 3.0, 18.0), 0.0],
		[Vector3(-7.5, 1.7, -18), Vector3(10.0, 3.4, 1.1), 0.0],
		[Vector3(7.5, 1.7, -18), Vector3(10.0, 3.4, 1.1), 0.0],
		[Vector3(-8, 1.0, 3), Vector3(8.0, 2.0, 1.0), 0.0],
		[Vector3(8, 1.0, 3), Vector3(8.0, 2.0, 1.0), 0.0]
	]:
		_create_stone_body(wall[0], wall[1], wall[2])
	for x in [-11.0, -4.2, 4.2, 11.0]:
		_create_column(Vector3(x, 1.65, -12.5), 3.3, x in [-11.0, 4.2])
	_create_arch(Vector3(0, 0, -18))
	_create_banner(Vector3(-3.6,2.45,-17.38),Color("603b3e"))
	_create_banner(Vector3(3.6,2.45,-17.38),Color("394a45"))
	_create_stairs(Vector3(0, 0, -10))
	for rubble in [Vector3(-9,0.18,-5), Vector3(8,0.18,-9), Vector3(-5,0.18,-15), Vector3(10,0.18,-16)]:
		_create_rubble(rubble)
	var landmark = VisualLibrary.tapered(Vector2(0.15,0.15), Vector2(1.2,0.9), 6.5, VisualLibrary.material("stone_dark"), "DistantSpire")
	VisualLibrary.add_part(environment_root, landmark, Vector3(0,3.25,-25), Vector3(0,18,0))

func _create_paving():
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.92,0.075,0.92)
	for variant in range(2):
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		var transforms: Array[Transform3D] = []
		for z in range(22):
			for x in range(24):
				if (x + z) % 2 != variant:
					continue
				if (x * 7 + z * 13) % 23 == 0:
					continue
				var jitter = sin(float(x * 17 + z * 31)) * 0.045
				var basis = Basis(Vector3.UP, jitter * 1.4)
				basis = basis.scaled(Vector3(0.96 + jitter,1.0,0.96 - jitter))
				var sink = -0.025 if (x * 11 + z * 5) % 17 == 0 else 0.0
				transforms.append(Transform3D(basis,Vector3(-11.5 + x,0.035 + sink,2.0-z)))
		multimesh.instance_count = transforms.size()
		for index in range(transforms.size()):
			multimesh.set_instance_transform(index,transforms[index])
		var paving = MultiMeshInstance3D.new()
		paving.name = "CourtyardPaving%d" % variant
		paving.multimesh = multimesh
		paving.material_override = VisualLibrary.material("stone" if variant == 0 else "stone_dark")
		environment_root.add_child(paving)

func _create_stone_body(position: Vector3, size: Vector3, y_rotation: float = 0.0):
	var body = StaticBody3D.new()
	body.position = position
	body.rotation_degrees.y = y_rotation
	environment_root.add_child(body)
	var mesh = VisualLibrary.tapered(Vector2(size.x * 0.48, size.z * 0.48), Vector2(size.x * 0.52, size.z * 0.52), size.y, VisualLibrary.material("stone"), "RuinWall")
	body.add_child(mesh)
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _create_column(position: Vector3, height: float, broken: bool):
	var actual_height = height * (0.62 if broken else 1.0)
	var body = StaticBody3D.new()
	body.position = Vector3(position.x, actual_height * 0.5, position.z)
	environment_root.add_child(body)
	var shaft = VisualLibrary.cylinder(0.38, actual_height, VisualLibrary.material("stone_light"), 8, "Column")
	body.add_child(shaft)
	for y in [-actual_height * 0.48, actual_height * 0.48]:
		var capital = VisualLibrary.tapered(Vector2(0.34,0.34), Vector2(0.48,0.48), 0.18, VisualLibrary.material("stone"), "Capital")
		VisualLibrary.add_part(body, capital, Vector3(0,y,0))
	var collision = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 0.42
	shape.height = actual_height
	collision.shape = shape
	body.add_child(collision)

func _create_arch(position: Vector3):
	_create_stone_body(position + Vector3(-2.6,1.8,0), Vector3(1.2,3.6,1.2))
	_create_stone_body(position + Vector3(2.6,1.8,0), Vector3(1.2,3.6,1.2))
	for i in range(7):
		var angle = lerp(20.0,160.0,float(i)/6.0)
		var rad = deg_to_rad(angle)
		var block_pos = position + Vector3(cos(rad)*2.55, 1.8 + sin(rad)*2.25, 0)
		var block = VisualLibrary.tapered(Vector2(0.40,0.55),Vector2(0.48,0.62),0.72,VisualLibrary.material("stone_light"),"ArchStone")
		VisualLibrary.add_part(environment_root, block, block_pos, Vector3(90,0,-angle+90))

func _create_stairs(position: Vector3):
	for i in range(4):
		_create_stone_body(position + Vector3(0,0.12 + i*0.18,-i*0.65), Vector3(5.0-i*0.25,0.24,1.1))

func _create_rubble(position: Vector3):
	for i in range(5):
		var size = Vector3(0.35 + i*0.06,0.25 + (i%2)*0.12,0.42)
		var stone = VisualLibrary.tapered(Vector2(size.x*0.42,size.z*0.42),Vector2(size.x*0.55,size.z*0.55),size.y,VisualLibrary.material("stone_dark"),"Rubble")
		VisualLibrary.add_part(environment_root, stone, position + Vector3((i-2)*0.32, size.y*0.5, (i%2)*0.28), Vector3(8*i,17*i,9*i))

func _create_banner(position: Vector3, color: Color):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var banner = VisualLibrary.tapered(Vector2(0.38,0.025),Vector2(0.55,0.025),1.65,material,"RuinBanner")
	VisualLibrary.add_part(environment_root,banner,position,Vector3(0,0,180))
	var rod = VisualLibrary.cylinder(0.035,1.35,VisualLibrary.material("dark_metal"),7,"BannerRod")
	VisualLibrary.add_part(environment_root,rod,position + Vector3(0,0.91,0),Vector3(0,0,90))

func _spawn_bonfires():
	for bonfire_data in Database.list_bonfires():
		var bonfire = BonfireScene.instantiate()
		bonfire.bonfire_id = bonfire_data.bonfire_id
		bonfire.position = bonfire_data.position
		add_child(bonfire)

func _spawn_chests():
	for chest_data in chest_spawn_points:
		var chest = ChestScene.instantiate()
		chest.chest_id = chest_data["id"]
		chest.loot_items = chest_data["loot"].duplicate()
		chest.position = chest_data["position"]
		chest.rotation_degrees.y = chest_data["rotation"]
		add_child(chest)

func _spawn_final_altar():
	var altar = FinalAltarScene.instantiate()
	altar.position = Vector3(0,0,-229)
	altar.rotation_degrees.y = 180.0
	add_child(altar)

func _on_character_selected(class_id):
	if GameState.create_character(class_id):
		_start_level()

func _start_level():
	_spawn_player(GameState.current_bonfire_position)
	_respawn_enemies()
	_refresh_bloodstain()
	ui.show_hud()

func _spawn_player(position):
	if player != null and is_instance_valid(player):
		player.queue_free()
	player = PlayerScene.instantiate()
	player.position = position + Vector3(0.0, 0.0, -1.7)
	add_child(player)

func _respawn_enemies():
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	for spawn in enemy_spawn_points:
		var enemy = EnemyScene.instantiate()
		enemy.enemy_id = spawn["enemy_id"]
		enemy.position = spawn["position"]
		add_child(enemy)

func _refresh_bloodstain():
	for bloodstain in get_tree().get_nodes_in_group("bloodstain"):
		bloodstain.queue_free()
	if GameState.has_bloodstain:
		var bloodstain = BloodstainScene.instantiate()
		bloodstain.position = GameState.bloodstain_position
		add_child(bloodstain)

func _on_player_died(_position):
	await get_tree().create_timer(1.0).timeout
	_spawn_player(GameState.respawn_at_bonfire())
	ui.notify("Perdiste tus souls. Recuperalas en la mancha verde.")

func _on_rest_requested():
	GameState.restore_at_bonfire()
	_respawn_enemies()
	ui.notify("Descansaste en el bonfire.")

func _on_travel_requested(bonfire_id):
	if GameState.travel_to_bonfire(bonfire_id):
		_spawn_player(GameState.current_bonfire_position)
		_respawn_enemies()
		ui.close_bonfire_menu()

func request_hit_stop(duration: float):
	hit_stop_serial += 1
	var serial = hit_stop_serial
	Engine.time_scale = 0.10
	await get_tree().create_timer(clamp(duration, 0.015, 0.09), true, false, true).timeout
	if serial == hit_stop_serial:
		Engine.time_scale = 1.0

func spawn_combat_impact(position: Vector3, direction: Vector3, impact_type: String):
	var particles = GPUParticles3D.new()
	particles.name = "CombatImpact"
	particles.one_shot = true
	particles.amount = 9 if impact_type == "heavy" or impact_type.contains("brute") else 5
	particles.lifetime = 0.28
	particles.explosiveness = 1.0
	var process = ParticleProcessMaterial.new()
	process.direction = (direction + Vector3.UP * 0.65).normalized()
	process.spread = 42.0
	process.initial_velocity_min = 1.4
	process.initial_velocity_max = 3.1
	process.gravity = Vector3(0.0, -5.0, 0.0)
	process.scale_min = 0.025
	process.scale_max = 0.065
	particles.process_material = process
	var spark = SphereMesh.new()
	spark.radius = 0.035
	spark.height = 0.07
	spark.material = VisualLibrary.material("fire" if impact_type == "heavy" else "metal")
	particles.draw_pass_1 = spark
	add_child(particles)
	particles.global_position = position
	particles.emitting = true
	await get_tree().create_timer(0.55, true, false, true).timeout
	if is_instance_valid(particles):
		particles.queue_free()
