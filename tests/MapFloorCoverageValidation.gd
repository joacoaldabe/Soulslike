extends SceneTree

func _initialize():
	call_deferred("_run")

func _run():
	var level = GothicChurchLevel.new()
	root.add_child(level)
	level.build()
	await physics_frame
	var space = root.get_world_3d().direct_space_state
	var holes := []
	for x in range(-28, 29, 2):
		for z in range(-104, -79, 2):
			var from = Vector3(x, 5.0, z)
			var query = PhysicsRayQueryParameters3D.create(from, Vector3(x, -3.0, z))
			if space.intersect_ray(query).is_empty():
				holes.append(Vector2i(x, z))
	for z in range(-132, -103, 2):
		var from = Vector3(0.0, 5.0, z)
		var query = PhysicsRayQueryParameters3D.create(from, Vector3(0.0, -3.0, z))
		if space.intersect_ray(query).is_empty():
			holes.append(Vector2i(0, z))
	if holes.is_empty():
		print("MAP_FLOOR_COVERAGE_OK")
		quit(0)
	else:
		push_error("Missing third-zone floor at: %s" % holes)
		quit(1)
