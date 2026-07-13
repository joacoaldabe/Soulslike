extends CanvasLayer

const PlayerModelScene = preload("res://scenes/PlayerModel.tscn")
const CHARACTER_CLASS_ORDER = ["warrior", "knight", "wanderer", "thief", "bandit", "hunter", "sorcerer", "pyromancer", "cleric", "deprived"]

signal character_selected(class_id)
signal rest_requested
signal travel_requested(bonfire_id)

var creator_panel = null
var creator_backdrop = null
var creator_columns = null
var creator_root = null
var creator_stats_labels = {}
var creator_equipment_label = null
var class_list = null
var class_details = null
var creator_preview_container = null
var creator_preview_viewport = null
var creator_preview_model: PlayerModel = null
var creator_left_column = null
var creator_middle_column = null
var creator_right_column = null
var creator_start_button = null
var hud = null
var health_label = null
var health_bar = null
var stamina_label = null
var stamina_bar = null
var souls_label = null
var weapon_label = null
var inventory_panel = null
var inventory_lists = {}
var bonfire_panel = null
var bonfire_menu_id := ""
var travel_option = null
var level_panel = null
var level_attribute_list = null
var level_overview_labels = {}
var level_preview_labels = {}
var level_weapon_label = null
var level_scaling_label = null
var level_effect_label = null
var level_confirm_button = null
var notification_label = null
var visual_theme: Theme = null

func _ready():
	add_to_group("ui")
	_apply_visual_theme()
	_build_creator()
	_build_hud()
	_build_inventory()
	_build_bonfire_menu()
	_build_level_up_menu()
	_build_notifications()
	GameState.health_changed.connect(_refresh_hud)
	GameState.stamina_changed.connect(_refresh_hud)
	GameState.souls_changed.connect(_refresh_hud)
	GameState.stats_changed.connect(_refresh_hud)
	Inventory.inventory_changed.connect(_refresh_inventory)
	Inventory.equipment_changed.connect(_refresh_hud)
	Inventory.equipment_changed.connect(_refresh_inventory)
	_refresh_hud()
	_refresh_inventory()
	get_viewport().size_changed.connect(_update_creator_layout)

func _apply_visual_theme():
	var theme = Theme.new()
	theme.default_font_size = 17
	var panel = StyleBoxFlat.new()
	panel.bg_color = Color(0.055,0.065,0.075,0.94)
	panel.border_color = Color(0.34,0.31,0.26,0.9)
	panel.set_border_width_all(1)
	panel.corner_radius_top_left = 3
	panel.corner_radius_top_right = 3
	panel.corner_radius_bottom_left = 3
	panel.corner_radius_bottom_right = 3
	panel.content_margin_left = 18
	panel.content_margin_right = 18
	panel.content_margin_top = 14
	panel.content_margin_bottom = 14
	theme.set_stylebox("panel", "PanelContainer", panel)
	var button = panel.duplicate()
	button.bg_color = Color(0.12,0.13,0.14,0.96)
	theme.set_stylebox("normal", "Button", button)
	var hover = button.duplicate()
	hover.bg_color = Color(0.25,0.22,0.17,0.98)
	hover.border_color = Color(0.72,0.57,0.33,1.0)
	theme.set_stylebox("hover", "Button", hover)
	var selected = button.duplicate()
	selected.bg_color = Color(0.32,0.25,0.14,0.98)
	selected.border_color = Color(0.82,0.66,0.34,1.0)
	selected.set_border_width_all(1)
	theme.set_stylebox("selected", "ItemList", selected)
	theme.set_stylebox("selected_focus", "ItemList", selected)
	theme.set_stylebox("hovered", "ItemList", hover)
	theme.set_color("font_selected_color", "ItemList", Color("f1d58d"))
	var health_fill = StyleBoxFlat.new()
	health_fill.bg_color = Color("8f3038")
	var stamina_fill = StyleBoxFlat.new()
	stamina_fill.bg_color = Color("4b8c58")
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04,0.045,0.05,0.9)
	bar_bg.border_color = Color(0.24,0.25,0.24,1)
	bar_bg.set_border_width_all(1)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_color("font_color", "Label", Color("d8d2c2"))
	visual_theme = theme
	set_meta("health_fill", health_fill)
	set_meta("stamina_fill", stamina_fill)

