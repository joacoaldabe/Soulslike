extends RefCounted
class_name VisualLibrary

static var _materials := {}

static func material(id: String) -> Material:
	if _materials.has(id):
		return _materials[id]
	var colors = {
		"stone": Color("454b4c"), "stone_light": Color("626661"), "stone_dark": Color("252a2d"),
		"wet_stone": Color("30383a"), "metal": Color("7b8180"), "dark_metal": Color("343a3c"),
		"rust": Color("674238"), "leather": Color("493127"), "wood": Color("392b24"),
		"cloth": Color("343337"), "cloth_red": Color("54383b"), "cloth_blue": Color("35424d"),
		"moss": Color("3f4a3b"), "skin": Color("9b7560"), "bone": Color("a59b7d"),
		"fire": Color("ff7624"), "souls": Color("55e889")
	}
	if id in ["stone", "stone_light", "stone_dark", "wet_stone"]:
		var stone = _stone_material(colors[id], id == "wet_stone")
		_materials[id] = stone
		return stone
	var m = StandardMaterial3D.new()
	m.albedo_color = colors.get(id, Color("777777"))
	m.roughness = 0.62 if id.contains("metal") else 0.94
	m.metallic = 0.65 if id.contains("metal") else 0.0
	if id in ["fire", "souls"]:
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 2.2
	_materials[id] = m
	return m

static func _stone_material(color: Color, wet: bool) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color;
uniform float wetness = 0.0;
varying vec3 world_position;
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 cell = floor(world_position.xz * 1.35 + world_position.y * 0.7);
	float grain = hash(cell);
	float broad = sin(world_position.x * 0.45) * sin(world_position.z * 0.38) * 0.5 + 0.5;
	float shade = 0.72 + grain * 0.16 + broad * 0.12;
	float upward = clamp(NORMAL.y * 0.18 + 0.82, 0.68, 1.0);
	ALBEDO = base_color.rgb * shade * upward;
	ROUGHNESS = mix(0.96, 0.68, wetness);
	SPECULAR = mix(0.18, 0.42, wetness);
}
"""
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("wetness", 0.65 if wet else 0.0)
	return material

static func mesh_instance(mesh: Mesh, mat: Material, node_name: String = "Mesh") -> MeshInstance3D:
	var instance = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = mat
	return instance

static func box(size: Vector3, mat: Material, node_name: String = "Box") -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	return mesh_instance(mesh, mat, node_name)

static func cylinder(radius: float, height: float, mat: Material, sides: int = 8, node_name: String = "Cylinder") -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return mesh_instance(mesh, mat, node_name)

static func tapered(top: Vector2, bottom: Vector2, height: float, mat: Material, node_name: String = "Tapered") -> MeshInstance3D:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	var corners = [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]
	for c in corners:
		vertices.append(Vector3(c.x * bottom.x, -height * 0.5, c.y * bottom.y))
	for c in corners:
		vertices.append(Vector3(c.x * top.x, height * 0.5, c.y * top.y))
	for i in range(8):
		normals.append(vertices[i].normalized())
	indices = PackedInt32Array([0,2,1,0,3,2,4,5,6,4,6,7,0,1,5,0,5,4,1,2,6,1,6,5,2,3,7,2,7,6,3,0,4,3,4,7])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh_instance(mesh, mat, node_name)

static func add_part(parent: Node, part: Node3D, position: Vector3 = Vector3.ZERO, rotation: Vector3 = Vector3.ZERO) -> Node3D:
	part.position = position
	part.rotation_degrees = rotation
	parent.add_child(part)
	return part
