extends Node

signal character_created
signal stats_changed
signal souls_changed
signal health_changed
signal stamina_changed
signal player_died(position)
signal bonfire_discovered(bonfire_id)
signal bloodstain_changed
signal church_completed_changed

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
var church_completed := false

func reset_runtime_state():
	character_ready = false
	class_id = ""
	level = 1
	souls = 0
	lost_souls = 0
	bloodstain_position = Vector3.ZERO
	has_bloodstain = false
	current_bonfire_id = "ash_camp"
	current_bonfire_position = Vector3.ZERO
	discovered_bonfires.clear()
	attributes.clear()
	max_health = 300
	health = 300
	max_stamina = 100
	stamina = 100
	church_completed = false
	_emit_all_stat_signals()
	emit_signal("bloodstain_changed")
	emit_signal("church_completed_changed")

func get_save_data() -> Dictionary:
	var effective_attributes := {}
	for attribute_name in ATTRIBUTES:
		effective_attributes[attribute_name] = get_attribute(attribute_name)
	return {
		"class_id": class_id,
		"level": level,
		"souls": souls,
		"souls_to_next_level": get_level_cost(),
		"health": health,
		"max_health": max_health,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"attributes": attributes.duplicate(true),
		"effective_attributes": effective_attributes,
		"lost_souls": lost_souls,
		"has_bloodstain": has_bloodstain,
		"bloodstain_position": [bloodstain_position.x, bloodstain_position.y, bloodstain_position.z]
	}

func get_world_save_data() -> Dictionary:
	var bonfire_ids: Array = discovered_bonfires.keys()
	bonfire_ids.sort()
	return {
		"discovered_bonfires": bonfire_ids,
		"last_bonfire_id": current_bonfire_id,
		"church_completed": church_completed
	}

func apply_save_data(player_data, world_data) -> bool:
	if not player_data is Dictionary or not world_data is Dictionary:
		push_error("GameState: los datos de jugador o mundo son invalidos.")
		return false
	var saved_class_id: String = player_data.get("class_id", class_id) if player_data.get("class_id", class_id) is String else class_id
	if Database.get_character_class(saved_class_id) != null:
		class_id = saved_class_id
	level = max(1, _safe_int(player_data.get("level", level), level))
	souls = max(0, _safe_int(player_data.get("souls", souls), souls))
	if player_data.has("attributes") and player_data["attributes"] is Dictionary:
		for attribute_name in ATTRIBUTES:
			if player_data["attributes"].has(attribute_name):
				attributes[attribute_name] = max(1, _safe_int(player_data["attributes"][attribute_name], int(attributes.get(attribute_name, 1))))
	_recalculate_derived_stats()
	max_health = max(1, _safe_int(player_data.get("max_health", max_health), max_health))
	max_stamina = max(1, _safe_int(player_data.get("max_stamina", max_stamina), max_stamina))
	health = clamp(_safe_int(player_data.get("health", max_health), max_health), 0, max_health)
	stamina = clamp(_safe_float(player_data.get("stamina", max_stamina), float(max_stamina)), 0.0, float(max_stamina))
	lost_souls = max(0, _safe_int(player_data.get("lost_souls", 0), 0))
	has_bloodstain = _safe_bool(player_data.get("has_bloodstain", false), false) and lost_souls > 0
	bloodstain_position = _vector3_from_save(player_data.get("bloodstain_position", []), Vector3.ZERO)
	discovered_bonfires.clear()
	var saved_bonfires = world_data.get("discovered_bonfires", [])
	if saved_bonfires is Array:
		for saved_id in saved_bonfires:
			if not saved_id is String:
				continue
			var bonfire_id: String = saved_id
			if Database.get_bonfire(bonfire_id) != null:
				discovered_bonfires[bonfire_id] = true
	var requested_bonfire_id: String = world_data.get("last_bonfire_id", "ash_camp") if world_data.get("last_bonfire_id", "ash_camp") is String else "ash_camp"
	var bonfire = Database.get_bonfire(requested_bonfire_id)
	if bonfire == null:
		push_warning("GameState: el bonfire guardado '%s' no existe; se usa ash_camp." % requested_bonfire_id)
		requested_bonfire_id = "ash_camp"
		bonfire = Database.get_bonfire(requested_bonfire_id)
	if bonfire != null:
		current_bonfire_id = bonfire.bonfire_id
		current_bonfire_position = bonfire.position
		discovered_bonfires[bonfire.bonfire_id] = true
	church_completed = _safe_bool(world_data.get("church_completed", church_completed), church_completed)
	character_ready = true
	_emit_all_stat_signals()
	emit_signal("bloodstain_changed")
	emit_signal("church_completed_changed")
	return true

