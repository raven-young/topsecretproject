class_name Mats
extends RefCounted
## Shared toon materials and helpers for building grey-box geometry from
## primitives. Swap these for real models/assets later.

static var _cache: Dictionary = {}


static func toon(color: Color, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), emission]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	_cache[key] = mat
	return mat


## White material that takes its colour from vertex/instance colours.
static func vertex_colored() -> StandardMaterial3D:
	if _cache.has("vertex"):
		return _cache["vertex"]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_cache["vertex"] = mat
	return mat


static func mesh(parent: Node, m: Mesh, color: Color, pos := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = toon(color, emission)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, collide := false) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := mesh(parent, m, color, pos)
	mi.rotation = rot
	if collide:
		_add_collider(mi, _box_shape(size))
	return mi


static func cylinder(parent: Node, radius: float, height: float, color: Color, pos := Vector3.ZERO, collide := false, top_radius := -1.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = 12
	m.rings = 1
	var mi := mesh(parent, m, color, pos)
	if collide:
		var shape := CylinderShape3D.new()
		shape.radius = maxf(radius, m.top_radius)
		shape.height = height
		_add_collider(mi, shape)
	return mi


static func sphere(parent: Node, radius: float, color: Color, pos := Vector3.ZERO, emission := 0.0) -> MeshInstance3D:
	return mesh(parent, sphere_mesh(radius), color, pos, emission)


static func sphere_mesh(radius: float, segments := 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = segments / 2
	return m


static func cone_mesh(radius: float, height: float, segments := 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = 0.0
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m


static func light(parent: Node, color: Color, energy: float, light_range: float, pos := Vector3.ZERO) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.position = pos
	parent.add_child(l)
	return l


static func label(parent: Node, text: String, pos: Vector3, size := 48, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.008
	l.outline_size = 12
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(l)
	return l


static func _box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


static func _add_collider(mi: MeshInstance3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	mi.add_child(body)
