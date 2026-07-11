extends Area3D

@export var chest_id := "chest"
@export_enum("random", "all") var loot_mode := "random"
@export var loot_items: Dictionary = {}

var is_open := false
var lid_pivot: Node3D = null

func _ready():
	add_to_group("interactable")
	add_to_group("chests")
	_setup_visuals()

func interact(_player):
	if is_open:
		return
	is_open = true
	_open_lid()
	if not loot_items.is_empty():
		_grant_defined_items()
	elif loot_mode == "all":
		_grant_all_items()
	else:
		_grant_random_item()

func _grant_defined_items():
	var granted := []
	for item_id in loot_items.keys():
		var amount: int = max(1, int(loot_items[item_id]))
		if Database.get_item(item_id) == null:
			push_warning("Unknown chest item: %s" % item_id)
			continue
		Inventory.add_item(item_id, amount)
		var item: Resource = Database.get_item(item_id)
		granted.append("%s x%d" % [item.display_name, amount])
	get_tree().call_group("ui", "notify", "Cofre abierto: %s." % ", ".join(granted))

func _grant_random_item():
	var item_ids = Database.list_all_item_ids()
	if item_ids.is_empty():
		return
	var item_id = item_ids.pick_random()
	Inventory.add_item(item_id, 1)
	var item: Resource = Database.get_item(item_id)
	get_tree().call_group("ui", "notify", "Cofre abierto: %s." % (item.display_name if item != null else item_id))

func _grant_all_items():
	var item_ids = Database.list_all_item_ids()
	for item_id in item_ids:
		Inventory.add_item(item_id, 1)
	get_tree().call_group("ui", "notify", "Cofre del tesoro: obtuviste uno de cada item.")

func _open_lid():
	if lid_pivot == null:
		return
	var tween = create_tween()
	tween.tween_property(lid_pivot, "rotation_degrees:x", 105.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _setup_visuals():
	var interaction_collision = CollisionShape3D.new()
	var interaction_shape = BoxShape3D.new()
	interaction_shape.size = Vector3(1.9, 1.35, 1.25)
	interaction_collision.shape = interaction_shape
	interaction_collision.position.y = 0.65
	add_child(interaction_collision)
	var solid_body = StaticBody3D.new()
	solid_body.name = "ChestCollision"
	add_child(solid_body)
	var solid_collision = CollisionShape3D.new()
	var solid_shape = BoxShape3D.new()
	solid_shape.size = Vector3(1.82,0.82,1.02)
	solid_collision.shape = solid_shape
	solid_collision.position.y = 0.42
	solid_body.add_child(solid_collision)

	var body = Node3D.new()
	body.name = "ChestBody"
	add_child(body)

	var base = VisualLibrary.tapered(Vector2(0.82,0.45),Vector2(0.92,0.53),0.68,VisualLibrary.material("wood"),"WoodenChest")
	VisualLibrary.add_part(body,base,Vector3(0,0.40,0))
	for x in [-0.86, 0.0, 0.86]:
		var vertical_band = VisualLibrary.box(Vector3(0.10,0.72,1.02),VisualLibrary.material("dark_metal"),"IronBand")
		VisualLibrary.add_part(body,vertical_band,Vector3(x,0.42,0))
	for z in [-0.50, 0.50]:
		var rim = VisualLibrary.box(Vector3(1.90,0.10,0.10),VisualLibrary.material("dark_metal"),"IronRim")
		VisualLibrary.add_part(body,rim,Vector3(0,0.71,z))
	var foot = VisualLibrary.box(Vector3(1.95,0.12,1.12),VisualLibrary.material("dark_metal"),"ChestFoot")
	VisualLibrary.add_part(body,foot,Vector3(0,0.08,0))

	lid_pivot = Node3D.new()
	lid_pivot.name = "LidPivot"
	lid_pivot.position = Vector3(0,0.74,0.50)
	add_child(lid_pivot)
	var lid_center = VisualLibrary.box(Vector3(1.82,0.20,0.96),VisualLibrary.material("wood"),"CurvedLidCenter")
	VisualLibrary.add_part(lid_pivot,lid_center,Vector3(0,0.08,-0.48))
	for z_offset in [-0.82, -0.48, -0.14]:
		var lid_slat = VisualLibrary.box(Vector3(1.86,0.16,0.34),VisualLibrary.material("wood"),"LidSlat")
		var arc = 16.0 - abs(z_offset + 0.48) * 24.0
		VisualLibrary.add_part(lid_pivot,lid_slat,Vector3(0,0.18 + cos((z_offset + 0.48) * 3.0) * 0.08,z_offset),Vector3(arc,0,0))
	for x in [-0.86, 0.86]:
		var lid_band = VisualLibrary.box(Vector3(0.10,0.31,1.04),VisualLibrary.material("dark_metal"),"LidBand")
		VisualLibrary.add_part(lid_pivot,lid_band,Vector3(x,0.15,-0.48))

	var lock_plate = VisualLibrary.box(Vector3(0.28,0.34,0.08),VisualLibrary.material("metal"),"LockPlate")
	VisualLibrary.add_part(lid_pivot,lock_plate,Vector3(0,-0.02,-0.99))
	var keyhole = VisualLibrary.box(Vector3(0.06,0.12,0.025),VisualLibrary.material("dark_metal"),"Keyhole")
	VisualLibrary.add_part(lid_pivot,keyhole,Vector3(0,-0.02,-1.04))

	for link_index in range(5):
		var link = VisualLibrary.cylinder(0.055,0.28,VisualLibrary.material("dark_metal"),6,"ChainLink")
		VisualLibrary.add_part(body,link,Vector3(1.02 + link_index * 0.18,0.25 - link_index * 0.035,0.38),Vector3(0,0,70 if link_index % 2 == 0 else 20))
