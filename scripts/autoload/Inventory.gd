extends Node

signal inventory_changed
signal equipment_changed

var item_counts = {}
var equipment = {
	"right_weapon": "",
	"armor": "",
	"ring_1": "",
	"ring_2": "",
	"consumable": ""
}

func reset_to_class(class_data):
	item_counts.clear()
	for key in equipment.keys():
		equipment[key] = ""
	if class_data == null:
		return
	if class_data.starting_weapon != "":
		add_item(class_data.starting_weapon, 1)
		equipment["right_weapon"] = class_data.starting_weapon
	if class_data.starting_armor != "":
		add_item(class_data.starting_armor, 1)
		equipment["armor"] = class_data.starting_armor
	if class_data.starting_ring != "":
		add_item(class_data.starting_ring, 1)
		equipment["ring_1"] = class_data.starting_ring
	for item_id in class_data.starting_items:
		add_item(item_id, 1)
		if Database.get_item_type(item_id) == "consumable" and equipment["consumable"] == "":
			equipment["consumable"] = item_id
	emit_signal("equipment_changed")
	emit_signal("inventory_changed")

func add_item(item_id, amount = 1):
	if item_id == "":
		return
	item_counts[item_id] = int(item_counts.get(item_id, 0)) + amount
	emit_signal("inventory_changed")

func remove_item(item_id, amount = 1):
	if not item_counts.has(item_id):
		return false
	item_counts[item_id] -= amount
	if item_counts[item_id] <= 0:
		item_counts.erase(item_id)
		for key in equipment.keys():
			if equipment[key] == item_id:
				equipment[key] = ""
		emit_signal("equipment_changed")
	emit_signal("inventory_changed")
	return true

func has_item(item_id):
	return int(item_counts.get(item_id, 0)) > 0

func equip_item(item_id):
	if not has_item(item_id):
		return false
	var item_type = Database.get_item_type(item_id)
	match item_type:
		"weapon":
			var weapon = Database.get_weapon(item_id)
			if not GameState.meets_weapon_requirements(weapon):
				return false
			equipment["right_weapon"] = item_id
		"armor":
			equipment["armor"] = item_id
		"ring":
			if equipment["ring_1"] == "" or equipment["ring_1"] == item_id:
				equipment["ring_1"] = item_id
			else:
				equipment["ring_2"] = item_id
		"consumable":
			equipment["consumable"] = item_id
		_:
			return false
	emit_signal("equipment_changed")
	return true

func use_consumable(item_id):
	if not has_item(item_id):
		return false
	var item = Database.get_consumable(item_id)
	if item == null:
		return false
	match item.effect:
		"heal":
			GameState.heal(item.amount)
		"souls":
			GameState.add_souls(item.amount)
		_:
			return false
	remove_item(item_id, 1)
	return true

func get_equipped_weapon():
	return Database.get_weapon(equipment["right_weapon"])

func get_equipped_armor():
	return Database.get_armor(equipment["armor"])

func get_equipped_rings():
	var result = []
	for key in ["ring_1", "ring_2"]:
		var ring = Database.get_ring(equipment[key])
		if ring != null:
			result.append(ring)
	return result

func get_total_defense():
	var defense = 0
	var armor = get_equipped_armor()
	if armor != null:
		defense += armor.defense
	for ring in get_equipped_rings():
		defense += ring.defense_bonus
	return defense

func get_bonus_attribute(attribute_name):
	var bonus = 0
	for ring in get_equipped_rings():
		if attribute_name == "vitality":
			bonus += ring.vitality_bonus
		elif attribute_name == "endurance":
			bonus += ring.endurance_bonus
	return bonus

func get_items_by_type(item_type):
	var result = []
	for item_id in item_counts.keys():
		if Database.get_item_type(item_id) == item_type:
			result.append(item_id)
	return result
