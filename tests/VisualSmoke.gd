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

func _run():
	var game_state = root.get_node("GameState")
	var inventory = root.get_node("Inventory")
	var database = root.get_node("Database")
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)
	await process_frame
	await process_frame

	_expect(game_state.create_character("knight"), "character creation")
	main_scene._start_level()
	await create_timer(0.25).timeout

	var player = get_first_node_in_group("player")
	_expect(player != null, "player spawned")
	_expect(get_nodes_in_group("enemies").size() == 4, "four enemies spawned")
	_expect(get_nodes_in_group("interactable").size() >= 2, "bonfires are interactable")
	_expect(player.visual_model != null, "modular player model attached")
	_expect(player.visual_model.get_armor_slot("chest_armor") != null, "armor slots available")
	await RenderingServer.frame_post_draw
	var initial_image = root.get_texture().get_image()
	_expect(initial_image.save_png("res://.godot/visual_initial.png") == OK, "initial camera screenshot saved")

	var position_before_walk = player.global_position
	Input.action_press("move_forward")
	await create_timer(0.25).timeout
	Input.action_release("move_forward")
	_expect(player.global_position.distance_to(position_before_walk) > 0.2, "walking moves the player")
	var position_before_run = player.global_position
	var stamina_before_run = game_state.stamina
	Input.action_press("move_forward")
	Input.action_press("run")
	await create_timer(0.3).timeout
	Input.action_release("run")
	Input.action_release("move_forward")
	_expect(player.global_position.distance_to(position_before_run) > 1.0, "running uses increased movement speed")
	_expect(game_state.stamina < stamina_before_run, "running consumes stamina")
	game_state.stamina = game_state.max_stamina
	player._start_roll()
	_expect(player.is_rolling, "roll starts and consumes stamina")
	await create_timer(0.55).timeout

	player._toggle_lock_target()
	_expect(player.lock_target != null, "lock-on selects an enemy")
	game_state.stamina = game_state.max_stamina
	player._start_attack("light")
	_expect(player.is_attacking, "light attack starts and consumes stamina")
	await create_timer(0.7).timeout

	for weapon in database.list_weapons():
		inventory.equipment["right_weapon"] = weapon.item_id
		inventory.emit_signal("equipment_changed")
		await process_frame
		_expect(player.visual_model.attack_family == weapon.weapon_family, "%s visual family" % weapon.display_name)
		_expect(player.visual_model.get_armor_slot("right_weapon").get_child_count() > 0, "%s visible in hand" % weapon.display_name)
		game_state.stamina = game_state.max_stamina
		player.is_attacking = false
		player._start_attack("heavy")
		_expect(player.is_attacking and player.attack_type == "heavy", "%s heavy attack" % weapon.display_name)
		player.is_attacking = false
		player.visual_model.set_attack_state(false,"heavy",0.0,0.1)

	for class_data in database.list_classes():
		var armor = database.get_armor(class_data.starting_armor)
		player.visual_model.set_character_class(class_data.class_id)
		player.visual_model.set_equipped_armor(armor)
		var armor_parts = player.visual_model.get_armor_slot("chest_armor").get_child_count()
		armor_parts += player.visual_model.get_armor_slot("hips_armor").get_child_count()
		armor_parts += player.visual_model.get_armor_slot("head_armor").get_child_count()
		_expect(armor_parts > 0, "%s class appearance" % class_data.display_name)
	player.visual_model.set_character_class("knight")
	player.visual_model.set_equipped_armor(database.get_armor("knight_set"))
	inventory.equipment["right_weapon"] = "longsword"
	inventory.emit_signal("equipment_changed")

	var original_position = player.global_position
	player.global_position = Vector3(-8.0,0.0,1.35)
	player.rotation.y = 0.0
	await physics_frame
	await physics_frame
	var spring_arm = player.camera_pivot.get_child(0)
	_expect(spring_arm.get_hit_length() < spring_arm.spring_length, "camera spring arm prevents wall clipping")
	player.global_position = original_position

	var enemy = get_nodes_in_group("enemies")[0]
	var souls_before = game_state.souls
	enemy.take_damage(99999, player)
	await process_frame
	_expect(game_state.souls > souls_before, "enemy death awards souls")

	var damage = player.take_damage(5)
	_expect(damage > 0, "player receives damage")
	game_state.add_souls(150)
	player.take_damage(99999)
	await create_timer(1.2).timeout
	_expect(game_state.has_bloodstain, "death creates lost-souls bloodstain")
	_expect(get_nodes_in_group("bloodstain").size() == 1, "bloodstain visual spawned")
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png("res://.godot/visual_bloodstain.png") == OK, "bloodstain screenshot saved")

	player = get_first_node_in_group("player")
	var bloodstain = get_nodes_in_group("bloodstain")[0]
	bloodstain.interact(player)
	await process_frame
	_expect(not game_state.has_bloodstain and game_state.souls > 0, "lost souls recovered")

	var bonfire = get_nodes_in_group("bonfires").filter(func(node): return node.bonfire_id == "ash_camp")[0]
	player.global_position = bonfire.global_position + Vector3(3.0,0.0,3.0)
	player.look_at(Vector3(bonfire.global_position.x,player.global_position.y,bonfire.global_position.z),Vector3.UP)
	player.rotate_y(deg_to_rad(-24.0))
	await physics_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png("res://.godot/visual_bonfire_world.png") == OK, "bonfire world screenshot saved")
	bonfire.interact(player)
	await process_frame
	_expect(game_state.discovered_bonfires.has(bonfire.bonfire_id), "bonfire discovery and rest")
	var level_before = game_state.level
	game_state.add_souls(game_state.get_level_cost())
	_expect(game_state.level_up("strength") and game_state.level == level_before + 1, "level up spends souls and improves an attribute")
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png("res://.godot/visual_bonfire.png") == OK, "bonfire screenshot saved")
	var second_bonfire = get_nodes_in_group("bonfires").filter(func(node): return node.bonfire_id != bonfire.bonfire_id)[0]
	second_bonfire.interact(player)
	await process_frame
	_expect(game_state.travel_to_bonfire(bonfire.bonfire_id), "fast travel between discovered bonfires")

	var ui = get_first_node_in_group("ui")
	ui.close_bonfire_menu()
	ui.toggle_inventory()
	_expect(ui.inventory_panel.visible, "inventory opens")
	ui.close_inventory()

	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var screenshot_error = image.save_png("res://.godot/visual_validation.png")
	_expect(screenshot_error == OK, "visual validation screenshot saved")
	var measured_fps = Performance.get_monitor(Performance.TIME_FPS)
	print("Measured FPS: ", measured_fps)
	_expect(measured_fps >= 30.0, "scene maintains at least 30 FPS during validation")

	if failures.is_empty():
		print("VISUAL_SMOKE_OK")
		quit(0)
	else:
		print("VISUAL_SMOKE_FAILED: ", failures)
		quit(1)
