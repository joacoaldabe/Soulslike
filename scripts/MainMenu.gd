extends Control

const GAME_SCENE := "res://scenes/Main.tscn"

var menu_panel: PanelContainer
var menu_box: VBoxContainer
var new_game_button: Button
var load_game_button: Button
var settings_button: Button
var exit_button: Button
var settings_panel: PanelContainer
var overwrite_dialog: ConfirmationDialog
var error_dialog: AcceptDialog
var menu_theme: Theme
var title_label: Label
var subtitle_label: Label

func _ready():
	_build_theme()
	_build_menu()
	_build_dialogs()
	get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	load_game_button.disabled = not SaveManager.has_valid_save()
	new_game_button.grab_focus()

func _build_theme():
	menu_theme = Theme.new()
	menu_theme.default_font_size = 20
	menu_theme.set_color("font_color", "Label", Color("d6d1c4"))
	menu_theme.set_color("font_color", "Button", Color("d6d1c4"))
	menu_theme.set_color("font_hover_color", "Button", Color("ffe0a0"))
	menu_theme.set_color("font_focus_color", "Button", Color("ffe0a0"))
	menu_theme.set_color("font_disabled_color", "Button", Color(0.40, 0.41, 0.40, 1.0))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.045, 0.052, 0.058, 0.96)
	panel.border_color = Color(0.30, 0.29, 0.27, 1.0)
	panel.set_border_width_all(2)
	panel.corner_radius_top_left = 4
	panel.corner_radius_top_right = 4
	panel.corner_radius_bottom_left = 4
	panel.corner_radius_bottom_right = 4
	panel.content_margin_left = 34
	panel.content_margin_right = 34
	panel.content_margin_top = 30
	panel.content_margin_bottom = 30
	menu_theme.set_stylebox("panel", "PanelContainer", panel)
	var button := StyleBoxFlat.new()
	button.bg_color = Color(0.09, 0.10, 0.105, 0.98)
	button.border_color = Color(0.22, 0.23, 0.22, 1.0)
	button.set_border_width_all(1)
	button.content_margin_left = 18
	button.content_margin_right = 18
	button.content_margin_top = 11
	button.content_margin_bottom = 11
	menu_theme.set_stylebox("normal", "Button", button)
	var hover := button.duplicate()
	hover.bg_color = Color(0.18, 0.16, 0.12, 0.98)
	hover.border_color = Color(0.65, 0.49, 0.25, 1.0)
	menu_theme.set_stylebox("hover", "Button", hover)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.28, 0.20, 0.10, 1.0)
	menu_theme.set_stylebox("pressed", "Button", pressed)
	var focus := button.duplicate()
	focus.draw_center = false
	focus.border_color = Color(0.92, 0.63, 0.23, 1.0)
	focus.set_border_width_all(2)
	menu_theme.set_stylebox("focus", "Button", focus)
	var disabled := button.duplicate()
	disabled.bg_color = Color(0.06, 0.065, 0.067, 0.95)
	disabled.border_color = Color(0.14, 0.15, 0.15, 1.0)
	menu_theme.set_stylebox("disabled", "Button", disabled)

