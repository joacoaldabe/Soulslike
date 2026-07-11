extends SceneTree

var failures: Array[String] = []
var model: PlayerModel

func _initialize():
	call_deferred("_run")

func _expect(condition: bool, message: String):
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _lowest_body_y() -> float:
	var lowest := INF
	var right_weapon_slot = model.get_armor_slot("right_weapon")
	var left_weapon_slot = model.get_armor_slot("left_weapon")
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if right_weapon_slot.is_ancestor_of(node) or left_weapon_slot.is_ancestor_of(node):
			continue
		var bounds = node.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					lowest = min(lowest, (node.global_transform * Vector3(x,y,z)).y)
	return lowest

func _run():
	model = load("res://scenes/PlayerModel.tscn").instantiate()
	root.add_child(model)
	await process_frame
	model.set_character_class("knight")
	model.set_equipped_armor(root.get_node("Database").get_armor("knight_set"))
	model.set_equipped_weapon(root.get_node("Database").get_weapon("longsword"))
	await process_frame
	model.set_action_phase("none","none",0.0)
	model._pose_model()
	var standing_floor = _lowest_body_y()

	for weapon in root.get_node("Database").list_weapons():
		model.set_equipped_weapon(weapon)
		for phase_data in [["windup",0.75],["active",0.1],["active",0.5],["active",0.9]]:
			model.set_action_phase("attack",phase_data[0],phase_data[1])
			model._pose_model()
			var hand_z = model.right_hand.global_position.z
			_expect(hand_z < 0.18, "%s attack %s %.2f keeps weapon hand in front (z=%.3f)" % [weapon.weapon_family,phase_data[0],phase_data[1],hand_z])

	model.set_action_phase("none","none",0.0)
	model._pose_model()
	model.set_roll_direction(Vector3.FORWARD)
	model.set_action_phase("roll","impulse",1.0)
	model._pose_model()
	_expect(abs(model.rig_root.global_transform.basis.y.z) > 0.85 and abs(model.left_thigh.rotation_degrees.x) < 25.0, "roll launch reaches a stretched horizontal dive")
	_expect(abs(model.left_forearm.rotation_degrees.x) < 10.0 and model.left_hand.global_position.y > model.head.global_position.y, "roll launch stretches both arms upward")
	_expect(_lowest_body_y() > standing_floor + 0.70, "roll dive rises clearly above the floor")
	model.set_action_phase("roll","invulnerable",0.55)
	model._pose_model()
	_expect(abs(model.left_thigh.rotation_degrees.x) > 110.0 and abs(model.left_shin.rotation_degrees.x) > 70.0, "roll tightens into a fetal rotation pose")
	var fetal_hand_distance = model.right_hand.global_position.distance_to(model.chest.global_position)
	var fetal_foot_distance = model.right_foot.global_position.distance_to(model.chest.global_position)
	_expect(fetal_hand_distance < 0.58 and fetal_foot_distance > 0.34 and fetal_foot_distance < 0.78, "fetal pose stays compact without putting feet inside torso (hand=%.3f foot=%.3f)" % [fetal_hand_distance,fetal_foot_distance])
	var back_y = (model.chest.global_transform * Vector3(0.0,0.0,0.22)).y
	var front_y = (model.chest.global_transform * Vector3(0.0,0.0,-0.22)).y
	_expect(back_y < front_y - 0.05, "roll presents the back, not the chest, toward the floor")
	_expect(_lowest_body_y() > standing_floor + 0.95, "fetal rotation happens near standing head height")
	model.set_action_phase("roll","travel",0.30)
	model._pose_model()
	_expect(abs(model.left_thigh.rotation_degrees.x) > 110.0 and abs(model.left_shin.rotation_degrees.x) > 70.0, "roll keeps the fetal pose through its main rotation")
	_expect(_lowest_body_y() > standing_floor + 0.05, "roll remains airborne until the end of its main rotation")
	model.set_action_phase("roll","landing",0.8)
	model._pose_model()
	_expect(model.rig_root.global_transform.basis.y.dot(Vector3.UP) > 0.98, "roll releases into an upright landing")

	for direction in [Vector3.FORWARD, Vector3.LEFT]:
		model.set_action_phase("none","none",0.0)
		model._pose_model()
		model.set_roll_direction(direction)
		for phase_data in [["prepare",0.5],["impulse",0.5],["invulnerable",0.15],["invulnerable",0.5],["invulnerable",0.85],["travel",0.35],["travel",0.8],["landing",0.4],["recovery",0.5]]:
			model.set_action_phase("roll",phase_data[0],phase_data[1])
			model._pose_model()
			var lowest = _lowest_body_y()
			_expect(lowest >= standing_floor - 0.015, "roll %s %.2f stays above standing floor (lowest=%.3f baseline=%.3f)" % [phase_data[0],phase_data[1],lowest,standing_floor])

	if failures.is_empty():
		print("PLAYER_ANIMATION_GEOMETRY_OK")
		quit(0)
	else:
		print("PLAYER_ANIMATION_GEOMETRY_FAILED: ",failures)
		quit(1)
