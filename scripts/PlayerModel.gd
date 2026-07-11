extends Node3D
class_name PlayerModel

const DEFAULT_ROLL_DURATION = 0.48
const VISUAL_FORWARD = Vector3.FORWARD

var rig_root = null
var hips = null
var spine = null
var chest = null
var neck = null
var head = null
var left_shoulder = null
var left_forearm = null
var left_hand = null
var right_shoulder = null
var right_forearm = null
var right_hand = null
var left_thigh = null
var left_shin = null
var left_foot = null
var right_thigh = null
var right_shin = null
var right_foot = null
var slots = {}
var materials = {}
var locomotion_amount = 0.0
var is_running = false
var is_rolling = false
var roll_timer = 0.0
var roll_duration = DEFAULT_ROLL_DURATION
var attack_active = false
var attack_kind = "light"
var attack_family = "sword"
var attack_timer = 0.0
var attack_duration = 0.1
var hit_timer = 0.0
var death_pose = false
var animation_time = 0.0
var action_kind := ""
var action_phase := "none"
var action_progress := 0.0
var roll_local_direction := Vector3.FORWARD
var hit_direction := Vector3.FORWARD
var hit_strength := 1.0
var pending_weapon = null
var has_pending_weapon = false
var pending_armor = null
var character_class_id := ""

func _ready():
	_build_materials()
	_build_rig()
	if has_pending_weapon:
		set_equipped_weapon(pending_weapon)
	else:
		set_equipped_weapon(null)

func _process(delta):
	animation_time += delta
	hit_timer = max(0.0, hit_timer - delta)
	_pose_model()

func set_locomotion(amount, running):
	locomotion_amount = clamp(amount, 0.0, 1.0)
	is_running = running

func set_roll_state(active, time_left, duration = DEFAULT_ROLL_DURATION):
	is_rolling = active
	roll_timer = max(0.0, time_left)
	roll_duration = max(0.01, duration)

func set_attack_state(active, kind, timer, duration):
	attack_active = active
	attack_kind = kind
	attack_timer = max(0.0, timer)
	attack_duration = max(0.01, duration)

func play_attack(kind, weapon_family, duration):
	attack_kind = kind
	attack_family = weapon_family
	attack_duration = max(0.01, duration)
	attack_timer = attack_duration
	attack_active = true

func play_hit(direction: Vector3 = Vector3.FORWARD, severity: String = "light"):
	hit_direction = direction
	hit_strength = 1.55 if severity == "stagger" or severity == "heavy" else 1.0
	hit_timer = 0.30 if hit_strength > 1.0 else 0.20

func play_death():
	death_pose = true
	action_kind = "dead"

func set_action_phase(kind: String, phase: String, progress: float):
	action_kind = kind
	action_phase = phase
	action_progress = clamp(progress, 0.0, 1.0)
	is_rolling = kind == "roll"
	attack_active = kind == "attack"

func set_roll_direction(local_direction: Vector3):
	roll_local_direction = local_direction.normalized() if local_direction.length_squared() > 0.001 else Vector3.FORWARD

func set_equipped_weapon(weapon):
	if not slots.has("right_weapon"):
		pending_weapon = weapon
		has_pending_weapon = true
		return
	has_pending_weapon = false
	_clear_slot("right_weapon")
	if weapon == null:
		return
	attack_family = weapon.weapon_family
	var mount = Node3D.new()
	mount.name = "WeaponVisualMount"
	mount.position = weapon.hand_position
	mount.rotation_degrees = weapon.hand_rotation_degrees
	mount.scale = weapon.hand_scale
	slots["right_weapon"].add_child(mount)
	if weapon.visual_scene != null:
		mount.add_child(weapon.visual_scene.instantiate())
		return
	match attack_family:
		"axe":
			_build_axe(mount)
		"spear":
			_build_spear(mount)
		"mace":
			_build_mace(mount)
		_:
			_build_sword(mount)

