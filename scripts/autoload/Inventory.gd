extends Node

signal inventory_changed
signal equipment_changed

const EQUIPMENT_TYPES := {
	"right_weapon": "weapon",
	"armor": "armor",
	"ring_1": "ring",
	"ring_2": "ring",
	"consumable": "consumable"
}

var item_instances: Dictionary = {}
var item_counts: Dictionary = {}
var equipment: Dictionary = {
	"right_weapon": "",
	"armor": "",
	"ring_1": "",
	"ring_2": "",
	"consumable": ""
}
var next_instance_serial := 1

func clear_all():
	item_instances.clear()
	item_counts.clear()
	next_instance_serial = 1
	for slot in equipment:
		equipment[slot] = ""
	equipment_changed.emit()
	inventory_changed.emit()

func get_save_data() -> Dictionary:
	var saved_instances: Array = []
	var instance_ids := item_instances.keys()
	instance_ids.sort()
	for instance_id in instance_ids:
		saved_instances.append(item_instances[instance_id].duplicate(true))
	return {
		"instances": saved_instances,
		"equipment": equipment.duplicate(true),
		"next_instance_serial": next_instance_serial
	}

func apply_save_data(data) -> bool:
	if not data is Dictionary:
		push_error("Inventory: los datos de guardado no son un diccionario.")
		return false
	item_instances.clear()
	item_counts.clear()
	for slot in equipment:
		equipment[slot] = ""
	next_instance_serial = 1
	if data.has("instances") and data["instances"] is Array:
		_load_instances(data["instances"])
	elif data.has("item_counts") and data["item_counts"] is Dictionary:
		_migrate_legacy_counts(data["item_counts"])
	if data.has("next_instance_serial") and (data["next_instance_serial"] is int or data["next_instance_serial"] is float):
		next_instance_serial = max(next_instance_serial, int(data["next_instance_serial"]))
	if data.has("equipment") and data["equipment"] is Dictionary:
		_load_equipment(data["equipment"])
	_rebuild_item_counts()
	equipment_changed.emit()
	inventory_changed.emit()
	return true

func _load_instances(saved_instances: Array):
	for value in saved_instances:
		if not value is Dictionary:
			continue
		var instance_id := str(value.get("instance_id", ""))
		var item_id := str(value.get("item_id", ""))
		if instance_id == "" or item_instances.has(instance_id) or Database.get_item(item_id) == null:
			continue
		item_instances[instance_id] = {"instance_id": instance_id, "item_id": item_id}
		_update_serial_from_id(instance_id)

func _migrate_legacy_counts(saved_counts: Dictionary):
	var item_ids := saved_counts.keys()
	item_ids.sort()
	for raw_item_id in item_ids:
		var item_id := str(raw_item_id)
		var raw_amount = saved_counts[raw_item_id]
		if Database.get_item(item_id) == null or (not raw_amount is int and not raw_amount is float):
			continue
		for _index in range(max(0, int(raw_amount))):
			_create_instance(item_id)

func _load_equipment(saved_equipment: Dictionary):
	var used_instances: Dictionary = {}
	for slot in equipment:
		if not saved_equipment.has(slot) or not saved_equipment[slot] is String:
			continue
		var saved_value: String = saved_equipment[slot]
		var instance_id := saved_value if item_instances.has(saved_value) else _find_available_instance(saved_value, slot, used_instances)
		if _is_valid_equipment_for_slot(slot, instance_id) and not used_instances.has(instance_id):
			equipment[slot] = instance_id
			used_instances[instance_id] = true

func _find_available_instance(item_id: String, slot: String, used_instances: Dictionary) -> String:
	if Database.get_item_type(item_id) != EQUIPMENT_TYPES.get(slot, ""):
		return ""
	for instance_id in get_instances_by_item_id(item_id):
		if not used_instances.has(instance_id):
			return instance_id
	return ""

