extends Node3D
class_name EnemyModel

var body_root: Node3D
var weapon_root: Node3D
var time := 0.0
var moving := false
var lock_marker: MeshInstance3D

func build(archetype: String):
	body_root = Node3D.new()
	body_root.name = "ReplaceableModel"
	add_child(body_root)
	match archetype:
		"brute": _build_guard()
		"lancer": _build_lancer()
		"hound": _build_hound()
		_: _build_hollow()
	lock_marker = VisualLibrary.tapered(Vector2(0.0,0.02),Vector2(0.09,0.035),0.26,VisualLibrary.material("fire"),"LockMarker")
	VisualLibrary.add_part(self,lock_marker,Vector3(0,2.42,0),Vector3(0,0,180))
	lock_marker.visible = false

func _process(delta):
	time += delta
	if body_root != null:
		body_root.position.y = sin(time * (7.0 if moving else 2.0)) * (0.035 if moving else 0.012)

func set_moving(value: bool):
	moving = value

func flash_hit():
	if body_root == null: return
	var tween = create_tween()
	body_root.scale = Vector3.ONE * 1.06
	tween.tween_property(body_root, "scale", Vector3.ONE, 0.14)

func set_targeted(value: bool):
	if lock_marker != null:
		lock_marker.visible = value

func play_death():
	set_process(false)
	var tween = create_tween().set_parallel()
	tween.tween_property(body_root,"rotation_degrees",Vector3(78,0,24),0.42).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(body_root,"position:y",0.14,0.42).set_trans(Tween.TRANS_QUAD)

func _limb(parent: Node, name: String, pos: Vector3, length: float, width: float, mat: Material, angle := Vector3.ZERO):
	var part = VisualLibrary.tapered(Vector2(width * 0.78, width * 0.78), Vector2(width, width), length, mat, name)
	VisualLibrary.add_part(parent, part, pos, angle)

func _build_humanoid(scale_factor: float, armor: bool, cloth: Material):
	var skin = VisualLibrary.material("skin")
	var metal = VisualLibrary.material("dark_metal")
	var torso = VisualLibrary.tapered(Vector2(0.29, 0.17), Vector2(0.21, 0.14), 0.62, metal if armor else cloth, "Torso")
	VisualLibrary.add_part(body_root, torso, Vector3(0, 1.33, 0))
	var head = VisualLibrary.tapered(Vector2(0.15, 0.14), Vector2(0.12, 0.12), 0.30, metal if armor else skin, "Head")
	VisualLibrary.add_part(body_root, head, Vector3(0, 1.88, -0.01))
	_limb(body_root, "ArmL", Vector3(-0.35, 1.26, 0), 0.72, 0.13, cloth, Vector3(0, 0, -6))
	_limb(body_root, "ArmR", Vector3(0.35, 1.26, 0), 0.72, 0.13, cloth, Vector3(0, 0, 6))
	_limb(body_root, "LegL", Vector3(-0.15, 0.54, 0), 0.92, 0.16, VisualLibrary.material("leather"), Vector3(2,0,-2))
	_limb(body_root, "LegR", Vector3(0.15, 0.54, 0), 0.92, 0.16, VisualLibrary.material("leather"), Vector3(2,0,2))
	var belt = VisualLibrary.box(Vector3(0.52,0.09,0.32),VisualLibrary.material("dark_leather"),"EnemyBelt")
	VisualLibrary.add_part(body_root,belt,Vector3(0,1.01,0))
	body_root.scale = Vector3.ONE * scale_factor
	weapon_root = Node3D.new()
	weapon_root.name = "WeaponMount"
	weapon_root.position = Vector3(0.43, 1.04, -0.08)
	body_root.add_child(weapon_root)

func _build_hollow():
	_build_humanoid(0.96, false, VisualLibrary.material("cloth_red"))
	var hood = VisualLibrary.tapered(Vector2(0.22,0.20), Vector2(0.16,0.15), 0.38, VisualLibrary.material("cloth"), "TornHood")
	VisualLibrary.add_part(body_root, hood, Vector3(0,1.88,0.04))
	_build_sword()