func set_equipped_armor(armor):
	pending_armor = armor
	if not slots.has("chest_armor"):
		return
	for slot_name in ["head_armor", "chest_armor", "hips_armor", "left_shoulder_armor", "right_shoulder_armor", "left_forearm_armor", "right_forearm_armor", "left_foot_armor", "right_foot_armor"]:
		_clear_slot(slot_name)
	if character_class_id == "deprived" or armor == null:
		_build_deprived_look()
	elif armor.item_id == "knight_set":
		_build_heavy_armor()
	elif character_class_id in ["warrior", "bandit"]:
		_build_medium_armor()
	elif character_class_id in ["sorcerer", "pyromancer", "cleric"]:
		_build_robes()
	elif armor.item_id == "cloth_set":
		_build_robes()
	else:
		_build_leather_armor()

func set_character_class(class_id: String):
	character_class_id = class_id

func get_armor_slot(slot_name):
	return slots.get(slot_name)

func attach_to_slot(slot_name, attachment):
	var slot = get_armor_slot(slot_name)
	if slot == null or attachment == null:
		return false
	clear_slot(slot_name)
	slot.add_child(attachment)
	return true

func clear_slot(slot_name):
	_clear_slot(slot_name)

func _build_materials():
	materials["skin"] = _make_material(Color(0.70, 0.52, 0.38), 1.0, 0.0)
	materials["hair"] = _make_material(Color(0.12, 0.09, 0.07), 1.0, 0.0)
	materials["cloth"] = _make_material(Color(0.19, 0.18, 0.20), 1.0, 0.0)
	materials["leather"] = _make_material(Color(0.25, 0.14, 0.08), 1.0, 0.0)
	materials["dark_leather"] = _make_material(Color(0.12, 0.08, 0.06), 1.0, 0.0)
	materials["metal"] = _make_material(Color(0.56, 0.57, 0.58), 0.62, 0.28)
	materials["dark_metal"] = _make_material(Color(0.19, 0.20, 0.22), 0.78, 0.18)
	materials["bone"] = _make_material(Color(0.70, 0.64, 0.52), 1.0, 0.0)
	materials["eye"] = _make_material(Color(0.03, 0.025, 0.02), 1.0, 0.0)

func _build_rig():
	rig_root = _joint(self, "RigRoot", Vector3.ZERO)
	hips = _joint(rig_root, "Hips", Vector3(0.0, 0.93, 0.0))
	var pelvis_mesh = VisualLibrary.tapered(Vector2(0.22,0.15),Vector2(0.18,0.13),0.24,materials["dark_leather"],"Pelvis")
	VisualLibrary.add_part(hips,pelvis_mesh)
	_box(hips, "Belt", Vector3(0.52, 0.08, 0.34), Vector3(0.0, 0.08, -0.01), materials["leather"])
	_box(hips, "BeltBuckle", Vector3(0.12, 0.10, 0.05), Vector3(0.0, 0.08, -0.18), materials["metal"])
	_slot(hips, "hips_armor", Vector3(0.0, 0.03, 0.0))

	spine = _joint(hips, "Spine", Vector3(0.0, 0.18, 0.0))
	var abdomen_mesh = VisualLibrary.tapered(Vector2(0.21,0.145),Vector2(0.17,0.12),0.34,materials["cloth"],"Abdomen")
	VisualLibrary.add_part(spine,abdomen_mesh,Vector3(0,0.15,0))
	_box(spine, "FrontStrap", Vector3(0.09, 0.42, 0.04), Vector3(-0.08, 0.19, -0.15), materials["leather"], Vector3(0.0, 0.0, 14.0))
	_box(spine, "SideStrap", Vector3(0.09, 0.42, 0.04), Vector3(0.10, 0.19, -0.15), materials["leather"], Vector3(0.0, 0.0, -14.0))

	chest = _joint(spine, "Chest", Vector3(0.0, 0.42, 0.0))
	var chest_mesh = VisualLibrary.tapered(Vector2(0.31,0.18),Vector2(0.22,0.145),0.44,materials["dark_metal"],"ChestPlate")
	VisualLibrary.add_part(chest,chest_mesh,Vector3(0,0.12,0))
	_box(chest, "ChestCloth", Vector3(0.46, 0.36, 0.04), Vector3(0.0, 0.11, -0.19), materials["cloth"])
	_box(chest, "BackHarness", Vector3(0.50, 0.10, 0.04), Vector3(0.0, 0.20, 0.19), materials["leather"])
	_slot(chest, "chest_armor", Vector3(0.0, 0.12, -0.19))
	_slot(chest, "back_armor", Vector3(0.0, 0.12, 0.19))

	neck = _joint(chest, "Neck", Vector3(0.0, 0.40, 0.0))
	_cylinder(neck, "NeckMesh", 0.08, 0.16, Vector3(0.0, 0.02, 0.0), materials["skin"], Vector3.ZERO, 7)
	head = _joint(neck, "Head", Vector3(0.0, 0.17, 0.0))
	_sphere(head, "HeadMesh", 0.19, Vector3(0.0, 0.04, 0.0), materials["skin"], 7)
	_box(head, "Jaw", Vector3(0.20, 0.08, 0.16), Vector3(0.0, -0.08, -0.03), materials["skin"])
	_box(head, "Brow", Vector3(0.27, 0.06, 0.06), Vector3(0.0, 0.10, -0.16), materials["hair"])
	_box(head, "LeftEye", Vector3(0.045, 0.025, 0.015), Vector3(-0.065, 0.04, -0.18), materials["eye"])
	_box(head, "RightEye", Vector3(0.045, 0.025, 0.015), Vector3(0.065, 0.04, -0.18), materials["eye"])
	_box(head, "Nose", Vector3(0.045, 0.06, 0.06), Vector3(0.0, 0.005, -0.20), materials["skin"])
	_slot(head, "head_armor", Vector3(0.0, 0.06, 0.0))
	_slot(head, "face_armor", Vector3(0.0, 0.02, -0.20))

	left_shoulder = _build_arm("Left", chest, -1.0)
	right_shoulder = _build_arm("Right", chest, 1.0)
	left_thigh = _build_leg("Left", hips, -1.0)
	right_thigh = _build_leg("Right", hips, 1.0)

