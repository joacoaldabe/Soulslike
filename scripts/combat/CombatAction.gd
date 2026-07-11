extends RefCounted
class_name CombatAction

var kind := ""
var phases: Array[Dictionary] = []
var phase_index := 0
var phase_elapsed := 0.0
var total_elapsed := 0.0
var finished := true

func begin(action_kind: String, definitions: Array[Dictionary]):
	kind = action_kind
	phases = definitions.duplicate(true)
	phase_index = 0
	phase_elapsed = 0.0
	total_elapsed = 0.0
	finished = phases.is_empty()

func update(delta: float) -> bool:
	if finished:
		return false
	var changed := false
	phase_elapsed += delta
	total_elapsed += delta
	while not finished and phase_elapsed >= get_phase_duration():
		phase_elapsed -= get_phase_duration()
		phase_index += 1
		changed = true
		if phase_index >= phases.size():
			finished = true
	return changed

func cancel():
	finished = true
	phases.clear()
	kind = ""
	phase_index = 0
	phase_elapsed = 0.0
	total_elapsed = 0.0

func get_phase() -> String:
	if finished or phases.is_empty():
		return "none"
	return str(phases[phase_index].get("name", "none"))

func get_phase_duration() -> float:
	if finished or phases.is_empty():
		return 0.001
	return max(0.001, float(phases[phase_index].get("duration", 0.001)))

func get_phase_progress() -> float:
	return clamp(phase_elapsed / get_phase_duration(), 0.0, 1.0)

func get_total_duration() -> float:
	var duration := 0.0
	for phase in phases:
		duration += max(0.001, float(phase.get("duration", 0.001)))
	return duration

func get_action_progress() -> float:
	var duration = get_total_duration()
	return clamp(total_elapsed / duration, 0.0, 1.0) if duration > 0.0 else 1.0

func get_flag(flag_name: String, fallback = false):
	if finished or phases.is_empty():
		return fallback
	return phases[phase_index].get(flag_name, fallback)

func allows_rotation() -> bool:
	return bool(get_flag("allow_rotation", false))

func allows_movement() -> bool:
	return bool(get_flag("allow_movement", false))

func is_hitbox_active() -> bool:
	return bool(get_flag("hitbox_active", false))

func can_chain() -> bool:
	return bool(get_flag("can_chain", false))

func is_interruptible() -> bool:
	return bool(get_flag("interruptible", false))

func is_invulnerable() -> bool:
	return bool(get_flag("invulnerable", false))

func is_active() -> bool:
	return not finished
