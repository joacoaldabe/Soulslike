extends SceneTree

func _initialize():
	call_deferred("_capture")

func _material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material

func _mesh(mesh: Mesh, position: Vector3, color: Color, scale_value := Vector3.ONE) -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale_value
	instance.material_override = _material(color)
	root.add_child(instance)
	return instance

func _capture():
	var environment_node = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035,0.035,0.045)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25,0.25,0.28)
	environment_node.environment = environment
	root.add_child(environment_node)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	sun.light_energy = 2.2
	root.add_child(sun)

	var ground = PlaneMesh.new()
	ground.size = Vector2(38,38)
	_mesh(ground,Vector3.ZERO,Color(0.18,0.16,0.14))
	for position in [Vector3(3,0.5,-7),Vector3(-7,0.5,-3),Vector3(7,0.5,-15),Vector3(-12,0.5,-13)]:
		var block = BoxMesh.new()
		block.size = Vector3(2,1,2)
		_mesh(block,position,Color(0.25,0.24,0.23))

	var player_capsule = CapsuleMesh.new()
	player_capsule.height = 1.8
	player_capsule.radius = 0.35
	_mesh(player_capsule,Vector3(0,0.9,1.7),Color(0.30,0.31,0.34))

	var enemy_colors = [Color(0.34,0.31,0.28),Color(0.42,0.20,0.15),Color(0.27,0.32,0.45),Color(0.16,0.16,0.14)]
	var enemy_positions = [Vector3(5,0.8,-4),Vector3(-6,1.0,-8),Vector3(10,0.8,-12),Vector3(-10,0.55,-15)]
	var enemy_scales = [Vector3.ONE,Vector3(1.25,1.25,1.25),Vector3.ONE,Vector3(0.85,0.65,1.1)]
	for index in range(enemy_positions.size()):
		var capsule = CapsuleMesh.new()
		capsule.height = 1.6
		capsule.radius = 0.35
		_mesh(capsule,enemy_positions[index],enemy_colors[index],enemy_scales[index])

	var hearth = CylinderMesh.new()
	hearth.height = 0.25
	hearth.top_radius = 0.8
	hearth.bottom_radius = 0.9
	_mesh(hearth,Vector3(0,0.125,0),Color(0.22,0.20,0.18))
	var flame = SphereMesh.new()
	flame.radius = 0.35
	flame.height = 0.8
	var flame_instance = _mesh(flame,Vector3(0,0.65,0),Color(1.0,0.42,0.10))
	var flame_material = flame_instance.material_override
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0,0.36,0.08)
	flame_material.emission_energy_multiplier = 2.5

	var camera = Camera3D.new()
	camera.position = Vector3(0,3.0,6.2)
	root.add_child(camera)
	camera.look_at_from_position(camera.position,Vector3(0,1.0,-5),Vector3.UP)
	camera.current = true
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var error = image.save_png("res://docs/screenshots/prototype_before_reconstruction.png")
	if error == OK:
		print("BASELINE_REFERENCE_OK")
		quit(0)
	else:
		push_error("Could not save baseline reference")
		quit(1)