func _build_arm(prefix, parent, side):
	var shoulder = _joint(parent, prefix + "Shoulder", Vector3(0.34 * side, 0.27, -0.01))
	_box(shoulder, prefix + "PauldronBase", Vector3(0.23, 0.14, 0.30), Vector3(0.04 * side, 0.02, 0.0), materials["dark_metal"], Vector3(0.0, 0.0, -7.0 * side))
	_slot(shoulder, prefix.to_lower() + "_shoulder_armor", Vector3(0.04 * side, 0.02, 0.0))
	_capsule(shoulder, prefix + "UpperArm", 0.085, 0.43, Vector3(0.0, -0.22, 0.0), materials["cloth"], 6)
	var forearm = _joint(shoulder, prefix + "Forearm", Vector3(0.0, -0.43, 0.0))
	_capsule(forearm, prefix + "ForearmMesh", 0.075, 0.38, Vector3(0.0, -0.19, 0.0), materials["leather"], 6)
	_slot(forearm, prefix.to_lower() + "_forearm_armor", Vector3(0.0, -0.17, 0.0))
	var hand = _joint(forearm, prefix + "Hand", Vector3(0.0, -0.38, -0.02))
	var hand_mesh = VisualLibrary.tapered(Vector2(0.045,0.055),Vector2(0.06,0.07),0.13,materials["skin"],prefix + "HandMesh")
	VisualLibrary.add_part(hand,hand_mesh,Vector3(0,-0.04,-0.02))
	_slot(hand, prefix.to_lower() + "_hand_armor", Vector3(0.0, -0.02, -0.02))
	if side > 0.0:
		_slot(hand, "right_weapon", Vector3(0.0, -0.05, -0.04), Vector3(0.0, 0.0, -8.0))
	else:
		_slot(hand, "left_weapon", Vector3(0.0, -0.05, -0.04), Vector3(0.0, 0.0, 8.0))
	if side < 0.0:
		left_forearm = forearm
		left_hand = hand
	else:
		right_forearm = forearm
		right_hand = hand
	return shoulder