func _build_menu():
	var background := ColorRect.new()
	background.color = Color("141a1e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var upper_shadow := ColorRect.new()
	upper_shadow.color = Color(0.07, 0.075, 0.075, 0.82)
	upper_shadow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	upper_shadow.custom_minimum_size.y = 76
	upper_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(upper_shadow)
	var safe_margin := MarginContainer.new()
	safe_margin.name = "SafeMargin"
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		safe_margin.add_theme_constant_override(side, 24)
	add_child(safe_margin)
	var center := CenterContainer.new()
	center.name = "MenuCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_margin.add_child(center)
	menu_panel = PanelContainer.new()
	menu_panel.name = "MenuPanel"
	menu_panel.theme = menu_theme
	center.add_child(menu_panel)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 12)
	menu_panel.add_child(menu_box)
	title_label = Label.new()
	title_label.text = "RUINAS DE CENIZA"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color("ddd5c2"))
	menu_box.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.text = "Una llama persiste entre las ruinas"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 15)
	subtitle_label.add_theme_color_override("font_color", Color("9b927f"))
	menu_box.add_child(subtitle_label)
	menu_box.add_child(HSeparator.new())
	new_game_button = _add_menu_button("Nuevo juego")
	load_game_button = _add_menu_button("Cargar juego")
	settings_button = _add_menu_button("Configuracion")
	exit_button = _add_menu_button("Salir")
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	settings_button.pressed.connect(_show_settings)
	exit_button.pressed.connect(_exit_game)
	settings_panel = PanelContainer.new()
	settings_panel.name = "SettingsPanel"
	settings_panel.theme = menu_theme
	center.add_child(settings_panel)
	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 18)
	settings_panel.add_child(settings_box)
	var settings_title := Label.new()
	settings_title.text = "CONFIGURACION"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 28)
	settings_box.add_child(settings_title)
	var coming_soon := Label.new()
	coming_soon.text = "Proximamente"
	coming_soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coming_soon.custom_minimum_size.y = 100
	settings_box.add_child(coming_soon)
	var back_button := Button.new()
	back_button.text = "Volver"
	back_button.pressed.connect(_hide_settings.bind(back_button))
	settings_box.add_child(back_button)
	settings_panel.hide()

func _add_menu_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 50
	menu_box.add_child(button)
	return button

func _build_dialogs():
	overwrite_dialog = ConfirmationDialog.new()
	overwrite_dialog.title = "Sobrescribir partida"
	overwrite_dialog.dialog_text = "Ya existe una partida guardada. Queres reemplazarla?"
	overwrite_dialog.ok_button_text = "Sobrescribir"
	overwrite_dialog.cancel_button_text = "Cancelar"
	overwrite_dialog.confirmed.connect(_begin_new_game)
	add_child(overwrite_dialog)
	error_dialog = AcceptDialog.new()
	error_dialog.title = "No se pudo cargar"
	add_child(error_dialog)

func _update_responsive_layout():
	var viewport_size := get_viewport_rect().size
	var safe_width: float = max(260.0, viewport_size.x - 48.0)
	var panel_width: float = min(460.0, safe_width)
	menu_panel.custom_minimum_size = Vector2(panel_width, 0)
	settings_panel.custom_minimum_size = Vector2(panel_width, 290)
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", 24 if panel_width < 380.0 else 34)

func _on_new_game_pressed():
	if SaveManager.has_save_file():
		overwrite_dialog.popup_centered(Vector2i(480, 210))
	else:
		_begin_new_game()

func _begin_new_game(change_scene := true):
	if not GameSession.request_new_game():
		_show_error("No se pudo preparar una partida nueva.")
		return
	if change_scene:
		var error := get_tree().change_scene_to_file(GAME_SCENE)
		if error != OK:
			_show_error("No se pudo abrir la escena del juego (error %d)." % error)

func _on_load_game_pressed():
	_begin_load_game()

func _begin_load_game(change_scene := true):
	if not GameSession.request_load_game():
		load_game_button.disabled = true
		_show_error("La partida guardada no existe o esta danada.")
		return
	if change_scene:
		var error := get_tree().change_scene_to_file(GAME_SCENE)
		if error != OK:
			_show_error("No se pudo abrir la escena del juego (error %d)." % error)

func _show_settings():
	menu_panel.hide()
	settings_panel.show()
	for child in settings_panel.get_child(0).get_children():
		if child is Button:
			child.grab_focus()
			break

func _hide_settings(_button = null):
	settings_panel.hide()
	menu_panel.show()
	settings_button.grab_focus()

func _show_error(message: String):
	error_dialog.dialog_text = message
	error_dialog.popup_centered(Vector2i(520, 190))

func _exit_game():
	get_tree().quit()
