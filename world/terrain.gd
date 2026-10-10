class_name Terrain
extends StaticBody3D
## Island heightmap: rolling noise, a north-east hill, a western cliff plateau
## (with a gentle ramp in the north), a south-east lake, a flattened village
## at the origin, a flat cave floor, and sea all around.

const CELLS := 200
const CELL_SIZE := 2.0
const HALF_EXTENT := CELLS * CELL_SIZE * 0.5
const VILLAGE_HEIGHT := 3.0
const CAVE_FLOOR := 4.0
const CAVE_CENTER := Vector2(-82, 10)
const HILL_CENTER := Vector2(90, -70)
const LAKE_CENTER := Vector2(70, 85)

var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()


func _init() -> void:
	_noise.seed = 1337
	_noise.frequency = 0.006
	_noise.fractal_octaves = 4
	_detail.seed = 7
	_detail.frequency = 0.08


func _ready() -> void:
	_generate()


func height_at(x: float, z: float) -> float:
	var h := 6.0 + _noise.get_noise_2d(x, z) * 8.0
	h += 26.0 * _bump(x, z, HILL_CENTER, 28.0)
	var cliff_half_width := lerpf(4.0, 35.0, smoothstep(60.0, 110.0, z))
	h += 18.0 * smoothstep(0.0, 1.0, clampf((-99.0 - x) / (2.0 * cliff_half_width) + 0.5, 0.0, 1.0))
	h -= 14.0 * _bump(x, z, LAKE_CENTER, 20.0)
	h = lerpf(CAVE_FLOOR, h, smoothstep(16.0, 26.0, Vector2(x, z).distance_to(CAVE_CENTER)))
	h = lerpf(VILLAGE_HEIGHT, h, smoothstep(30.0, 48.0, Vector2(x, z).length()))
	var edge := Vector2(x, z).length() * 0.75 + maxf(absf(x), absf(z)) * 0.25 + _noise.get_noise_2d(x * 2.0, z * 2.0) * 18.0
	return lerpf(h, -8.0, smoothstep(150.0, 192.0, edge))


func slope_at(x: float, z: float) -> float:
	var dx := height_at(x + 1.0, z) - height_at(x - 1.0, z)
	var dz := height_at(x, z + 1.0) - height_at(x, z - 1.0)
	return Vector2(dx, dz).length() / 2.0


func _bump(x: float, z: float, center: Vector2, sigma: float) -> float:
	return exp(-Vector2(x, z).distance_squared_to(center) / (2.0 * sigma * sigma))


func _generate() -> void:
	var n := CELLS + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for iz in n:
		for ix in n:
			heights[iz * n + ix] = height_at(-HALF_EXTENT + ix * CELL_SIZE, -HALF_EXTENT + iz * CELL_SIZE)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	verts.resize(n * n)
	normals.resize(n * n)
	colors.resize(n * n)
	for iz in n:
		for ix in n:
			var i := iz * n + ix
			var x := -HALF_EXTENT + ix * CELL_SIZE
			var z := -HALF_EXTENT + iz * CELL_SIZE
			var h := heights[i]
			var left := heights[iz * n + maxi(ix - 1, 0)]
			var right := heights[iz * n + mini(ix + 1, n - 1)]
			var back := heights[maxi(iz - 1, 0) * n + ix]
			var front := heights[mini(iz + 1, n - 1) * n + ix]
			var normal := Vector3(left - right, 2.0 * CELL_SIZE, back - front).normalized()
			verts[i] = Vector3(x, h, z)
			normals[i] = normal
			colors[i] = _color(x, z, h, normal.y)

	var indices := PackedInt32Array()
	indices.resize(CELLS * CELLS * 6)
	var k := 0
	for iz in CELLS:
		for ix in CELLS:
			var a := iz * n + ix
			var b := a + 1
			var c := a + n
			var d := c + 1
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = d
			indices[k + 3] = a
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := Mats.vertex_colored().duplicate()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)

	# The collision heightmap is in cell units and scaled up uniformly.
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	var scaled := PackedFloat32Array()
	scaled.resize(n * n)
	for i in n * n:
		scaled[i] = heights[i] / CELL_SIZE
	shape.map_data = scaled
	var col := CollisionShape3D.new()
	col.shape = shape
	col.scale = Vector3.ONE * CELL_SIZE
	add_child(col)


func _color(x: float, z: float, h: float, up: float) -> Color:
	var c: Color
	if h < -0.6:
		c = Color("#5f8a86").lerp(Color("#2f4f5c"), clampf(-h / 8.0, 0.0, 1.0))
	elif Vector2(x, z).distance_to(CAVE_CENTER) < 15.0:
		c = Color("#6b655c")
	elif h < 1.2:
		c = Color("#d9c98f")
	elif up < 0.78:
		c = Color("#8a8379")
	elif _is_path(x, z):
		c = Color("#b39463")
	else:
		c = Color("#7cc061").lerp(Color("#3f8a4a"), clampf((h - 2.0) / 22.0, 0.0, 1.0))
	if h > 27.0:
		c = c.lerp(Color("#a49c8f"), 0.45)
	var jitter := _detail.get_noise_2d(x, z) * 0.06
	return Color(c.r + jitter, c.g + jitter, c.b + jitter)


func _is_path(x: float, z: float) -> bool:
	var d := Vector2(x, z).length()
	if d < 9.0:
		return true
	return d < 42.0 and (absf(x) < 2.5 or absf(z) < 2.5)