func _build_leg(prefix, parent, side):
	var thigh = _joint(parent, prefix + "Thigh", Vector3(0.15 * side, -0.09, 0.0))
	_capsule(thigh, prefix + "ThighMesh", 0.105, 0.50, Vector3(0.0, -0.25, 0.0), materials["cloth"], 6)
	_slot(thigh, prefix.to_lower() + "_thigh_armor", Vector3(0.0, -0.22, 0.0))
	var shin = _joint(thigh, prefix + "Shin", Vector3(0.0, -0.50, 0.0))
	_capsule(shin, prefix + "ShinMesh", 0.085, 0.45, Vector3(0.0, -0.22, 0.0), materials["dark_leather"], 6)
	_slot(shin, prefix.to_lower() + "_shin_armor", Vector3(0.0, -0.18, 0.0))
	var foot = _joint(shin, prefix + "Foot", Vector3(0.0, -0.43, -0.07))
	var boot_mesh = VisualLibrary.tapered(Vector2(0.07,0.12),Vector2(0.085,0.16),0.16,materials["dark_leather"],prefix + "Boot")
	VisualLibrary.add_part(foot,boot_mesh,Vector3(0,-0.02,-0.09),Vector3(90,0,0))
	_slot(foot, prefix.to_lower() + "_foot_armor", Vector3(0.0, -0.02, -0.08))
	if side < 0.0:
		left_shin = shin
		left_foot = foot
	else:
		right_shin = shin
		right_foot = foot
	return thigh

func _pose_model():
	_pose_base()
	if death_pose:
		_pose_death()
	elif action_kind == "roll" or is_rolling:
		_pose_roll()
	elif action_kind == "attack" or attack_active:
		_pose_attack()
	elif action_kind == "stagger":
		_pose_stagger()
	elif locomotion_amount > 0.04:
		_pose_locomotion()
	else:
		_pose_idle()
	if hit_timer > 0.0 and not death_pose:
		_pose_hit()

func _pose_base():
	rig_root.position = Vector3.ZERO
	rig_root.rotation = Vector3.ZERO
	hips.position = Vector3(0.0, 0.93, 0.0)
	hips.rotation = Vector3.ZERO
	spine.rotation = Vector3.ZERO
	chest.rotation = Vector3.ZERO
	neck.rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	left_shoulder.position = Vector3(-0.34, 0.27, -0.01)
	right_shoulder.position = Vector3(0.34, 0.27, -0.01)
	left_shoulder.rotation_degrees = Vector3(5.0, 0.0, -7.0)
	right_shoulder.rotation_degrees = Vector3(5.0, 0.0, 7.0)
	left_forearm.rotation_degrees = Vector3(-4.0, 0.0, -3.0)
	right_forearm.rotation_degrees = Vector3(-4.0, 0.0, 3.0)
	left_hand.rotation = Vector3.ZERO
	right_hand.rotation = Vector3.ZERO
	left_thigh.rotation = Vector3.ZERO
	right_thigh.rotation = Vector3.ZERO
	left_shin.rotation_degrees = Vector3(4.0, 0.0, 0.0)
	right_shin.rotation_degrees = Vector3(4.0, 0.0, 0.0)
	left_foot.rotation_degrees = Vector3(-3.0, 0.0, 0.0)
	right_foot.rotation_degrees = Vector3(-3.0, 0.0, 0.0)

func _pose_idle():
	var breath = sin(animation_time * 2.2) * 0.025
	hips.position.y += breath
	chest.rotation.x = sin(animation_time * 1.8) * 0.025
	head.rotation.y = sin(animation_time * 0.9) * 0.045
	left_shoulder.rotation.x += sin(animation_time * 2.2) * 0.035
	right_shoulder.rotation.x -= sin(animation_time * 2.2) * 0.035

func _pose_locomotion():
	var pace = 8.5 if is_running else 5.3
	var strength = (0.9 if is_running else 0.58) * locomotion_amount
	var phase = animation_time * pace
	var swing = sin(phase) * strength
	var lift = abs(cos(phase)) * 0.025 * locomotion_amount
	hips.position.y += lift
	hips.rotation.y = sin(phase * 0.5) * 0.045 * locomotion_amount
	chest.rotation.y = -hips.rotation.y * 0.7
	left_thigh.rotation.x = swing
	right_thigh.rotation.x = -swing
	left_shin.rotation.x = max(0.0, -swing) * 0.65
	right_shin.rotation.x = max(0.0, swing) * 0.65
	left_foot.rotation.x = -0.18 - max(0.0, swing) * 0.25
	right_foot.rotation.x = -0.18 - max(0.0, -swing) * 0.25
	left_shoulder.rotation.x = -swing * 0.55
	right_shoulder.rotation.x = swing * 0.55
	left_forearm.rotation.x = -0.25 + max(0.0, swing) * 0.25
	right_forearm.rotation.x = -0.25 + max(0.0, -swing) * 0.25

