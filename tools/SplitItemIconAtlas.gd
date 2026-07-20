extends SceneTree

const SOURCE_PATH := "res://assets/ui/item_icons_atlas.png"
const OUTPUT_DIRECTORY := "res://assets/ui/items"
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

func _initialize():
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if source == null or source.is_empty():
		push_error("SplitItemIconAtlas: atlas invalido.")
		quit(1)
		return
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	if DirAccess.make_dir_recursive_absolute(output_path) != OK:
		push_error("SplitItemIconAtlas: no se pudo crear el directorio de salida.")
		quit(1)
		return
	var output_size := Vector2i(320, 320)
	for index in range(ICON_NAMES.size()):
		var column := index % 4
		var row := int(index / 4)
		var region := Rect2i(
			COLUMN_BOUNDARIES[column],
			ROW_BOUNDARIES[row],
			COLUMN_BOUNDARIES[column + 1] - COLUMN_BOUNDARIES[column],
			ROW_BOUNDARIES[row + 1] - ROW_BOUNDARIES[row]
		)
		var content_region := Rect2i(
			region.position + Vector2i(BORDER_CROP, BORDER_CROP),
			region.size - Vector2i(BORDER_CROP * 2, BORDER_CROP * 2)
		)
		var icon := Image.create(output_size.x, output_size.y, false, source.get_format())
		icon.fill(Color.BLACK)
		var offset := Vector2i((output_size.x - content_region.size.x) / 2, (output_size.y - content_region.size.y) / 2)
		icon.blit_rect(source, content_region, offset)
		var error := icon.save_png(output_path.path_join("%s.png" % ICON_NAMES[index]))
		if error != OK:
			push_error("SplitItemIconAtlas: no se pudo guardar %s." % ICON_NAMES[index])
			quit(1)
			return
	print("ITEM_ICONS_SPLIT_OK: %d iconos de %dx%d sin reescalado" % [ICON_NAMES.size(), output_size.x, output_size.y])
	quit(0)