func _build_guard():
	_build_humanoid(1.18, true, VisualLibrary.material("cloth_red"))
	for x in [-0.39, 0.39]:
		var shoulder = VisualLibrary.tapered(Vector2(0.18,0.22), Vector2(0.24,0.25), 0.18, VisualLibrary.material("dark_metal"), "Pauldron")
		VisualLibrary.add_part(body_root, shoulder, Vector3(x,1.57,0), Vector3(0,0,8 * sign(x)))
	var axe = VisualLibrary.cylinder(0.04, 1.25, VisualLibrary.material("wood"), 7, "AxeHandle")
	VisualLibrary.add_part(weapon_root, axe, Vector3(0,-0.42,0))
	var blade = VisualLibrary.tapered(Vector2(0.08,0.04), Vector2(0.28,0.05), 0.42, VisualLibrary.material("metal"), "AxeBlade")
	VisualLibrary.add_part(weapon_root, blade, Vector3(-0.22,-1.03,0), Vector3(0,0,90))

func _build_lancer():
	_build_humanoid(1.04, true, VisualLibrary.material("cloth_blue"))
	var crest = VisualLibrary.tapered(Vector2(0.03,0.04), Vector2(0.19,0.05), 0.42, VisualLibrary.material("cloth_blue"), "HelmetCrest")
	VisualLibrary.add_part(body_root, crest, Vector3(0,2.18,0))
	var shaft = VisualLibrary.cylinder(0.028, 2.35, VisualLibrary.material("wood"), 7, "SpearShaft")
	VisualLibrary.add_part(weapon_root, shaft, Vector3(0,-0.2,-0.7), Vector3(90,0,0))
	var tip = VisualLibrary.tapered(Vector2(0,0), Vector2(0.10,0.035), 0.40, VisualLibrary.material("metal"), "SpearTip")
	VisualLibrary.add_part(weapon_root, tip, Vector3(0,-0.2,-2.05), Vector3(90,0,0))

func _build_hound():
	var bone = VisualLibrary.material("bone")
	var dark = VisualLibrary.material("stone_dark")
	var torso = VisualLibrary.tapered(Vector2(0.24,0.22), Vector2(0.38,0.28), 0.92, dark, "HoundTorso")
	VisualLibrary.add_part(body_root, torso, Vector3(0,0.72,0), Vector3(90,0,0))
	var skull = VisualLibrary.tapered(Vector2(0.20,0.16), Vector2(0.12,0.10), 0.42, bone, "Skull")
	VisualLibrary.add_part(body_root, skull, Vector3(0,0.78,-0.65), Vector3(90,0,0))
	for x in [-0.25,0.25]:
		for z in [-0.24,0.25]:
			_limb(body_root, "CorruptedLeg", Vector3(x,0.30,z), 0.55, 0.08, dark, Vector3(8,0,0))
	for x in [-0.12,0.12]:
		var horn = VisualLibrary.tapered(Vector2(0,0), Vector2(0.055,0.055), 0.38, bone, "Horn")
		VisualLibrary.add_part(body_root, horn, Vector3(x,1.02,-0.68), Vector3(-25,0,18 * sign(x)))

func _build_sword():
	var grip = VisualLibrary.cylinder(0.03, 0.27, VisualLibrary.material("leather"), 7, "Grip")
	VisualLibrary.add_part(weapon_root, grip, Vector3(0,-0.12,0))
	var guard = VisualLibrary.box(Vector3(0.38,0.055,0.07), VisualLibrary.material("dark_metal"), "Guard")
	VisualLibrary.add_part(weapon_root, guard, Vector3(0,-0.28,0))
	var blade = VisualLibrary.tapered(Vector2(0.0,0.018), Vector2(0.065,0.025), 1.0, VisualLibrary.material("metal"), "Blade")
	VisualLibrary.add_part(weapon_root, blade, Vector3(0,-0.80,0))