func _pose_roll():
	var p = action_progress if action_kind == "roll" else clamp(1.0 - roll_timer / roll_duration, 0.0, 1.0)
	var side_roll = abs(roll_local_direction.x) > abs(roll_local_direction.z)
	var forward_sign = 1.0 if roll_local_direction.z <= 0.0 else -1.0
	var angle := 0.0
	match action_phase:
		"prepare":
			var prep = p * p * (3.0 - 2.0 * p)
			hips.position.y = lerp(0.93, 0.66, prep)
			chest.rotation.x = -0.52 * prep
			left_thigh.rotation.x = 0.45 * prep
			right_thigh.rotation.x = 0.45 * prep
		"impulse":
			angle = p * PI * 0.35
			_apply_roll_tuck(lerp(0.75, 1.0, p), angle, side_roll, forward_sign)
		"invulnerable":
			angle = PI * 0.35 + p * PI * 1.25
			_apply_roll_tuck(sin(p * PI), angle, side_roll, forward_sign)
		"travel":
			angle = PI * 1.60 + p * PI * 0.40
			_apply_roll_tuck(1.0 - p * 0.45, angle, side_roll, forward_sign)
		"landing":
			var settle = 1.0 - p * p * (3.0 - 2.0 * p)
			hips.position.y = lerp(0.93, 0.70, settle)
			chest.rotation.x = -0.42 * settle
			left_thigh.rotation.x = 0.40 * settle
			right_thigh.rotation.x = 0.40 * settle
		"recovery":
			var recover = 1.0 - p * p * (3.0 - 2.0 * p)
			hips.position.y = lerp(0.93, 0.82, recover)
			chest.rotation.x = -0.18 * recover
			left_thigh.rotation.x = 0.16 * recover
			right_thigh.rotation.x = 0.16 * recover
		_:
			pass

func _apply_roll_tuck(tuck: float, angle: float, side_roll: bool, forward_sign: float):
	hips.position.y = 0.62 + tuck * 0.06
	if side_roll:
		rig_root.rotation.z = -sign(roll_local_direction.x) * angle
	else:
		rig_root.rotation.x = -forward_sign * angle
	chest.rotation.x += -0.72 * tuck
	head.rotation.x = 0.42 * tuck
	left_shoulder.rotation_degrees = Vector3(-100.0 * tuck, 0.0, -32.0)
	right_shoulder.rotation_degrees = Vector3(-100.0 * tuck, 0.0, 32.0)
	left_forearm.rotation_degrees = Vector3(-92.0 * tuck, 0.0, 0.0)
	right_forearm.rotation_degrees = Vector3(-92.0 * tuck, 0.0, 0.0)
	left_thigh.rotation_degrees = Vector3(70.0 * tuck, 0.0, -7.0)
	right_thigh.rotation_degrees = Vector3(70.0 * tuck, 0.0, 7.0)
	left_shin.rotation_degrees = Vector3(-96.0 * tuck, 0.0, 0.0)
	right_shin.rotation_degrees = Vector3(-96.0 * tuck, 0.0, 0.0)

