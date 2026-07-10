extends Node

signal character_created
signal stats_changed
signal souls_changed
signal health_changed
signal stamina_changed
signal player_died(position)
signal bonfire_discovered(bonfire_id)
signal bloodstain_changed

const ATTRIBUTES = [
	"vitality",
	"attunement",
	"endurance",
	"strength",
	"dexterity",
	"resistance",
	"intelligence",
	"faith"
]

const ATTRIBUTE_LABELS = {
	"vitality": "Vitality",
	"attunement": "Attunement",
	"endurance": "Endurance",
	"strength": "Strength",
	"dexterity": "Dexterity",
	"resistance": "Resistance",
	"intelligence": "Intelligence",
	"faith": "Faith"
}

const SCALING_MULTIPLIERS = {
	"S": 2.4,
	"A": 1.9,
	"B": 1.45,
	"C": 1.05,
	"D": 0.65,
	"E": 0.35
}

var character_ready = false
var class_id = ""
var level = 1
var souls = 0
var lost_souls = 0
var bloodstain_position = Vector3.ZERO
var has_bloodstain = false
var current_bonfire_id = "ash_camp"
var current_bonfire_position = Vector3.ZERO
var discovered_bonfires = {}
var attributes = {}
var max_health = 300
var health = 300
var max_stamina = 100
var stamina = 100

func _ready():
	_setup_input_actions()
	Inventory.equipment_changed.connect(_on_equipment_changed)

func _on_equipment_changed():
	if not character_ready:
		return
	_recalculate_derived_stats()
	emit_signal("stats_changed")
	emit_signal("health_changed")
	emit_signal("stamina_changed")

func _setup_input_actions():
	_ensure_key_action("move_forward", KEY_W)
	_ensure_key_action("move_back", KEY_S)
	_ensure_key_action("move_left", KEY_A)
	_ensure_key_action("move_right", KEY_D)
	_ensure_key_action("run", KEY_SHIFT)
	_ensure_key_action("roll", KEY_SPACE)
	_ensure_key_action("interact", KEY_E)
	_ensure_key_action("inventory", KEY_I)
	_ensure_key_action("lock_on", KEY_Q)
	_ensure_key_action("use_item", KEY_R)
	_ensure_key_action("heavy_attack", KEY_F)
	_ensure_mouse_action("light_attack", MOUSE_BUTTON_LEFT)

func _ensure_key_action(action_name, keycode):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event = InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey and existing.physical_keycode == keycode:
			return
	InputMap.action_add_event(action_name, event)

func _ensure_mouse_action(action_name, button_index):
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event = InputEventMouseButton.new()
	event.button_index = button_index
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventMouseButton and existing.button_index == button_index:
			return
	InputMap.action_add_event(action_name, event)

func create_character(new_class_id):
	var class_data = Database.get_character_class(new_class_id)
	if class_data == null:
		return false
	class_id = new_class_id
	level = class_data.level
	souls = 0
	lost_souls = 0
	has_bloodstain = false
	discovered_bonfires.clear()
	attributes = class_data.attributes.duplicate(true)
	Inventory.reset_to_class(class_data)
	var bonfire = Database.get_bonfire("ash_camp")
	if bonfire != null:
		current_bonfire_id = bonfire.bonfire_id
		current_bonfire_position = bonfire.position
		discovered_bonfires[bonfire.bonfire_id] = true
	_recalculate_derived_stats()
	health = max_health
	stamina = max_stamina
	character_ready = true
	emit_signal("character_created")
	_emit_all_stat_signals()
	return true

func _recalculate_derived_stats():
	max_health = 260 + get_attribute("vitality") * 28
	max_stamina = 70 + get_attribute("endurance") * 9
	health = min(health, max_health)
	stamina = min(stamina, max_stamina)

func _emit_all_stat_signals():
	emit_signal("stats_changed")
	emit_signal("souls_changed")
	emit_signal("health_changed")
	emit_signal("stamina_changed")

func get_attribute(attribute_name):
	return int(attributes.get(attribute_name, 1)) + Inventory.get_bonus_attribute(attribute_name)

func get_level_cost():
	return 400 + level * 120

func can_level_up(attribute_name):
	return ATTRIBUTES.has(attribute_name) and souls >= get_level_cost()

func level_up(attribute_name):
	if not can_level_up(attribute_name):
		return false
	var cost = get_level_cost()
	souls -= cost
	level += 1
	attributes[attribute_name] = int(attributes.get(attribute_name, 1)) + 1
	_recalculate_derived_stats()
	health = max_health
	stamina = max_stamina
	_emit_all_stat_signals()
	return true

func add_souls(amount):
	souls += max(0, int(amount))
	emit_signal("souls_changed")

func spend_stamina(amount):
	if stamina < amount:
		return false
	stamina -= amount
	emit_signal("stamina_changed")
	return true

func regen_stamina(amount):
	stamina = min(max_stamina, stamina + amount)
	emit_signal("stamina_changed")

func heal(amount):
	health = min(max_health, health + amount)
	emit_signal("health_changed")

func take_damage(raw_damage):
	var reduction = get_damage_reduction()
	var final_damage = max(1, int(raw_damage) - reduction)
	health = max(0, health - final_damage)
	emit_signal("health_changed")
	return final_damage

func get_damage_reduction():
	return int(get_attribute("resistance") * 0.6) + Inventory.get_total_defense()

func restore_at_bonfire():
	_recalculate_derived_stats()
	health = max_health
	stamina = max_stamina
	_emit_all_stat_signals()

func die(position):
	if souls > 0:
		lost_souls = souls
		bloodstain_position = position
		has_bloodstain = true
	else:
		lost_souls = 0
		has_bloodstain = false
	souls = 0
	health = 0
	emit_signal("souls_changed")
	emit_signal("health_changed")
	emit_signal("bloodstain_changed")
	emit_signal("player_died", position)

func respawn_at_bonfire():
	restore_at_bonfire()
	return current_bonfire_position

func recover_lost_souls():
	if not has_bloodstain:
		return false
	souls += lost_souls
	lost_souls = 0
	has_bloodstain = false
	emit_signal("souls_changed")
	emit_signal("bloodstain_changed")
	return true

func discover_bonfire(bonfire_id, position):
	var was_new = not discovered_bonfires.has(bonfire_id)
	discovered_bonfires[bonfire_id] = true
	current_bonfire_id = bonfire_id
	current_bonfire_position = position
	if was_new:
		emit_signal("bonfire_discovered", bonfire_id)

func travel_to_bonfire(bonfire_id):
	if not discovered_bonfires.has(bonfire_id):
		return false
	var bonfire = Database.get_bonfire(bonfire_id)
	if bonfire == null:
		return false
	current_bonfire_id = bonfire_id
	current_bonfire_position = bonfire.position
	restore_at_bonfire()
	return true

func calculate_weapon_damage(weapon, attack_type = "light"):
	if weapon == null:
		return 10
	var damage = float(weapon.base_damage)
	for attribute_name in weapon.scaling.keys():
		var grade = weapon.scaling[attribute_name]
		damage += get_attribute(attribute_name) * float(SCALING_MULTIPLIERS.get(grade, 0.0))
	if attack_type == "heavy":
		damage *= 1.35
	if not meets_weapon_requirements(weapon):
		damage *= 0.35
	return int(round(damage))

func meets_weapon_requirements(weapon):
	if weapon == null:
		return true
	for attribute_name in weapon.requirements.keys():
		if get_attribute(attribute_name) < int(weapon.requirements[attribute_name]):
			return false
	return true
