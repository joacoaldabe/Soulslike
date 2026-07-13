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
	_expect(game_state.create_character("knight"), "level UI test character created")
	var ui = load("res://scenes/UI.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	game_state.add_souls(game_state.get_level_cost() * 2)
	ui.open_level_up_menu()
	await process_frame
	_expect(ui.level_panel.visible and not ui.bonfire_panel.visible, "level screen replaces the compact bonfire menu")
	var viewport_center = root.get_viewport().get_visible_rect().size * 0.5
	var panel_center = ui.level_panel.get_global_rect().get_center()
	_expect(panel_center.distance_to(viewport_center) < 2.0, "level screen is centered in the viewport")
	_expect(ui.level_attribute_list.get_item_count() == game_state.ATTRIBUTES.size(), "all level attributes are selectable")

	var vitality_index = game_state.ATTRIBUTES.find("vitality")
	ui._refresh_level_preview(vitality_index)
	var vitality_preview = game_state.get_level_preview("vitality")
	_expect(vitality_preview["next"]["health"] == vitality_preview["current"]["health"] + 28, "vitality preview shows exact maximum health gain")
	_expect(ui.level_preview_labels["health"][1].text == str(vitality_preview["next"]["health"]), "health preview is rendered in the new value column")

	var strength_index = game_state.ATTRIBUTES.find("strength")
	ui._refresh_level_preview(strength_index)
	var strength_preview = game_state.get_level_preview("strength")
	_expect(strength_preview["next"]["light_damage"] > strength_preview["current"]["light_damage"], "strength preview reflects equipped weapon scaling")
	_expect(ui.level_effect_label.text.contains("ataque ligero"), "selected attribute explains affected derived stats")

	var level_before = game_state.level
	var souls_before = game_state.souls
	var cost_before = game_state.get_level_cost()
	ui._level_up_selected_attribute()
	_expect(game_state.level == level_before + 1 and game_state.souls == souls_before - cost_before, "confirmation spends displayed souls and raises one level")
	_expect(ui.level_panel.visible, "level screen stays open for consecutive upgrades")

	ui.close_level_up_menu()
	_expect(not ui.level_panel.visible and ui.bonfire_panel.visible, "back returns to the bonfire menu")
	if failures.is_empty():
		print("LEVEL_UP_UI_OK")
		quit(0)
	else:
		print("LEVEL_UP_UI_FAILED: ", failures)
		quit(1)