func _build_creator():
	creator_backdrop = ColorRect.new()
	creator_backdrop.name = "CreatorBackdrop"
	creator_backdrop.color = Color(0.025, 0.03, 0.035, 0.985)
	creator_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(creator_backdrop)
	var center = CenterContainer.new()
	center.name = "CreatorCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	creator_backdrop.add_child(center)
	creator_panel = PanelContainer.new()
	creator_panel.theme = visual_theme
	creator_panel.name = "CharacterCreator"
	center.add_child(creator_panel)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	creator_panel.add_child(scroll)
	creator_root = VBoxContainer.new()
	creator_root.add_theme_constant_override("separation", 12)
	creator_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(creator_root)
	var title = Label.new()
	title.text = "CREAR PERSONAJE"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("ddd5c2"))
	creator_root.add_child(title)
	var subtitle = Label.new()
	subtitle.text = "Selecciona una clase inicial"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("9b927f"))
	creator_root.add_child(subtitle)
	creator_root.add_child(HSeparator.new())
	creator_columns = BoxContainer.new()
	creator_columns.add_theme_constant_override("separation", 16)
	creator_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	creator_root.add_child(creator_columns)

	creator_left_column = VBoxContainer.new()
	creator_left_column.add_theme_constant_override("separation", 8)
	creator_columns.add_child(creator_left_column)
	_add_creator_heading(creator_left_column, "ESTADISTICAS")
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 8)
	creator_left_column.add_child(stats_grid)
	var stat_rows = [["level", "Nivel"]]
	for attribute_name in GameState.ATTRIBUTES:
		stat_rows.append([attribute_name, GameState.ATTRIBUTE_LABELS[attribute_name]])
	for stat_data in stat_rows:
		var stat_name = Label.new()
		stat_name.text = stat_data[1]
		stat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_grid.add_child(stat_name)
		var stat_value = Label.new()
		stat_value.text = "0"
		stat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stat_value.add_theme_color_override("font_color", Color("e5c77e"))
		stats_grid.add_child(stat_value)
		creator_stats_labels[stat_data[0]] = stat_value
	creator_left_column.add_child(HSeparator.new())
	creator_equipment_label = Label.new()
	creator_equipment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	creator_equipment_label.add_theme_font_size_override("font_size", 15)
	creator_left_column.add_child(creator_equipment_label)

	creator_middle_column = VBoxContainer.new()
	creator_middle_column.add_theme_constant_override("separation", 8)
	creator_columns.add_child(creator_middle_column)
	_add_creator_heading(creator_middle_column, "CLASE")
	class_list = ItemList.new()
	class_list.name = "ClassList"
	class_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	class_list.allow_reselect = true
	creator_middle_column.add_child(class_list)
	for class_id in CHARACTER_CLASS_ORDER:
		var class_data = Database.get_character_class(class_id)
		if class_data == null:
			continue
		class_list.add_item(class_data.display_name)
		class_list.set_item_metadata(class_list.get_item_count() - 1, class_data.class_id)
	class_details = RichTextLabel.new()
	class_details.custom_minimum_size.y = 105
	class_details.bbcode_enabled = true
	class_details.fit_content = false
	creator_middle_column.add_child(class_details)

	creator_right_column = VBoxContainer.new()
	creator_right_column.add_theme_constant_override("separation", 8)
	creator_columns.add_child(creator_right_column)
	_add_creator_heading(creator_right_column, "APARIENCIA")
	_build_creator_preview()
	creator_start_button = Button.new()
	creator_start_button.text = "Comenzar"
	creator_start_button.custom_minimum_size.y = 46
	creator_start_button.pressed.connect(_confirm_character)
	creator_root.add_child(creator_start_button)
	class_list.item_selected.connect(_refresh_class_details)
	class_list.item_activated.connect(func(_index): _confirm_character())
	if class_list.get_item_count() > 0:
		class_list.select(0)
	_refresh_class_details(0)
	_update_creator_layout()