func _pose_attack():
	var p = action_progress if action_kind == "attack" else clamp(1.0 - attack_timer / attack_duration, 0.0, 1.0)
	var progress := 0.0
	match action_phase:
		"windup": progress = 0.30 * (p * p * (3.0 - 2.0 * p))
		"active": progress = 0.30 + 0.50 * (1.0 - pow(1.0 - p, 3.0))
		"recovery": progress = 0.80 + 0.20 * (p * p * (3.0 - 2.0 * p))
		_: progress = p
	var impact = sin(clamp((progress - 0.25) / 0.65, 0.0, 1.0) * PI)
	var heavy = 1.22 if attack_kind == "heavy" else 1.0
	var recovery_weight = 1.0 - (p * p * (3.0 - 2.0 * p)) if action_phase == "recovery" else 1.0
	hips.rotation.y = -sin(progress * PI * 1.1) * 0.22 * heavy * recovery_weight
	spine.rotation.x = -impact * 0.12 * heavy * recovery_weight
	head.rotation.y = -hips.rotation.y * 0.35
	match attack_family:
		"axe":
			chest.rotation.y = lerp(-0.35, 0.48, progress) * heavy
			chest.rotation.x = -0.18 * impact
			right_shoulder.rotation_degrees = Vector3(lerp(-135.0, 72.0, progress), 0.0, lerp(-28.0, 62.0, progress))
			right_forearm.rotation_degrees = Vector3(-38.0, 0.0, lerp(-12.0, 28.0, progress))
			left_shoulder.rotation_degrees = Vector3(-72.0, -18.0, -44.0)
		"spear":
			var thrust = sin(progress * PI)
			chest.rotation.y = lerp(-0.18, 0.16, progress)
			right_shoulder.position.z = -0.01 - thrust * 0.30
			right_shoulder.rotation_degrees = Vector3(-84.0, 0.0, 18.0)
			right_forearm.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
			left_shoulder.rotation_degrees = Vector3(-74.0, 0.0, -28.0)
			left_forearm.rotation_degrees = Vector3(-34.0, 0.0, 0.0)
		"mace":
			chest.rotation.y = lerp(0.32, -0.45, progress) * heavy
			right_shoulder.rotation_degrees = Vector3(lerp(-118.0, 56.0, progress), 0.0, lerp(-46.0, 70.0, progress))
			right_forearm.rotation_degrees = Vector3(-72.0 + impact * 38.0, 0.0, lerp(-18.0, 30.0, progress))
			left_shoulder.rotation_degrees = Vector3(-35.0, 0.0, -28.0)
		_:
			chest.rotation.y = lerp(-0.42, 0.48, progress) * heavy
			right_shoulder.rotation_degrees = Vector3(lerp(-76.0, 38.0, progress), lerp(-28.0, 34.0, progress), lerp(-68.0, 76.0, progress))
			right_forearm.rotation_degrees = Vector3(-32.0, 0.0, lerp(-24.0, 34.0, progress))
			left_shoulder.rotation_degrees = Vector3(-28.0, 0.0, -25.0)
	right_hand.rotation.z = -0.25 * impact
	left_thigh.rotation.x = -0.12 * impact
	right_thigh.rotation.x = 0.12 * impact
	if action_phase == "recovery":
		chest.rotation *= recovery_weight
		right_shoulder.rotation *= recovery_weight
		right_forearm.rotation *= recovery_weight
		left_shoulder.rotation *= recovery_weight
		left_forearm.rotation *= recovery_weight

func _pose_hit():
	var duration = 0.30 if hit_strength > 1.0 else 0.20
	var strength = clamp(hit_timer / duration, 0.0, 1.0) * hit_strength
	var local_direction = global_transform.basis.inverse() * hit_direction
	chest.rotation.x += local_direction.z * 0.32 * strength
	chest.rotation.z += -local_direction.x * 0.28 * strength
	head.rotation.x += local_direction.z * 0.18 * strength
	head.rotation.z += -local_direction.x * 0.16 * strength
	left_shoulder.rotation.x += 0.30 * strength
	right_shoulder.rotation.x += 0.30 * strength

func _pose_stagger():
	var p = action_progress
	var recoil = sin(p * PI)
	chest.rotation.x = -0.48 * recoil
	chest.rotation.z = 0.20 * recoil
	head.rotation.x = -0.30 * recoil
	left_shoulder.rotation.x = 0.62 * recoil
	right_shoulder.rotation.x = 0.72 * recoil
	hips.position.y -= 0.08 * recoil

func _pose_death():
	hips.position.y = 0.24
	rig_root.rotation_degrees = Vector3(78.0, 0.0, -22.0)
	chest.rotation_degrees = Vector3(20.0, 0.0, 0.0)
	head.rotation_degrees = Vector3(18.0, 0.0, 0.0)
	left_shoulder.rotation_degrees = Vector3(-40.0, 0.0, -85.0)
	right_shoulder.rotation_degrees = Vector3(-20.0, 0.0, 90.0)
	left_thigh.rotation_degrees = Vector3(36.0, 0.0, -22.0)
	right_thigh.rotation_degrees = Vector3(-28.0, 0.0, 24.0)

