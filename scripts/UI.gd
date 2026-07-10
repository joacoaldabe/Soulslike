extends CanvasLayer

signal character_selected(class_id)
signal rest_requested
signal travel_requested(bonfire_id)

var creator_panel = null
var class_option = null
var class_details = null
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
var travel_option = null
var level_attribute_option = null
var level_cost_label = null
var notification_label = null

func _ready():
	add_to_group("ui")
	_build_creator()
	_build_hud()
	_build_inventory()
	_build_bonfire_menu()
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

func _build_creator():
	creator_panel = PanelContainer.new()
	creator_panel.name = "CharacterCreator"
	creator_panel.set_anchors_preset(Control.PRESET_CENTER)
	creator_panel.custom_minimum_size = Vector2(520, 520)
	add_child(creator_panel)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	creator_panel.add_child(box)
	var title = Label.new()
	title.text = "Crear personaje"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	class_option = OptionButton.new()
	box.add_child(class_option)
	for class_data in Database.list_classes():
		class_option.add_item(class_data.display_name)
		class_option.set_item_metadata(class_option.get_item_count() - 1, class_data.class_id)
	if class_option.get_item_count() > 0:
		class_option.select(0)
	class_details = RichTextLabel.new()
	class_details.custom_minimum_size = Vector2(480, 360)
	class_details.bbcode_enabled = true
	box.add_child(class_details)
	var start_button = Button.new()
	start_button.text = "Comenzar"
	box.add_child(start_button)
	class_option.item_selected.connect(_refresh_class_details)
	start_button.pressed.connect(_confirm_character)
	_refresh_class_details(0)

func _build_hud():
	hud = VBoxContainer.new()
	hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud.position = Vector2(16, 16)
	hud.custom_minimum_size = Vector2(300, 0)
	add_child(hud)
	health_label = Label.new()
	hud.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.custom_minimum_size = Vector2(280, 20)
	hud.add_child(health_bar)
	stamina_label = Label.new()
	hud.add_child(stamina_label)
	stamina_bar = ProgressBar.new()
	stamina_bar.show_percentage = false
	stamina_bar.custom_minimum_size = Vector2(280, 20)
	hud.add_child(stamina_bar)
	souls_label = Label.new()
	hud.add_child(souls_label)
	weapon_label = Label.new()
	hud.add_child(weapon_label)
	hud.hide()

func _build_inventory():
	inventory_panel = PanelContainer.new()
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
	bonfire_panel.set_anchors_preset(Control.PRESET_CENTER)
	bonfire_panel.custom_minimum_size = Vector2(430, 360)
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
	level_cost_label = Label.new()
	root.add_child(level_cost_label)
	level_attribute_option = OptionButton.new()
	for attribute_name in GameState.ATTRIBUTES:
		level_attribute_option.add_item(GameState.ATTRIBUTE_LABELS[attribute_name])
		level_attribute_option.set_item_metadata(level_attribute_option.get_item_count() - 1, attribute_name)
	root.add_child(level_attribute_option)
	var level_button = Button.new()
	level_button.text = "Subir nivel"
	level_button.pressed.connect(_level_up_selected_attribute)
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

func _build_notifications():
	notification_label = Label.new()
	notification_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	notification_label.position = Vector2(16, -56)
	notification_label.custom_minimum_size = Vector2(650, 40)
	add_child(notification_label)

func show_character_creator():
	creator_panel.show()
	hud.hide()
	inventory_panel.hide()
	bonfire_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_hud():
	creator_panel.hide()
	hud.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_hud()

func _confirm_character():
	var class_id = class_option.get_selected_metadata()
	emit_signal("character_selected", class_id)

func _refresh_class_details(_index):
	if class_option.get_item_count() == 0:
		return
	var selected_class_id = class_option.get_selected_metadata()
	var class_data = Database.get_character_class(selected_class_id)
	if class_data == null:
		return
	var text = "[b]%s[/b]\n%s\n\nNivel %d\n" % [class_data.display_name, class_data.description, class_data.level]
	for attribute_name in GameState.ATTRIBUTES:
		text += "%s: %d\n" % [GameState.ATTRIBUTE_LABELS[attribute_name], int(class_data.attributes.get(attribute_name, 1))]
	text += "\nEquipo inicial: %s, %s" % [
		Database.get_item(class_data.starting_weapon).display_name,
		Database.get_item(class_data.starting_armor).display_name
	]
	class_details.text = text

func _refresh_hud():
	if health_bar == null:
		return
	health_bar.max_value = GameState.max_health
	health_bar.value = GameState.health
	health_label.text = "HP %d / %d" % [GameState.health, GameState.max_health]
	stamina_bar.max_value = GameState.max_stamina
	stamina_bar.value = GameState.stamina
	stamina_label.text = "Stamina %d / %d" % [GameState.stamina, GameState.max_stamina]
	souls_label.text = "Souls: %d | Nivel: %d | Costo: %d" % [GameState.souls, GameState.level, GameState.get_level_cost()]
	var weapon = Inventory.get_equipped_weapon()
	weapon_label.text = "Arma: %s" % (weapon.display_name if weapon != null else "Sin arma")
	if level_cost_label != null:
		level_cost_label.text = "Costo de nivel: %d souls" % GameState.get_level_cost()

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
	if inventory_panel.visible:
		close_inventory()
	else:
		_refresh_inventory()
		inventory_panel.show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_inventory():
	inventory_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if bonfire_panel.visible or creator_panel.visible else Input.MOUSE_MODE_CAPTURED

func is_blocking_gameplay():
	return creator_panel.visible or inventory_panel.visible or bonfire_panel.visible

func open_bonfire_menu(_bonfire_id):
	_refresh_travel_options()
	_refresh_hud()
	bonfire_panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_bonfire_menu():
	bonfire_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _refresh_travel_options():
	travel_option.clear()
	for bonfire_id in GameState.discovered_bonfires.keys():
		var bonfire = Database.get_bonfire(bonfire_id)
		if bonfire == null:
			continue
		travel_option.add_item(bonfire.display_name)
		travel_option.set_item_metadata(travel_option.get_item_count() - 1, bonfire_id)

func _level_up_selected_attribute():
	var attribute_name = level_attribute_option.get_selected_metadata()
	if GameState.level_up(attribute_name):
		notify("Subiste %s." % GameState.ATTRIBUTE_LABELS[attribute_name])
	else:
		notify("No tenes souls suficientes.")
	_refresh_hud()

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