func _update_serial_from_id(instance_id: String):
	var separator := instance_id.rfind(":")
	if separator < 0:
		return
	var suffix := instance_id.substr(separator + 1)
	if suffix.is_valid_int():
		next_instance_serial = max(next_instance_serial, int(suffix) + 1)

func reset_to_class(class_data):
	clear_all()
	if class_data == null:
		return
	if class_data.starting_weapon != "":
		var weapon_instances := add_item(class_data.starting_weapon, 1)
		if not weapon_instances.is_empty():
			equipment["right_weapon"] = weapon_instances[0]
	if class_data.starting_armor != "":
		var armor_instances := add_item(class_data.starting_armor, 1)
		if not armor_instances.is_empty():
			equipment["armor"] = armor_instances[0]
	if class_data.starting_ring != "":
		var ring_instances := add_item(class_data.starting_ring, 1)
		if not ring_instances.is_empty():
			equipment["ring_1"] = ring_instances[0]
	for item_id in class_data.starting_items:
		var created := add_item(item_id, 1)
		if Database.get_item_type(item_id) == "consumable" and equipment["consumable"] == "" and not created.is_empty():
			equipment["consumable"] = created[0]
	equipment_changed.emit()
	inventory_changed.emit()

func add_item(item_id, amount = 1) -> Array:
	var created: Array = []
	if item_id == "" or Database.get_item(item_id) == null:
		return created
	for _index in range(max(0, int(amount))):
		created.append(_create_instance(str(item_id)))
	if not created.is_empty():
		_rebuild_item_counts()
		inventory_changed.emit()
	return created

func _create_instance(item_id: String) -> String:
	var instance_id := "%s:%08d" % [item_id, next_instance_serial]
	while item_instances.has(instance_id):
		next_instance_serial += 1
		instance_id = "%s:%08d" % [item_id, next_instance_serial]
	next_instance_serial += 1
	item_instances[instance_id] = {"instance_id": instance_id, "item_id": item_id}
	return instance_id

func remove_instance(instance_id: String) -> bool:
	if not item_instances.has(instance_id):
		return false
	item_instances.erase(instance_id)
	var equipment_changed_now := false
	for slot in equipment:
		if equipment[slot] == instance_id:
			equipment[slot] = ""
			equipment_changed_now = true
	_rebuild_item_counts()
	if equipment_changed_now:
		equipment_changed.emit()
	inventory_changed.emit()
	return true

func remove_item(item_id, amount = 1) -> bool:
	var instances := get_instances_by_item_id(str(item_id))
	if instances.is_empty():
		return false
	instances.sort_custom(func(a, b): return int(_is_instance_equipped(a)) < int(_is_instance_equipped(b)))
	for index in range(min(max(0, int(amount)), instances.size())):
		remove_instance(instances[index])
	return true

func has_item(item_id) -> bool:
	return get_item_count(str(item_id)) > 0

func has_instance(instance_id: String) -> bool:
	return item_instances.has(instance_id)

func get_item_count(item_id: String) -> int:
	return int(item_counts.get(item_id, 0))

func get_instance(instance_id: String):
	return item_instances.get(instance_id)

func get_instance_item_id(instance_id: String) -> String:
	var instance = item_instances.get(instance_id)
	return str(instance.get("item_id", "")) if instance is Dictionary else ""

func get_instance_item(instance_id: String):
	return Database.get_item(get_instance_item_id(instance_id))

func get_instances_by_item_id(item_id: String) -> Array:
	var result: Array = []
	for instance_id in item_instances:
		if get_instance_item_id(instance_id) == item_id:
			result.append(instance_id)
	result.sort()
	return result

func get_instances_by_type(item_type: String) -> Array:
	var result: Array = []
	for instance_id in item_instances:
		if Database.get_item_type(get_instance_item_id(instance_id)) == item_type:
			result.append(instance_id)
	result.sort()
	return result

func get_all_instances() -> Array:
	var result: Array = item_instances.keys()
	result.sort()
	return result