func _add_creator_heading(parent: VBoxContainer, text: String):
	var heading = Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color("c69b50"))
	parent.add_child(heading)
	parent.add_child(HSeparator.new())

func _build_creator_preview():
	creator_preview_container = SubViewportContainer.new()
	creator_preview_container.name = "CharacterPreview"
	creator_preview_container.stretch = true
	creator_preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	creator_preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	creator_preview_container.gui_input.connect(_on_creator_preview_input)
	creator_right_column.add_child(creator_preview_container)
	creator_preview_viewport = SubViewport.new()
	creator_preview_viewport.name = "PreviewViewport"
	creator_preview_viewport.size = Vector2i(420, 500)
	creator_preview_viewport.own_world_3d = true
	creator_preview_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	creator_preview_container.add_child(creator_preview_viewport)
	var world_environment = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0b0e10")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8d8170")
	environment.ambient_light_energy = 0.72
	world_environment.environment = environment
	creator_preview_viewport.add_child(world_environment)
	var key_light = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-38, -32, 0)
	key_light.light_color = Color("ffd8a2")
	key_light.light_energy = 1.45
	creator_preview_viewport.add_child(key_light)
	var rim_light = DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(-20, 145, 0)
	rim_light.light_color = Color("8ca3b8")
	rim_light.light_energy = 0.75
	creator_preview_viewport.add_child(rim_light)
	var camera = Camera3D.new()
	camera.position = Vector3(0, 1.15, -4.65)
	camera.fov = 35.0
	camera.look_at_from_position(camera.position, Vector3(0, 1.05, 0), Vector3.UP)
	creator_preview_viewport.add_child(camera)
	creator_preview_model = PlayerModelScene.instantiate()
	creator_preview_model.name = "PreviewModel"
	creator_preview_model.position = Vector3(0, -0.05, 0)
	creator_preview_viewport.add_child(creator_preview_model)

func _on_creator_preview_input(event):
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT and creator_preview_model != null:
		creator_preview_model.rotate_y(-event.relative.x * 0.012)

func _update_creator_layout():
	if creator_panel == null:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_width: float = min(1420.0, max(300.0, viewport_size.x - 24.0))
	var panel_height: float = min(820.0, max(280.0, viewport_size.y - 24.0))
	creator_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	creator_root.custom_minimum_size.x = max(250.0, panel_width - 44.0)
	var compact := panel_width < 820.0
	creator_columns.vertical = compact
	for column in [creator_left_column, creator_middle_column, creator_right_column]:
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.custom_minimum_size.x = 0.0 if compact else (panel_width - 92.0) / 3.0
	creator_left_column.custom_minimum_size.y = 270.0 if compact else 0.0
	creator_middle_column.custom_minimum_size.y = 390.0 if compact else 0.0
	creator_right_column.custom_minimum_size.y = 430.0 if compact else 0.0
	class_list.custom_minimum_size.y = 265.0 if compact else 310.0
	creator_preview_container.custom_minimum_size.y = 360.0 if compact else 430.0

func _build_hud():
	hud = VBoxContainer.new()
	hud.theme = visual_theme
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.position = Vector2(16, 16)
	hud.custom_minimum_size = Vector2(300, 0)
	add_child(hud)
	health_label = Label.new()
	hud.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(280, 20)
	health_bar.add_theme_stylebox_override("fill", get_meta("health_fill"))
	hud.add_child(health_bar)
	stamina_label = Label.new()
	hud.add_child(stamina_label)
	stamina_bar = ProgressBar.new()
	stamina_bar.show_percentage = false
	stamina_bar.custom_minimum_size = Vector2(280, 20)
	stamina_bar.add_theme_stylebox_override("fill", get_meta("stamina_fill"))
	hud.add_child(stamina_bar)
	souls_label = Label.new()
	hud.add_child(souls_label)
	weapon_label = Label.new()
	hud.add_child(weapon_label)
	hud.hide()

