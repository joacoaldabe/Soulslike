extends RefCounted
class_name CombatHit

var attacker = null
var damage := 0
var poise_damage := 0.0
var direction := Vector3.FORWARD
var point := Vector3.ZERO
var force := 0.0
var impact_type := "light"
var attack_id := 0

func _init(
	attacker_value = null,
	damage_value: int = 0,
	poise_damage_value: float = 0.0,
	direction_value: Vector3 = Vector3.FORWARD,
	point_value: Vector3 = Vector3.ZERO,
	force_value: float = 0.0,
	impact_type_value: String = "light",
	attack_id_value: int = 0
):
	attacker = attacker_value
	damage = damage_value
	poise_damage = poise_damage_value
	direction = direction_value.normalized() if direction_value.length_squared() > 0.0001 else Vector3.FORWARD
	point = point_value
	force = force_value
	impact_type = impact_type_value
	attack_id = attack_id_value