func _vector3_from_save(value, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3 and _is_number(value[0]) and _is_number(value[1]) and _is_number(value[2]):
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback

func _is_number(value) -> bool:
	return value is int or value is float

func _safe_int(value, fallback: int) -> int:
	return int(value) if _is_number(value) else fallback

func _safe_float(value, fallback: float) -> float:
	return float(value) if _is_number(value) else fallback

func _safe_bool(value, fallback: bool) -> bool:
	return value if value is bool else fallback

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
	church_completed = false
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

func complete_church() -> bool:
	if church_completed:
		return false
	church_completed = true
	emit_signal("church_completed_changed")
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

func get_level_preview(attribute_name: String) -> Dictionary:
	var weapon = Inventory.get_equipped_weapon()
	var attribute_bonus = 1 if ATTRIBUTES.has(attribute_name) else 0
	var current_values = {
		"level": level,
		"souls": souls,
		"health": max_health,
		"stamina": max_stamina,
		"defense": get_damage_reduction(),
		"light_damage": calculate_weapon_damage(weapon, "light"),
		"heavy_damage": calculate_weapon_damage(weapon, "heavy")
	}
	var next_resistance = get_attribute("resistance") + (attribute_bonus if attribute_name == "resistance" else 0)
	var next_values = {
		"level": level + attribute_bonus,
		"souls": max(0, souls - get_level_cost()),
		"health": 260 + (get_attribute("vitality") + (attribute_bonus if attribute_name == "vitality" else 0)) * 28,
		"stamina": 70 + (get_attribute("endurance") + (attribute_bonus if attribute_name == "endurance" else 0)) * 9,
		"defense": int(next_resistance * 0.6) + Inventory.get_total_defense(),
		"light_damage": calculate_weapon_damage_preview(weapon, "light", attribute_name),
		"heavy_damage": calculate_weapon_damage_preview(weapon, "heavy", attribute_name)
	}
	return {"cost": get_level_cost(), "current": current_values, "next": next_values}

func calculate_weapon_damage_preview(weapon, attack_type: String, boosted_attribute: String) -> int:
	if weapon == null:
		return 10
	var damage = float(weapon.base_damage)
	for attribute_name in weapon.scaling.keys():
		var value = get_attribute(attribute_name) + (1 if attribute_name == boosted_attribute else 0)
		damage += value * float(SCALING_MULTIPLIERS.get(weapon.scaling[attribute_name], 0.0))
	if attack_type == "heavy":
		damage *= 1.70
	var meets_requirements = true
	for attribute_name in weapon.requirements.keys():
		var value = get_attribute(attribute_name) + (1 if attribute_name == boosted_attribute else 0)
		if value < int(weapon.requirements[attribute_name]):
			meets_requirements = false
			break
	if not meets_requirements:
		damage *= 0.35
	return int(round(damage))

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

func discover_bonfire(bonfire_id, position, make_current := true):
	var was_new = not discovered_bonfires.has(bonfire_id)
	discovered_bonfires[bonfire_id] = true
	if make_current:
		current_bonfire_id = bonfire_id
		current_bonfire_position = position
	if was_new:
		emit_signal("bonfire_discovered", bonfire_id)

func rest_at_bonfire(bonfire_id: String, position: Vector3) -> bool:
	if Database.get_bonfire(bonfire_id) == null:
		push_error("GameState: no se puede descansar en el bonfire desconocido '%s'." % bonfire_id)
		return false
	discover_bonfire(bonfire_id, position, true)
	restore_at_bonfire()
	return true

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
		damage *= 1.70
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
