extends SceneTree

const SOURCE_PATH := "res://assets/ui/item_icons_atlas.png"
const COLUMN_BOUNDARIES := [4, 313, 625, 937, 1250]
const ROW_BOUNDARIES := [4, 292, 546, 803, 1027, 1250]
const BORDER_CROP := 14
const ICON_NAMES := [
	"longsword", "battle_axe", "winged_spear", "mace",
	"cloth_set", "leather_set", "knight_set", "wanderer_set",
	"thief_set", "bandit_set", "hunter_set", "sorcerer_set",
	"pyromancer_set", "cleric_set", "life_ring", "stamina_ring",
	"green_estus", "soul_shard", "fallback_item", "empty_slot"
]
const OUTPUT_SIZE := Vector2i(320, 320)

var failures: Array[String] = []

func _initialize():
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	_expect(source != null and not source.is_empty(), "source item atlas remains available")
	if source == null or source.is_empty():
		_finish()
		return
	for index in range(ICON_NAMES.size()):
		var icon_name: String = ICON_NAMES[index]
		var path := "res://assets/ui/items/%s.png" % icon_name
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		_expect(image != null and image.get_size() == OUTPUT_SIZE, "%s has the shared 320x320 resolution" % icon_name)
		if image == null or image.is_empty():
			continue
		var column := index % 4
		var row := int(index / 4)
		var source_region := Rect2i(
			COLUMN_BOUNDARIES[column],
			ROW_BOUNDARIES[row],
			COLUMN_BOUNDARIES[column + 1] - COLUMN_BOUNDARIES[column],
			ROW_BOUNDARIES[row + 1] - ROW_BOUNDARIES[row]
		)
		var content_region := Rect2i(
			source_region.position + Vector2i(BORDER_CROP, BORDER_CROP),
			source_region.size - Vector2i(BORDER_CROP * 2, BORDER_CROP * 2)
		)
		var offset := Vector2i((OUTPUT_SIZE.x - content_region.size.x) / 2, (OUTPUT_SIZE.y - content_region.size.y) / 2)
		var separated_pixels := image.get_region(Rect2i(offset, content_region.size)).get_data()
		var source_pixels := source.get_region(content_region).get_data()
		_expect(separated_pixels == source_pixels, "%s removes the atlas border and preserves item pixels without rescaling" % icon_name)
	var texture := IconCatalog.get_item_icon("knight_set")
	_expect(texture != null and not texture is AtlasTexture and texture.get_size() == Vector2(OUTPUT_SIZE), "inventory loads standalone item textures instead of atlas regions")
	_expect(IconCatalog.get_item_icon("future_item").resource_path == IconCatalog.FALLBACK_ITEM_ICON_PATH, "future items use the standalone fallback image")
	_finish()

func _expect(condition: bool, message: String):
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _finish():
	if failures.is_empty():
		print("ITEM_ICON_FILES_OK")
		quit(0)
	else:
		print("ITEM_ICON_FILES_FAILED: ", failures)
		quit(1)