func _build_inventory():
	inventory_panel = PanelContainer.new()
	inventory_panel.theme = visual_theme
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	inventory_panel.custom_minimum_size = Vector2(620, 440)
	add_child(inventory_panel)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	inventory_panel.add_child(root)
	var title = Label.new()
	title.text = "Inventario"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	root.add_child(columns)
	for item_type in ["weapon", "armor", "ring", "consumable"]:
		var column = VBoxContainer.new()
		column.custom_minimum_size = Vector2(145, 280)
		columns.add_child(column)
		var label = Label.new()
		label.text = item_type.capitalize()
		column.add_child(label)
		var list = ItemList.new()
		list.custom_minimum_size = Vector2(145, 240)
		column.add_child(list)
		inventory_lists[item_type] = list
		list.item_activated.connect(func(index): _activate_inventory_item(item_type, index))
	var close_button = Button.new()
	close_button.text = "Cerrar"
	close_button.pressed.connect(close_inventory)
	root.add_child(close_button)
	inventory_panel.hide()

func _build_bonfire_menu():
	bonfire_panel = PanelContainer.new()
	bonfire_panel.theme = visual_theme
	bonfire_panel.set_anchors_preset(Control.PRESET_CENTER)
	bonfire_panel.custom_minimum_size = Vector2(430, 330)
	add_child(bonfire_panel)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	bonfire_panel.add_child(root)
	var title = Label.new()
	title.text = "Bonfire"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var rest_button = Button.new()
	rest_button.text = "Descansar"
	rest_button.pressed.connect(func(): emit_signal("rest_requested"))
	root.add_child(rest_button)
	var level_button = Button.new()
	level_button.text = "Subir nivel"
	level_button.pressed.connect(open_level_up_menu)
	root.add_child(level_button)
	travel_option = OptionButton.new()
	root.add_child(travel_option)
	var travel_button = Button.new()
	travel_button.text = "Viajar"
	travel_button.pressed.connect(_travel_to_selected_bonfire)
	root.add_child(travel_button)
	var close_button = Button.new()
	close_button.text = "Cerrar"
	close_button.pressed.connect(close_bonfire_menu)
	root.add_child(close_button)
	bonfire_panel.hide()

