extends VBoxContainer
class_name SettingsPanel

signal exit_to_menu_requested

var show_exit_to_menu := false
var resolution_selector: OptionButton
var window_mode_selector: OptionButton
var vsync_toggle: CheckButton
var exit_to_menu_button: Button

func _ready():
	add_theme_constant_override("separation", 14)
	_build_controls()
	refresh()

func _build_controls():
	var display_header := _label("PANTALLA", 17)
	display_header.add_theme_color_override("font_color", Color("b79a5a"))
	add_child(display_header)
	resolution_selector = OptionButton.new()
	resolution_selector.name = "ResolutionSelector"
	resolution_selector.custom_minimum_size.y = 44
	resolution_selector.item_selected.connect(_on_resolution_selected)
	add_child(_setting_row("Resolucion", resolution_selector, "display"))
	window_mode_selector = OptionButton.new()
	window_mode_selector.name = "WindowModeSelector"
	window_mode_selector.add_item("Ventana", 0)
	window_mode_selector.add_item("Pantalla completa", 1)
	window_mode_selector.custom_minimum_size.y = 44
	window_mode_selector.item_selected.connect(func(index): AppSettings.set_fullscreen(index == 1))
	add_child(_setting_row("Modo", window_mode_selector, "class"))
	vsync_toggle = CheckButton.new()
	vsync_toggle.name = "VSyncToggle"
	vsync_toggle.text = "Activado"
	vsync_toggle.toggled.connect(AppSettings.set_vsync)
	add_child(_setting_row("VSync", vsync_toggle, "stamina"))
	if show_exit_to_menu:
		add_child(HSeparator.new())
		exit_to_menu_button = Button.new()
		exit_to_menu_button.name = "ExitToMenuButton"
		exit_to_menu_button.text = "Salir al menu"
		exit_to_menu_button.icon = IconCatalog.get_stat_icon("exit")
		exit_to_menu_button.expand_icon = true
		exit_to_menu_button.custom_minimum_size.y = 52
		exit_to_menu_button.pressed.connect(func(): exit_to_menu_requested.emit())
		add_child(exit_to_menu_button)

func _setting_row(title: String, control: Control, icon_id: String) -> BoxContainer:
	var row := BoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var heading := HBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.custom_minimum_size.x = 180
	heading.add_theme_constant_override("separation", 10)
	row.add_child(heading)
	var icon := TextureRect.new()
	icon.texture = IconCatalog.get_stat_icon(icon_id)
	icon.custom_minimum_size = Vector2(38, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(icon)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	control.custom_minimum_size.x = 180
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	row.resized.connect(func(): row.vertical = row.size.x < 420.0)
	return row

func _label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	return label

func refresh():
	if resolution_selector == null:
		return
	resolution_selector.clear()
	var options := AppSettings.get_resolution_options()
	for option in options:
		resolution_selector.add_item("%d x %d" % [option.x, option.y])
		resolution_selector.set_item_metadata(resolution_selector.item_count - 1, option)
		if option == AppSettings.resolution:
			resolution_selector.select(resolution_selector.item_count - 1)
	window_mode_selector.select(1 if AppSettings.fullscreen else 0)
	vsync_toggle.button_pressed = AppSettings.vsync

func _on_resolution_selected(index: int):
	var value = resolution_selector.get_item_metadata(index)
	if value is Vector2i:
		AppSettings.set_resolution(value)