func equip_instance(slot: String, instance_id: String) -> bool:
	if not _is_valid_equipment_for_slot(slot, instance_id):
		return false
	var item = get_instance_item(instance_id)
	if EQUIPMENT_TYPES.get(slot, "") == "weapon" and not GameState.meets_weapon_requirements(item):
		return false
	for other_slot in equipment:
		if other_slot != slot and equipment[other_slot] == instance_id:
			equipment[other_slot] = ""
	equipment[slot] = instance_id
	equipment_changed.emit()
	return true

func equip_item(item_id, preferred_slot := "") -> bool:
	var instances := get_instances_by_item_id(str(item_id))
	if instances.is_empty():
		return false
	var item_type: String = str(Database.get_item_type(str(item_id)))
	var slot := str(preferred_slot)
	if slot == "":
		match item_type:
			"weapon": slot = "right_weapon"
			"armor": slot = "armor"
			"ring": slot = "ring_1" if equipment["ring_1"] == "" else "ring_2"
			"consumable": slot = "consumable"
			_: return false
	return equip_instance(slot, instances[0])

func use_consumable_instance(instance_id: String) -> bool:
	if not item_instances.has(instance_id):
		return false
	var item = Database.get_consumable(get_instance_item_id(instance_id))
	if item == null:
		return false
	match item.effect:
		"heal": GameState.heal(item.amount)
		"souls": GameState.add_souls(item.amount)
		_: return false
	return remove_instance(instance_id)

func use_consumable(item_id) -> bool:
	var instance_id: String = str(equipment["consumable"]) if get_instance_item_id(str(equipment["consumable"])) == item_id else ""
	if instance_id == "":
		var instances := get_instances_by_item_id(str(item_id))
		if instances.is_empty():
			return false
		instance_id = instances[0]
	return use_consumable_instance(instance_id)

func get_equipped_instance_id(slot: String) -> String:
	return str(equipment.get(slot, ""))

func get_equipped_item_id(slot: String) -> String:
	return get_instance_item_id(get_equipped_instance_id(slot))

func get_equipped_weapon():
	return Database.get_weapon(get_equipped_item_id("right_weapon"))

func get_equipped_armor():
	return Database.get_armor(get_equipped_item_id("armor"))

func get_equipped_rings() -> Array:
	var result: Array = []
	for slot in ["ring_1", "ring_2"]:
		var ring = Database.get_ring(get_equipped_item_id(slot))
		if ring != null:
			result.append(ring)
	return result

func get_total_defense() -> int:
	var defense := 0
	var armor = get_equipped_armor()
	if armor != null:
		defense += armor.defense
	for ring in get_equipped_rings():
		defense += ring.defense_bonus
	return defense

func get_total_poise() -> float:
	var armor = get_equipped_armor()
	return armor.poise if armor != null else 0.0

func get_bonus_attribute(attribute_name) -> int:
	var bonus := 0
	for ring in get_equipped_rings():
		if attribute_name == "vitality":
			bonus += ring.vitality_bonus
		elif attribute_name == "endurance":
			bonus += ring.endurance_bonus
	return bonus

func get_items_by_type(item_type) -> Array:
	var result: Array = []
	for item_id in item_counts:
		if Database.get_item_type(item_id) == item_type:
			result.append(item_id)
	result.sort()
	return result

func _is_valid_equipment_for_slot(slot: String, instance_id: String) -> bool:
	if instance_id == "":
		return false
	if not item_instances.has(instance_id):
		return false
	return Database.get_item_type(get_instance_item_id(instance_id)) == EQUIPMENT_TYPES.get(slot, "")

func _is_instance_equipped(instance_id: String) -> bool:
	return equipment.values().has(instance_id)

func _rebuild_item_counts():
	item_counts.clear()
	for instance_id in item_instances:
		var item_id := get_instance_item_id(instance_id)
		item_counts[item_id] = int(item_counts.get(item_id, 0)) + 1