func _build_level_up_menu():
	level_panel = PanelContainer.new()
	level_panel.name = "LevelUpPanel"
	level_panel.theme = visual_theme
	level_panel.set_anchors_preset(Control.PRESET_CENTER)
	level_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	level_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	level_panel.custom_minimum_size = Vector2(1050, 610)
	add_child(level_panel)
	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	level_panel.add_child(root)
	var title = Label.new()
	title.text = "SUBIR DE NIVEL"
	title.add_theme_font_size_override("font_size", 27)
	root.add_child(title)
	var subtitle = Label.new()
	subtitle.text = "Selecciona un atributo para previsualizar los cambios"
	subtitle.modulate = Color(0.74, 0.70, 0.61)
	root.add_child(subtitle)
	root.add_child(HSeparator.new())
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)
	var attributes_box = _level_column(columns, "ATRIBUTOS", Vector2(300, 430))
	for key in ["level", "souls", "cost"]:
		var label = Label.new()
		attributes_box.add_child(label)
		level_overview_labels[key] = label
	attributes_box.add_child(HSeparator.new())
	level_attribute_list = ItemList.new()
	level_attribute_list.custom_minimum_size = Vector2(270, 310)
	level_attribute_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_attribute_list.allow_reselect = true
	attributes_box.add_child(level_attribute_list)
	for attribute_name in GameState.ATTRIBUTES:
		level_attribute_list.add_item(GameState.ATTRIBUTE_LABELS[attribute_name])
		level_attribute_list.set_item_metadata(level_attribute_list.get_item_count() - 1, attribute_name)
	level_attribute_list.item_selected.connect(_refresh_level_preview)
	var stats_box = _level_column(columns, "ESTADISTICAS", Vector2(390, 430))
	var stat_header = GridContainer.new()
	stat_header.columns = 3
	stat_header.add_theme_constant_override("h_separation", 18)
	stats_box.add_child(stat_header)
	_add_level_grid_label(stat_header, "Parametro", 180)
	_add_level_grid_label(stat_header, "Actual", 72, HORIZONTAL_ALIGNMENT_RIGHT)
	_add_level_grid_label(stat_header, "Nuevo", 72, HORIZONTAL_ALIGNMENT_RIGHT)
	stats_box.add_child(HSeparator.new())
	var stats_grid = GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 18)
	stats_grid.add_theme_constant_override("v_separation", 12)
	stats_box.add_child(stats_grid)
	for stat_data in [["health","Vida"],["stamina","Energia"],["defense","Reduccion de dano"],["light_damage","Ataque ligero"],["heavy_damage","Ataque fuerte"]]:
		_add_level_grid_label(stats_grid, stat_data[1], 180)
		var current = _add_level_grid_label(stats_grid, "0", 72, HORIZONTAL_ALIGNMENT_RIGHT)
		var next = _add_level_grid_label(stats_grid, "0", 72, HORIZONTAL_ALIGNMENT_RIGHT)
		level_preview_labels[stat_data[0]] = [current, next]
	var equipment_box = _level_column(columns, "EQUIPO Y ESCALADO", Vector2(280, 430))
	level_weapon_label = Label.new()
	level_weapon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_box.add_child(level_weapon_label)
	equipment_box.add_child(HSeparator.new())
	level_scaling_label = Label.new()
	level_scaling_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_box.add_child(level_scaling_label)
	equipment_box.add_child(HSeparator.new())
	level_effect_label = Label.new()
	level_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level_effect_label.modulate = Color(0.88, 0.78, 0.52)
	equipment_box.add_child(level_effect_label)
	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)
	var back_button = Button.new()
	back_button.text = "Volver"
	back_button.custom_minimum_size = Vector2(130, 42)
	back_button.pressed.connect(close_level_up_menu)
	footer.add_child(back_button)
	level_confirm_button = Button.new()
	level_confirm_button.text = "Confirmar nivel"
	level_confirm_button.custom_minimum_size = Vector2(190, 42)
	level_confirm_button.pressed.connect(_level_up_selected_attribute)
	footer.add_child(level_confirm_button)
	level_panel.hide()

func _level_column(parent: HBoxContainer, title_text: String, minimum_size: Vector2) -> VBoxContainer:
	var box = VBoxContainer.new()
	box.custom_minimum_size = minimum_size
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	parent.add_child(box)
	var title = Label.new()
	title.text = title_text
	title.modulate = Color(0.82, 0.68, 0.39)
	box.add_child(title)
	box.add_child(HSeparator.new())
	return box

