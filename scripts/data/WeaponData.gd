extends Resource
class_name WeaponData

@export var item_id = ""
@export var display_name = ""
@export var description = ""
@export var weapon_family = "sword"
@export var base_damage = 40
@export var light_stamina_cost = 18
@export var heavy_stamina_cost = 32
@export var requirements = {}
@export var scaling = {}
@export var attack_reach = 2.0
@export var attack_arc = 70.0
@export var attack_time = 0.45

# Visual-only metadata. Gameplay never reads these fields.
@export var visual_scene: PackedScene
@export var hand_scale = Vector3.ONE
@export var hand_position = Vector3.ZERO
@export var hand_rotation_degrees = Vector3.ZERO
@export var stowed_position = Vector3(0.32, 0.12, 0.18)
@export var stowed_rotation_degrees = Vector3(8.0, 0.0, 145.0)
@export var visual_effect_id = ""
