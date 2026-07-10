extends Area3D

func _ready():
	add_to_group("interactable")
	add_to_group("bloodstain")
	_setup_visuals()

func _setup_visuals():
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0
	collision.shape = shape
	add_child(collision)

	var mesh = MeshInstance3D.new()
	var pool = CylinderMesh.new()
	pool.bottom_radius = 0.68
	pool.top_radius = 0.48
	pool.height = 0.08
	pool.radial_segments = 9
	mesh.mesh = pool
	mesh.position.y = 0.1
	mesh.material_override = VisualLibrary.material("souls")
	add_child(mesh)

	var light = OmniLight3D.new()
	light.light_color = Color(0.2, 1.0, 0.35)
	light.light_energy = 2.2
	light.omni_range = 3.0
	light.position.y = 0.8
	add_child(light)
	var wisp = GPUParticles3D.new()
	wisp.amount = 14
	wisp.lifetime = 1.8
	wisp.position.y = 0.15
	var process = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.5
	process.direction = Vector3(0,1,0)
	process.spread = 35.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.65
	process.gravity = Vector3(0,0.12,0)
	process.scale_min = 0.025
	process.scale_max = 0.075
	wisp.process_material = process
	var mote = SphereMesh.new()
	mote.radius = 0.035
	mote.height = 0.07
	mote.material = VisualLibrary.material("souls")
	wisp.draw_pass_1 = mote
	add_child(wisp)
	var tween = create_tween().set_loops()
	tween.tween_property(mesh,"scale",Vector3(1.12,1.0,1.12),0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mesh,"scale",Vector3.ONE,0.8).set_trans(Tween.TRANS_SINE)

func interact(_player):
	if GameState.recover_lost_souls():
		get_tree().call_group("ui", "notify", "Recuperaste tus souls perdidas.")
	queue_free()