func _build_sword(parent):
	_cylinder(parent, "SwordGrip", 0.035, 0.28, Vector3(0.0, -0.10, 0.0), materials["leather"], Vector3.ZERO, 6)
	_box(parent, "SwordGuard", Vector3(0.42, 0.055, 0.08), Vector3(0.0, -0.25, -0.01), materials["dark_metal"])
	var blade = VisualLibrary.tapered(Vector2(0.0, 0.018), Vector2(0.075, 0.028), 1.12, materials["metal"], "SwordBlade")
	VisualLibrary.add_part(parent, blade, Vector3(0.0, -0.84, -0.01))
	_cylinder(parent, "SwordPommel", 0.065, 0.11, Vector3(0.0, 0.095, 0.0), materials["dark_metal"], Vector3.ZERO, 7)
	_box(parent, "BladeRidge", Vector3(0.018, 0.88, 0.045), Vector3(0.0, -0.72, -0.01), materials["dark_metal"])

func _build_deprived_look():
	var wrap = VisualLibrary.tapered(Vector2(0.22,0.14),Vector2(0.25,0.16),0.22,materials["cloth"],"WaistWrap")
	VisualLibrary.add_part(slots["hips_armor"],wrap)

func _build_leather_armor():
	var vest = VisualLibrary.tapered(Vector2(0.31,0.18),Vector2(0.23,0.16),0.58,materials["leather"],"LeatherVest")
	VisualLibrary.add_part(slots["chest_armor"],vest,Vector3(0,0,-0.02))
	for side in ["left", "right"]:
		var shoulder = VisualLibrary.tapered(Vector2(0.09,0.13),Vector2(0.15,0.17),0.15,materials["dark_leather"],"LeatherShoulder")
		VisualLibrary.add_part(slots[side + "_shoulder_armor"],shoulder)

func _build_heavy_armor():
	var cuirass = VisualLibrary.tapered(Vector2(0.34,0.20),Vector2(0.24,0.17),0.62,materials["metal"],"Cuirass")
	VisualLibrary.add_part(slots["chest_armor"],cuirass,Vector3(0,0,-0.02))
	var helm = VisualLibrary.tapered(Vector2(0.18,0.17),Vector2(0.16,0.15),0.38,materials["dark_metal"],"KnightHelm")
	VisualLibrary.add_part(slots["head_armor"],helm,Vector3(0,0.02,0))
	var visor = VisualLibrary.box(Vector3(0.28,0.055,0.035),materials["dark_leather"],"VisorSlit")
	VisualLibrary.add_part(slots["head_armor"],visor,Vector3(0,0.07,-0.18))
	var nose_guard = VisualLibrary.tapered(Vector2(0.025,0.018),Vector2(0.04,0.025),0.22,materials["metal"],"NoseGuard")
	VisualLibrary.add_part(slots["head_armor"],nose_guard,Vector3(0,-0.02,-0.20))
	for side in ["left", "right"]:
		var pauldron = VisualLibrary.tapered(Vector2(0.12,0.17),Vector2(0.20,0.22),0.18,materials["metal"],"Pauldron")
		VisualLibrary.add_part(slots[side + "_shoulder_armor"],pauldron)
		var vambrace = VisualLibrary.tapered(Vector2(0.08,0.09),Vector2(0.11,0.11),0.34,materials["dark_metal"],"Vambrace")
		VisualLibrary.add_part(slots[side + "_forearm_armor"],vambrace,Vector3(0,-0.17,0))

func _build_medium_armor():
	var brigandine = VisualLibrary.tapered(Vector2(0.32,0.19),Vector2(0.24,0.16),0.60,materials["leather"],"Brigandine")
	VisualLibrary.add_part(slots["chest_armor"],brigandine,Vector3(0,0,-0.02))
	for y in [-0.16,0.0,0.16]:
		var plate = VisualLibrary.box(Vector3(0.48,0.07,0.035),materials["dark_metal"],"BrigandinePlate")
		VisualLibrary.add_part(slots["chest_armor"],plate,Vector3(0,y,-0.20))
	var pauldron = VisualLibrary.tapered(Vector2(0.12,0.16),Vector2(0.19,0.21),0.17,materials["dark_metal"],"WarriorPauldron")
	VisualLibrary.add_part(slots["right_shoulder_armor"],pauldron)
	var skirt = VisualLibrary.tapered(Vector2(0.24,0.16),Vector2(0.32,0.21),0.36,materials["cloth"],"BattleSkirt")
	VisualLibrary.add_part(slots["hips_armor"],skirt,Vector3(0,-0.16,0))

