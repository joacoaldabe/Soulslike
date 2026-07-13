extends SceneTree

var failures: Array[String] = []

func _initialize():
	call_deferred("_run")

func _expect(condition: bool, message: String):
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _armor_signature(model: PlayerModel) -> String:
	var names: Array[String] = []
	for slot_name in ["head_armor", "face_armor", "chest_armor", "back_armor", "hips_armor", "left_shoulder_armor", "right_shoulder_armor", "left_forearm_armor", "right_forearm_armor"]:
		var slot = model.get_armor_slot(slot_name)
		if slot != null:
			_collect_mesh_names(slot, names)
	names.sort()
	return ",".join(names)

func _collect_mesh_names(node: Node, names: Array[String]):
	for child in node.get_children():
		if child is MeshInstance3D:
			names.append(child.name)
		_collect_mesh_names(child, names)

func _run():
	var database = root.get_node("Database")
	var ui = load("res://scenes/UI.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.show_character_creator()
	await process_frame
	_expect(ui.class_list.get_item_count() == 10, "creator lists all ten character classes")
	_expect(ui.creator_left_column.get_index() < ui.creator_middle_column.get_index() and ui.creator_middle_column.get_index() < ui.creator_right_column.get_index(), "stats, classes and character preview keep the required order")
	_expect(ui.creator_preview_model != null and ui.creator_preview_viewport != null, "creator uses a live 3D player preview")

	var armor_ids := {}
	var visual_signatures := {}
	for index in range(ui.class_list.get_item_count()):
		ui._refresh_class_details(index)
		await process_frame
		var class_id: String = ui.class_list.get_item_metadata(index)
		var class_data = database.get_character_class(class_id)
		var armor = database.get_armor(class_data.starting_armor)
		_expect(armor != null, "%s has a valid starting armor" % class_data.display_name)
		_expect(not armor_ids.has(class_data.starting_armor), "%s has a unique armor category" % class_data.display_name)
		armor_ids[class_data.starting_armor] = true
		_expect(ui.creator_preview_model.character_class_id == class_id, "%s updates the preview class" % class_data.display_name)
		_expect(ui.creator_preview_model.pending_armor != null and ui.creator_preview_model.pending_armor.item_id == class_data.starting_armor, "%s updates the visible preview armor" % class_data.display_name)
		var signature := _armor_signature(ui.creator_preview_model)
		_expect(signature != "", "%s preview contains visible armor geometry" % class_data.display_name)
		_expect(not visual_signatures.has(signature), "%s armor has a distinct physical silhouette" % class_data.display_name)
		visual_signatures[signature] = class_id
		_expect(ui.creator_stats_labels["level"].text == str(class_data.level) and ui.creator_stats_labels["strength"].text == str(class_data.attributes["strength"]), "%s updates the displayed statistics" % class_data.display_name)

	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(640, 480)]:
		root.size = resolution
		await process_frame
		await process_frame
		var panel_rect: Rect2 = ui.creator_panel.get_global_rect()
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(resolution))
		_expect(panel_rect.get_center().distance_to(Vector2(resolution) * 0.5) < 3.0, "creator stays centered at %dx%d" % [resolution.x, resolution.y])
		_expect(viewport_rect.encloses(panel_rect), "creator stays inside the viewport at %dx%d" % [resolution.x, resolution.y])
		_expect(ui.creator_columns.vertical == (resolution.x < 820), "creator switches to the responsive layout at %dx%d" % [resolution.x, resolution.y])

	root.size = Vector2i(1152, 648)
	ui.queue_free()
	await process_frame
	if failures.is_empty():
		print("CHARACTER_CREATOR_OK")
		quit(0)
	else:
		print("CHARACTER_CREATOR_FAILED: ", failures)
		quit(1)
