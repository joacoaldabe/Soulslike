extends RefCounted
class_name IconCatalog

const STAT_ATLAS_PATH := "res://assets/ui/stat_icons_atlas.png"

const STAT_GRID := Vector2i(4, 4)

const ITEM_ICON_PATHS := {
	"longsword": "res://assets/ui/items/longsword.png",
	"battle_axe": "res://assets/ui/items/battle_axe.png",
	"winged_spear": "res://assets/ui/items/winged_spear.png",
	"mace": "res://assets/ui/items/mace.png",
	"cloth_set": "res://assets/ui/items/cloth_set.png",
	"leather_set": "res://assets/ui/items/leather_set.png",
	"knight_set": "res://assets/ui/items/knight_set.png",
	"wanderer_set": "res://assets/ui/items/wanderer_set.png",
	"thief_set": "res://assets/ui/items/thief_set.png",
	"bandit_set": "res://assets/ui/items/bandit_set.png",
	"hunter_set": "res://assets/ui/items/hunter_set.png",
	"sorcerer_set": "res://assets/ui/items/sorcerer_set.png",
	"pyromancer_set": "res://assets/ui/items/pyromancer_set.png",
	"cleric_set": "res://assets/ui/items/cleric_set.png",
	"life_ring": "res://assets/ui/items/life_ring.png",
	"stamina_ring": "res://assets/ui/items/stamina_ring.png",
	"green_estus": "res://assets/ui/items/green_estus.png",
	"soul_shard": "res://assets/ui/items/soul_shard.png"
}
const FALLBACK_ITEM_ICON_PATH := "res://assets/ui/items/fallback_item.png"
const EMPTY_SLOT_ICON_PATH := "res://assets/ui/items/empty_slot.png"

const STAT_INDEX := {
	"class": 0,
	"level": 1,
	"souls": 2,
	"health": 3,
	"stamina": 4,
	"defense": 5,
	"poise": 5,
	"vitality": 6,
	"attunement": 7,
	"endurance": 8,
	"strength": 9,
	"dexterity": 10,
	"resistance": 11,
	"intelligence": 12,
	"faith": 13,
	"display": 14,
	"exit": 15
}

static var _stat_atlas: Texture2D
static var _cache: Dictionary = {}

static func get_item_icon(item_id: String) -> Texture2D:
	var path: String = str(ITEM_ICON_PATHS.get(item_id, FALLBACK_ITEM_ICON_PATH))
	return _file_icon(path)

static func get_empty_slot_icon() -> Texture2D:
	return _file_icon(EMPTY_SLOT_ICON_PATH)

static func get_stat_icon(stat_id: String) -> Texture2D:
	return _atlas_icon(_get_stat_atlas(), STAT_GRID, int(STAT_INDEX.get(stat_id, 14)), "stat:%s" % stat_id)

static func _get_stat_atlas() -> Texture2D:
	if _stat_atlas == null:
		_stat_atlas = load(STAT_ATLAS_PATH)
	return _stat_atlas

static func _file_icon(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var icon := load(path) as Texture2D
	_cache[path] = icon
	return icon

static func _atlas_icon(atlas: Texture2D, grid: Vector2i, index: int, cache_key: String) -> Texture2D:
	if _cache.has(cache_key):
		return _cache[cache_key]
	if atlas == null:
		return null
	var cell_size := Vector2i(atlas.get_width() / grid.x, atlas.get_height() / grid.y)
	var icon := AtlasTexture.new()
	icon.atlas = atlas
	icon.region = Rect2i((index % grid.x) * cell_size.x, (index / grid.x) * cell_size.y, cell_size.x, cell_size.y)
	_cache[cache_key] = icon
	return icon