func _build_robes():
	var robe = VisualLibrary.tapered(Vector2(0.30,0.18),Vector2(0.23,0.15),0.66,materials["cloth"],"RobeTorso")
	VisualLibrary.add_part(slots["chest_armor"],robe)
	var skirt = VisualLibrary.tapered(Vector2(0.24,0.16),Vector2(0.37,0.24),0.64,materials["cloth"],"RobeSkirt")
	VisualLibrary.add_part(slots["hips_armor"],skirt,Vector3(0,-0.28,0))
	var hood = VisualLibrary.tapered(Vector2(0.23,0.21),Vector2(0.17,0.16),0.40,materials["cloth"],"Hood")
	VisualLibrary.add_part(slots["head_armor"],hood,Vector3(0,0.03,0.03))

func _build_axe(parent):
	_cylinder(parent, "AxeHandle", 0.038, 1.02, Vector3(0.0, -0.58, 0.0), materials["leather"], Vector3.ZERO, 6)
	_box(parent, "AxeHeadCore", Vector3(0.16, 0.20, 0.10), Vector3(0.0, -1.12, 0.0), materials["dark_metal"])
	_box(parent, "AxeLeftBlade", Vector3(0.34, 0.30, 0.08), Vector3(-0.20, -1.10, -0.01), materials["metal"], Vector3(0.0, 0.0, -18.0))
	_box(parent, "AxeRightSpike", Vector3(0.23, 0.11, 0.07), Vector3(0.20, -1.11, -0.01), materials["metal"], Vector3(0.0, 0.0, 18.0))

func _build_spear(parent):
	_cylinder(parent, "SpearShaft", 0.026, 1.75, Vector3(0.0, -0.12, -0.82), materials["leather"], Vector3(90.0, 0.0, 0.0), 6)
	_cylinder(parent, "SpearHead", 0.085, 0.32, Vector3(0.0, -0.12, -1.86), materials["metal"], Vector3(90.0, 0.0, 0.0), 5, 0.0)
	_box(parent, "SpearWingL", Vector3(0.22, 0.05, 0.08), Vector3(-0.12, -0.12, -1.69), materials["metal"], Vector3(0.0, 0.0, 20.0))
	_box(parent, "SpearWingR", Vector3(0.22, 0.05, 0.08), Vector3(0.12, -0.12, -1.69), materials["metal"], Vector3(0.0, 0.0, -20.0))

func _build_mace(parent):
	_cylinder(parent, "MaceHandle", 0.035, 0.72, Vector3(0.0, -0.43, 0.0), materials["leather"], Vector3.ZERO, 6)
	_box(parent, "MaceHead", Vector3(0.22, 0.22, 0.22), Vector3(0.0, -0.86, 0.0), materials["dark_metal"])
	_box(parent, "MaceFlangeX", Vector3(0.36, 0.08, 0.10), Vector3(0.0, -0.86, 0.0), materials["metal"])
	_box(parent, "MaceFlangeZ", Vector3(0.10, 0.08, 0.36), Vector3(0.0, -0.86, 0.0), materials["metal"])

func _clear_slot(slot_name):
	var slot = slots.get(slot_name)
	if slot == null:
		return
	for child in slot.get_children():
		slot.remove_child(child)
		child.queue_free()

func _joint(parent, joint_name, position):
	var joint = Node3D.new()
	joint.name = joint_name
	joint.position = position
	parent.add_child(joint)
	return joint

func _slot(parent, slot_name, position, rotation_degrees_value = Vector3.ZERO):
	var slot = _joint(parent, slot_name, position)
	slot.rotation_degrees = rotation_degrees_value
	slots[slot_name] = slot
	return slot

func _box(parent, mesh_name, size, position, material, rotation_degrees_value = Vector3.ZERO):
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_degrees_value
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _capsule(parent, mesh_name, radius, height, position, material, radial_segments = 6):
	var mesh_instance = VisualLibrary.tapered(Vector2(radius * 0.78, radius * 0.78), Vector2(radius, radius), height, material, mesh_name)
	mesh_instance.position = position
	parent.add_child(mesh_instance)
	return mesh_instance

func _cylinder(parent, mesh_name, radius, height, position, material, rotation_degrees_value = Vector3.ZERO, radial_segments = 6, top_radius = -1.0):
	var mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_degrees_value
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _sphere(parent, mesh_name, radius, position, material, radial_segments = 7):
	var mesh_instance = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial_segments
	mesh.rings = 4
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _make_material(color, roughness, metallic):
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
