extends CanvasLayer
class_name BonfireFogTransition

signal fully_covered
signal finished

@export_group("Timing")
@export_range(0.1, 5.0, 0.05) var entrance_duration := 1.65
@export_range(0.0, 3.0, 0.05) var full_coverage_pause := 0.35
@export_range(0.1, 5.0, 0.05) var exit_duration := 1.45

@export_group("Fog")
@export_range(0.25, 2.0, 0.05) var fog_density := 1.0
@export_range(1.0, 2.5, 0.05) var expansion_radius := 1.65
@export var fog_color := Color(0.36, 0.42, 0.44, 1.0)
@export_range(0.05, 3.0, 0.05) var smoke_speed := 0.65

var overlay: ColorRect = null
var active := false
var phase := "idle"
var phase_progress := 0.0

var _phase_elapsed := 0.0
var _smoke_time := 0.0
var _reveal_requested := false
var _cover_origin: Node3D = null
var _reveal_origin: Node3D = null

func _ready():
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	set_process(false)

func begin(origin: Node3D) -> bool:
	if active or origin == null or not is_instance_valid(origin):
		return false
	active = true
	phase = "covering"
	phase_progress = 0.0
	_phase_elapsed = 0.0
	_smoke_time = 0.0
	_reveal_requested = false
	_cover_origin = origin
	_reveal_origin = origin
	overlay.show()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_shader_phase(false, 0.0)
	_update_origin(origin)
	set_process(true)
	return true

func reveal_from(origin: Node3D):
	if not active:
		return
	if origin != null and is_instance_valid(origin):
		_reveal_origin = origin
	_reveal_requested = true

func is_active() -> bool:
	return active

func is_fully_opaque() -> bool:
	return active and phase == "covered" and phase_progress >= 1.0

func _process(delta: float):
	if not active:
		return
	_smoke_time += delta
	(overlay.material as ShaderMaterial).set_shader_parameter("smoke_time", _smoke_time)
	match phase:
		"covering":
			_update_origin(_cover_origin)
			_phase_elapsed += delta
			phase_progress = clamp(_phase_elapsed / max(entrance_duration, 0.01), 0.0, 1.0)
			_set_shader_phase(false, phase_progress)
			if phase_progress >= 1.0:
				phase = "covered"
				_phase_elapsed = 0.0
				fully_covered.emit()
		"covered":
			phase_progress = 1.0
			_set_shader_phase(false, 1.0)
			_phase_elapsed += delta
			if _reveal_requested and _phase_elapsed >= full_coverage_pause:
				phase = "revealing"
				phase_progress = 0.0
				_phase_elapsed = 0.0
				_update_origin(_reveal_origin)
				_set_shader_phase(true, 0.0)
		"revealing":
			_update_origin(_reveal_origin)
			_phase_elapsed += delta
			phase_progress = clamp(_phase_elapsed / max(exit_duration, 0.01), 0.0, 1.0)
			_set_shader_phase(true, phase_progress)
			if phase_progress >= 1.0:
				_finish_transition()

func _finish_transition():
	active = false
	phase = "idle"
	phase_progress = 0.0
	_reveal_requested = false
	_cover_origin = null
	_reveal_origin = null
	overlay.hide()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	finished.emit()

func _build_overlay():
	overlay = ColorRect.new()
	overlay.name = "FogOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color.WHITE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_mode : hint_range(0.0, 1.0) = 0.0;
uniform float fog_density : hint_range(0.25, 2.0) = 1.0;
uniform float expansion_radius : hint_range(1.0, 2.5) = 1.65;
uniform vec4 fog_color : source_color = vec4(0.32, 0.38, 0.41, 1.0);
uniform float smoke_speed = 0.65;
uniform float smoke_time = 0.0;
uniform vec2 origin_uv = vec2(0.5);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fog_noise(vec2 p) {
	float value = 0.0;
	float amplitude = 0.55;
	for (int i = 0; i < 4; i++) {
		value += noise(p) * amplitude;
		p = p * 2.03 + vec2(13.7, 7.9);
		amplitude *= 0.5;
	}
	return value;
}

void fragment() {
	float time = smoke_time * smoke_speed;
	float broad = fog_noise(UV * 4.2 + vec2(time * 0.09, -time * 0.06));
	float detail = fog_noise(UV * 8.0 + vec2(-time * 0.13, time * 0.08));
	float edge_noise = (broad - 0.5) * 0.24 * (1.0 - progress * 0.55);
	float distance_from_fire = distance(UV, origin_uv);
	float alpha = 0.0;

	if (reveal_mode < 0.5) {
		float radius = pow(progress, 1.28) * expansion_radius;
		float fog_shape = 1.0 - smoothstep(radius - 0.14 + edge_noise, radius + 0.10 + edge_noise, distance_from_fire);
		float rolling_bands = fog_noise(vec2(UV.x * 6.4 - time * 0.11, UV.y * 2.3 + time * 0.08));
		float translucent_body = fog_shape * mix(0.14, 0.82, progress) * fog_density * (0.52 + broad * 0.56);
		float drifting_wisps = fog_shape * (0.08 + detail * 0.28 + rolling_bands * 0.18) * smoothstep(0.02, 0.42, progress);
		alpha = clamp(max(translucent_body, drifting_wisps), 0.0, 0.94);
		alpha = mix(alpha, 1.0, smoothstep(0.88, 1.0, progress));
	} else {
		float clear_radius = pow(progress, 1.20) * expansion_radius;
		float clear_shape = 1.0 - smoothstep(clear_radius - 0.12 + edge_noise, clear_radius + 0.12 + edge_noise, distance_from_fire);
		float clear_strength = smoothstep(0.0, 0.82, progress);
		float remaining = 1.0 - clear_shape * clear_strength;
		float textured_fog = remaining * (0.68 + broad * 0.24 + detail * 0.12);
		alpha = mix(1.0, textured_fog, smoothstep(0.03, 0.20, progress));
		alpha *= 1.0 - smoothstep(0.90, 1.0, progress);
	}

	vec3 shaded_fog = fog_color.rgb * (0.58 + broad * 0.34 + detail * 0.16);
	COLOR = vec4(shaded_fog, clamp(alpha, 0.0, 1.0));
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fog_density", fog_density)
	material.set_shader_parameter("expansion_radius", expansion_radius)
	material.set_shader_parameter("fog_color", fog_color)
	material.set_shader_parameter("smoke_speed", smoke_speed)
	overlay.material = material
	add_child(overlay)
	overlay.hide()

func _set_shader_phase(revealing: bool, value: float):
	var material := overlay.material as ShaderMaterial
	material.set_shader_parameter("reveal_mode", 1.0 if revealing else 0.0)
	material.set_shader_parameter("progress", value)
	material.set_shader_parameter("fog_density", fog_density)
	material.set_shader_parameter("expansion_radius", expansion_radius)
	material.set_shader_parameter("fog_color", fog_color)
	material.set_shader_parameter("smoke_speed", smoke_speed)

func _update_origin(origin: Node3D):
	if origin == null or not is_instance_valid(origin):
		return
	var camera := get_viewport().get_camera_3d()
	var viewport_size := get_viewport().get_visible_rect().size
	if camera == null or viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var screen_position := camera.unproject_position(origin.global_position + Vector3.UP * 0.65)
	var origin_uv := Vector2(screen_position.x / viewport_size.x, screen_position.y / viewport_size.y)
	(overlay.material as ShaderMaterial).set_shader_parameter("origin_uv", origin_uv.clamp(Vector2.ZERO, Vector2.ONE))
