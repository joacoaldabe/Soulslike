extends Node

const CLASS_PATHS = [
	"res://data/classes/warrior.tres",
	"res://data/classes/knight.tres",
	"res://data/classes/wanderer.tres",
	"res://data/classes/thief.tres",
	"res://data/classes/bandit.tres",
	"res://data/classes/hunter.tres",
	"res://data/classes/sorcerer.tres",
	"res://data/classes/pyromancer.tres",
	"res://data/classes/cleric.tres",
	"res://data/classes/deprived.tres"
]

const WEAPON_PATHS = [
	"res://data/weapons/longsword.tres",
	"res://data/weapons/battle_axe.tres",
	"res://data/weapons/winged_spear.tres",
	"res://data/weapons/mace.tres"
]

const ARMOR_PATHS = [
	"res://data/armor/cloth_set.tres",
	"res://data/armor/leather_set.tres",
	"res://data/armor/knight_set.tres"
]

const RING_PATHS = [
	"res://data/rings/life_ring.tres",
	"res://data/rings/stamina_ring.tres"
]

const CONSUMABLE_PATHS = [
	"res://data/consumables/green_estus.tres",
	"res://data/consumables/soul_shard.tres"
]

const ENEMY_PATHS = [
	"res://data/enemies/hollow_sword.tres",
	"res://data/enemies/axe_brute.tres",
	"res://data/enemies/spear_guard.tres",
	"res://data/enemies/ash_hound.tres"
]

const BONFIRE_PATHS = [
	"res://data/bonfires/ash_camp.tres",
	"res://data/bonfires/ruined_gate.tres"
]

var classes = {}
var weapons = {}
var armors = {}
var rings = {}
var consumables = {}
var enemies = {}
var bonfires = {}

func _ready():
	_load_resources(CLASS_PATHS, classes, "class_id")
	_load_resources(WEAPON_PATHS, weapons, "item_id")
	_load_resources(ARMOR_PATHS, armors, "item_id")
	_load_resources(RING_PATHS, rings, "item_id")
	_load_resources(CONSUMABLE_PATHS, consumables, "item_id")
	_load_resources(ENEMY_PATHS, enemies, "enemy_id")
	_load_resources(BONFIRE_PATHS, bonfires, "bonfire_id")

func _load_resources(paths, target, id_property):
	for path in paths:
		var resource = load(path)
		if resource == null:
			push_warning("Missing data resource: %s" % path)
			continue
		var id_value = resource.get(id_property)
		if id_value != null and str(id_value) != "":
			target[id_value] = resource

func list_classes():
	return classes.values()

func list_weapons():
	return weapons.values()

func list_armors():
	return armors.values()

func list_rings():
	return rings.values()

func list_consumables():
	return consumables.values()

func list_enemies():
	return enemies.values()

func list_bonfires():
	return bonfires.values()

func get_character_class(class_id):
	return classes.get(class_id)

func get_weapon(item_id):
	return weapons.get(item_id)

func get_armor(item_id):
	return armors.get(item_id)

func get_ring(item_id):
	return rings.get(item_id)

func get_consumable(item_id):
	return consumables.get(item_id)

func get_enemy(enemy_id):
	return enemies.get(enemy_id)

func get_bonfire(bonfire_id):
	return bonfires.get(bonfire_id)

func get_item(item_id):
	if weapons.has(item_id):
		return weapons[item_id]
	if armors.has(item_id):
		return armors[item_id]
	if rings.has(item_id):
		return rings[item_id]
	if consumables.has(item_id):
		return consumables[item_id]
	return null

func get_item_type(item_id):
	if weapons.has(item_id):
		return "weapon"
	if armors.has(item_id):
		return "armor"
	if rings.has(item_id):
		return "ring"
	if consumables.has(item_id):
		return "consumable"
	return ""
