extends Area3D

@export var bonfire_id = "ash_camp"

var data = null

func _ready():
	add_to_group("interactable")
	add_to_group("bonfires")
	data = Database.get_bonfire(bonfire_id)
	_setup_visuals()

func _setup_visuals():
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.1
	collision.shape = shape
	add_child(collision)

	for i in range(9):
		var angle = TAU * float(i) / 9.0
		var stone = VisualLibrary.tapered(Vector2(0.16,0.22),Vector2(0.24,0.28),0.28,VisualLibrary.material("stone_dark"),"HearthStone")
		VisualLibrary.add_part(self, stone, Vector3(cos(angle)*0.68,0.14,sin(angle)*0.68), Vector3(8,i*40,12))
	for angle in [-32.0, 34.0, 88.0]:
		var log_mesh = VisualLibrary.cylinder(0.09,1.15,VisualLibrary.material("wood"),7,"CharredLog")
		VisualLibrary.add_part(self,log_mesh,Vector3(0,0.28,0),Vector3(0,0,90+angle))
	var sword = VisualLibrary.tapered(Vector2(0.0,0.025),Vector2(0.075,0.035),1.45,VisualLibrary.material("dark_metal"),"BonfireSword")
	VisualLibrary.add_part(self,sword,Vector3(0,1.02,0),Vector3(0,0,8))
	var guard = VisualLibrary.box(Vector3(0.52,0.06,0.08),VisualLibrary.material("metal"),"SwordGuard")
	VisualLibrary.add_part(self,guard,Vector3(-0.13,1.43,0),Vector3(0,0,8))

	var flame = MeshInstance3D.new()
	var flame_mesh = CylinderMesh.new()
	flame_mesh.bottom_radius = 0.42
	flame_mesh.top_radius = 0.03
	flame_mesh.height = 1.0
	flame_mesh.radial_segments = 7
	flame.mesh = flame_mesh
	flame.position.y = 0.65
	flame.material_override = VisualLibrary.material("fire")
	add_child(flame)

	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 2.5
	light.omni_range = 5.0
	light.position.y = 1.0
	add_child(light)
	var tween = create_tween().set_loops()
	tween.tween_property(light,"light_energy",3.0,0.55).set_trans(Tween.TRANS_SINE)
	tween.tween_property(light,"light_energy",2.1,0.65).set_trans(Tween.TRANS_SINE)
	var particles = GPUParticles3D.new()
	particles.amount = 22
	particles.lifetime = 1.4
	particles.position.y = 0.45
	var process = ParticleProcessMaterial.new()
	process.direction = Vector3(0,1,0)
	process.spread = 24.0
	process.initial_velocity_min = 0.7
	process.initial_velocity_max = 1.7
	process.gravity = Vector3(0,0.3,0)
	process.scale_min = 0.025
	process.scale_max = 0.07
	particles.process_material = process
	var spark = QuadMesh.new()
	spark.size = Vector2(0.05,0.05)
	spark.material = VisualLibrary.material("fire")
	particles.draw_pass_1 = spark
	add_child(particles)

func interact(player):
	GameState.discover_bonfire(bonfire_id, global_position, false)
	if player != null and player.has_method("begin_bonfire_rest"):
		player.begin_bonfire_rest(global_position)
	get_tree().call_group("ui", "open_bonfire_menu", bonfire_id)

func get_spawn_position() -> Vector3:
	return global_position