func _add_level_grid_label(parent: GridContainer, text: String, width: float, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label = Label.new()
	label.text = text
	label.custom_minimum_size.x = width
	label.horizontal_alignment = alignment
	parent.add_child(label)
	return label

func _build_notifications():
	notification_label = Label.new()
	notification_label.theme = visual_theme
	notification_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	notification_label.position = Vector2(16, -56)
	notification_label.custom_minimum_size = Vector2(650, 40)
	add_child(notification_label)

func show_character_creator():
	creator_backdrop.show()
	creator_panel.show()
	hud.hide()
	inventory_panel.hide()
	bonfire_panel.hide()
	level_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_creator_layout()
	if class_list != null:
		class_list.grab_focus()

func show_hud():
	creator_backdrop.hide()
	creator_panel.hide()
	hud.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_hud()

func _confirm_character():
	var selected = class_list.get_selected_items()
	if selected.is_empty():
		return
	var class_id = class_list.get_item_metadata(selected[0])
	emit_signal("character_selected", class_id)

func _refresh_class_details(index):
	if class_list.get_item_count() == 0:
		return
	if index < 0 or index >= class_list.get_item_count():
		index = 0
	class_list.select(index)
	var selected_class_id = class_list.get_item_metadata(index)
	var class_data = Database.get_character_class(selected_class_id)
	if class_data == null:
		return
	creator_stats_labels["level"].text = str(class_data.level)
	for attribute_name in GameState.ATTRIBUTES:
		creator_stats_labels[attribute_name].text = str(int(class_data.attributes.get(attribute_name, 1)))
	var weapon = Database.get_item(class_data.starting_weapon)
	var armor = Database.get_item(class_data.starting_armor)
	creator_equipment_label.text = "EQUIPO INICIAL\n%s\n%s\n\nDefensa: %d    Peso: %.1f" % [
		weapon.display_name if weapon != null else "Sin arma",
		armor.display_name if armor != null else "Sin armadura",
		armor.defense if armor != null else 0,
		armor.weight if armor != null else 0.0
	]
	class_details.text = "[b]%s[/b]\n%s" % [class_data.display_name, class_data.description]
	if creator_preview_model != null:
		creator_preview_model.rotation = Vector3.ZERO
		creator_preview_model.set_character_class(class_data.class_id)
		creator_preview_model.set_equipped_weapon(weapon)
		creator_preview_model.set_equipped_armor(armor)

func _refresh_hud():
	if health_bar == null:
		return
	health_bar.max_value = GameState.max_health
	health_bar.value = GameState.health
	health_label.text = "VIDA"
	stamina_bar.max_value = GameState.max_stamina
	stamina_bar.value = GameState.stamina
	stamina_label.text = "ENERGIA"
	souls_label.text = "%d souls    Nivel %d" % [GameState.souls, GameState.level]
	var weapon = Inventory.get_equipped_weapon()
	weapon_label.text = "Arma: %s" % (weapon.display_name if weapon != null else "Sin arma")

func _refresh_inventory():
	if inventory_panel == null:
		return
	for item_type in inventory_lists.keys():
		var list = inventory_lists[item_type]
		list.clear()
		for item_id in Inventory.get_items_by_type(item_type):
			var item = Database.get_item(item_id)
			if item == null:
				continue
			var label = "%s x%d" % [item.display_name, Inventory.item_counts[item_id]]
			if _is_equipped(item_id):
				label += " *"
			list.add_item(label)
			list.set_item_metadata(list.get_item_count() - 1, item_id)

func _is_equipped(item_id):
	for value in Inventory.equipment.values():
		if value == item_id:
			return true
	return false

func _activate_inventory_item(item_type, index):
	var list = inventory_lists[item_type]
	var item_id = list.get_item_metadata(index)
	if item_type == "consumable":
		Inventory.use_consumable(item_id)
	else:
		if not Inventory.equip_item(item_id):
			notify("No cumplis los requisitos del item.")
	_refresh_inventory()

func toggle_inventory():
	if not GameState.character_ready:
		return
	if bonfire_panel.visible or level_panel.visible or creator_panel.visible:
		return
	if inventory_panel.visible:
		close_inventory()
	else:
		_refresh_inventory()
		inventory_panel.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_inventory():
	inventory_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if bonfire_panel.visible or level_panel.visible or creator_panel.visible else Input.MOUSE_MODE_CAPTURED

func is_blocking_gameplay():
	return creator_panel.visible or inventory_panel.visible or bonfire_panel.visible or level_panel.visible

func open_bonfire_menu(selected_bonfire_id):
	bonfire_menu_id = str(selected_bonfire_id)
	_refresh_travel_options()
	_refresh_hud()
	level_panel.hide()
	bonfire_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_bonfire_menu():
	bonfire_panel.hide()
	level_panel.hide()
	get_tree().call_group("player", "end_bonfire_rest")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_travel_options():
	travel_option.clear()
	for bonfire_id in GameState.discovered_bonfires.keys():
		var bonfire = Database.get_bonfire(bonfire_id)
		if bonfire == null:
			continue
		travel_option.add_item(bonfire.display_name)
		travel_option.set_item_metadata(travel_option.get_item_count() - 1, bonfire_id)

func open_level_up_menu():
	bonfire_panel.hide()
	level_panel.show()
	if level_attribute_list.get_item_count() > 0:
		if level_attribute_list.get_selected_items().is_empty():
			level_attribute_list.select(0)
		_refresh_level_preview(level_attribute_list.get_selected_items()[0])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_level_up_menu():
	level_panel.hide()
	bonfire_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _refresh_level_preview(index := -1):
	if level_attribute_list == null or level_attribute_list.get_item_count() == 0:
		return
	if index < 0:
		var selected = level_attribute_list.get_selected_items()
		index = selected[0] if not selected.is_empty() else 0
	level_attribute_list.select(index)
	var attribute_name: String = level_attribute_list.get_item_metadata(index)
	var preview = GameState.get_level_preview(attribute_name)
	var current = preview["current"]
	var next = preview["next"]
	level_overview_labels["level"].text = "Nivel                 %d  >  %d" % [current["level"], next["level"]]
	level_overview_labels["souls"].text = "Souls                 %d  >  %d" % [current["souls"], next["souls"]]
	level_overview_labels["cost"].text = "Souls requeridas      %d" % preview["cost"]
	for item_index in range(level_attribute_list.get_item_count()):
		var item_attribute: String = level_attribute_list.get_item_metadata(item_index)
		var value = GameState.get_attribute(item_attribute)
		level_attribute_list.set_item_text(item_index, "%s        %d%s" % [GameState.ATTRIBUTE_LABELS[item_attribute], value, "  >  %d" % (value + 1) if item_attribute == attribute_name else ""])
	for stat_name in level_preview_labels.keys():
		var labels = level_preview_labels[stat_name]
		labels[0].text = str(current[stat_name])
		labels[1].text = str(next[stat_name])
		labels[1].modulate = Color(0.45, 0.78, 0.95) if next[stat_name] != current[stat_name] else Color(0.62, 0.62, 0.59)
	var weapon = Inventory.get_equipped_weapon()
	if weapon == null:
		level_weapon_label.text = "Arma equipada\nSin arma"
		level_scaling_label.text = "Escalado\nNinguno"
	else:
		level_weapon_label.text = "Arma equipada\n%s\n\nDano base: %d" % [weapon.display_name, weapon.base_damage]
		var scaling_parts = []
		for scaling_attribute in weapon.scaling.keys():
			scaling_parts.append("%s %s" % [GameState.ATTRIBUTE_LABELS.get(scaling_attribute, scaling_attribute), weapon.scaling[scaling_attribute]])
		level_scaling_label.text = "Escalado del arma\n%s" % (", ".join(scaling_parts) if not scaling_parts.is_empty() else "Sin escalado")
	var changed_stats = []
	for stat_data in [["health","vida maxima"],["stamina","energia maxima"],["defense","reduccion de dano"],["light_damage","ataque ligero"],["heavy_damage","ataque fuerte"]]:
		if next[stat_data[0]] != current[stat_data[0]]:
			changed_stats.append("%s +%d" % [stat_data[1], next[stat_data[0]] - current[stat_data[0]]])
	level_effect_label.text = "%s mejora:\n%s" % [GameState.ATTRIBUTE_LABELS[attribute_name], "\n".join(changed_stats) if not changed_stats.is_empty() else "Actualmente no modifica otra estadistica derivada."]
	level_confirm_button.disabled = GameState.souls < int(preview["cost"])
	level_confirm_button.text = "Confirmar nivel" if not level_confirm_button.disabled else "Souls insuficientes"

func _level_up_selected_attribute():
	var selected = level_attribute_list.get_selected_items()
	if selected.is_empty():
		return
	var attribute_name = level_attribute_list.get_item_metadata(selected[0])
	if GameState.level_up(attribute_name):
		notify("Subiste %s." % GameState.ATTRIBUTE_LABELS[attribute_name])
	else:
		notify("No tenes souls suficientes.")
	_refresh_hud()
	_refresh_level_preview(selected[0])

func _travel_to_selected_bonfire():
	if travel_option.get_item_count() == 0:
		return
	var bonfire_id = travel_option.get_selected_metadata()
	emit_signal("travel_requested", bonfire_id)

func notify(message):
	if notification_label == null:
		return
	notification_label.text = message
	var tween = create_tween()
	notification_label.modulate.a = 1.0
	tween.tween_property(notification_label, "modulate:a", 0.0, 3.0).set_delay(2.0)
