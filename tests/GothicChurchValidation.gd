extends SceneTree

var failures: Array[String] = []

func _initialize():
	call_deferred("_run")

func _expect(condition: bool, message: String):
	if condition:
		print("PASS: ",message)
	else:
		failures.append(message)
		push_error("FAIL: "+message)

func _run():
	var database = root.get_node("Database")
	var level=GothicChurchLevel.new()
	root.add_child(level)
	level.build()
	await process_frame
	var rooms=get_nodes_in_group("level_room")
	var measured_area:=0.0
	for room in rooms:
		measured_area += float(room.get_meta("floor_area",0.0))
		_expect(room.get_node_or_null("Floor") != null, "%s has a visible floor" % room.name)
		_expect(room.get_child_count() >= 3, "%s has floor collision" % room.name)
	_expect(measured_area >= 4368.0, "playable floor area is at least eight original courtyards")
	_expect(level.PLAYABLE_AREA >= 4368.0, "declared playable area satisfies expansion")
	_expect(rooms.size() >= 12, "all major rooms and connectors exist")
	_expect(level.enemy_spawns.size() == 21, "enemy progression covers all sectors")
	_expect(level.chest_spawns.size() == 5, "optional rooms contain defined loot")
	for chest in level.chest_spawns:
		_expect(not chest["loot"].is_empty(), "%s has explicit loot" % chest["id"])
	for spawn in level.enemy_spawns:
		_expect(database.get_enemy(spawn["enemy_id"]) != null, "enemy id %s exists" % spawn["enemy_id"])
	if failures.is_empty():
		print("GOTHIC_CHURCH_VALIDATION_OK")
		quit(0)
	else:
		print("GOTHIC_CHURCH_VALIDATION_FAILED: ",failures)
		quit(1)
