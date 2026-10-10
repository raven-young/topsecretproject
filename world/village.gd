class_name Village
extends RefCounted
## Brightvale: houses around a plaza, a well, a market stall, a campfire,
## lanterns and a fence with four gates. Returns anchor points the world uses
## to place interactive things.

const FENCE_RADIUS := 36.0
const HOUSES := [
	{"pos": Vector2(-14, -12), "wall": "#e8dcc2", "roof": "#b5523b"},
	{"pos": Vector2(14, -13), "wall": "#dfe6e8", "roof": "#4f6d8f"},
	{"pos": Vector2(-16, 10), "wall": "#efe2c9", "roof": "#7a9a4a"},
	{"pos": Vector2(16, 12), "wall": "#e8d6c9", "roof": "#b5523b"},
]
const HOLLIS_HOUSE := Vector2(0, -24)


static func build(parent: Node3D, terrain: Terrain) -> Dictionary:
	var root := Node3D.new()
	root.name = "Village"
	parent.add_child(root)
	var y := terrain.height_at(0, 0)

	for house in HOUSES:
		var p: Vector2 = house["pos"]
		_house(root, Vector3(p.x, y, p.y), Color(house["wall"]), Color(house["roof"]), false)
	var hollis := _house(root, Vector3(HOLLIS_HOUSE.x, y, HOLLIS_HOUSE.y), Color("#d9c7a6"), Color("#6d4c8f"), true)

	_well(root, Vector3(5.5, y, 1.5))
	_stall(root, Vector3(-8, y, 6.5))
	for p in [Vector2(25, 3.2), Vector2(-25, 3.2), Vector2(3.2, 25), Vector2(3.2, -16)]:
		_lantern(root, Vector3(p.x, y, p.y))
	_fence(root, terrain)

	return {
		"campfire": Vector3(-3, y, -1),
		"hollis_chest": hollis.to_global(Vector3(2.2, 0.06, -1.8)),
		"hollis_chest_yaw": hollis.rotation.y,
	}


static func _house(parent: Node3D, pos: Vector3, wall: Color, roof: Color, enterable: bool) -> Node3D:
	const W := 7.0
	const D := 6.0
	const H := 3.6
	var house := Node3D.new()
	house.position = pos
	house.rotation.y = atan2(-pos.x, -pos.z)
	parent.add_child(house)
	var trim := wall.darkened(0.35)
	if enterable:
		var seg := (W - 1.8) / 2.0
		Mats.box(house, Vector3(W, H, 0.3), wall, Vector3(0, H / 2.0, -D / 2.0), Vector3.ZERO, true)
		Mats.box(house, Vector3(0.3, H, D), wall, Vector3(-W / 2.0, H / 2.0, 0), Vector3.ZERO, true)
		Mats.box(house, Vector3(0.3, H, D), wall, Vector3(W / 2.0, H / 2.0, 0), Vector3.ZERO, true)
		Mats.box(house, Vector3(seg, H, 0.3), wall, Vector3(-(0.9 + seg / 2.0), H / 2.0, D / 2.0), Vector3.ZERO, true)
		Mats.box(house, Vector3(seg, H, 0.3), wall, Vector3(0.9 + seg / 2.0, H / 2.0, D / 2.0), Vector3.ZERO, true)
		Mats.box(house, Vector3(1.8, H - 2.4, 0.3), wall, Vector3(0, 2.4 + (H - 2.4) / 2.0, D / 2.0), Vector3.ZERO, true)
		Mats.box(house, Vector3(W - 0.4, 0.06, D - 0.4), Color("#8b6a45"), Vector3(0, 0.03, 0))
		Mats.box(house, Vector3(W, 0.2, D), wall.darkened(0.1), Vector3(0, H, 0))
		Mats.box(house, Vector3(1.2, 0.5, 2.2), Color("#a8553f"), Vector3(-2.3, 0.25, -1.6), Vector3.ZERO, true)
		Mats.box(house, Vector3(1.2, 0.8, 0.9), Color("#7a5230"), Vector3(1.5, 0.4, 1.0), Vector3.ZERO, true)
		Mats.light(house, Color("#ffcf8a"), 1.2, 6.0, Vector3(0, 2.6, 0))
	else:
		Mats.box(house, Vector3(W, H, D), wall, Vector3(0, H / 2.0, 0), Vector3.ZERO, true)
		Mats.box(house, Vector3(1.2, 2.2, 0.1), Color("#6b4a2b"), Vector3(0, 1.1, D / 2.0 + 0.05))
		for x in [-2.2, 2.2]:
			Mats.box(house, Vector3(0.9, 0.9, 0.1), Color("#ffe39a"), Vector3(x, 2.0, D / 2.0 + 0.05)).material_override = Mats.toon(Color("#ffe39a"), 0.8)
	for x in [-W / 2.0, W / 2.0]:
		Mats.box(house, Vector3(0.25, H, 0.25), trim, Vector3(x, H / 2.0, D / 2.0))
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(W + 0.8, 2.4, D + 0.8)
	Mats.mesh(house, roof_mesh, roof, Vector3(0, H + 1.2, 0))
	Mats.box(house, Vector3(0.6, 1.4, 0.6), Color("#8c877d"), Vector3(W / 4.0, H + 1.8, -D / 4.0))
	return house


static func _well(parent: Node3D, pos: Vector3) -> void:
	var well := Node3D.new()
	well.position = pos
	parent.add_child(well)
	Mats.cylinder(well, 1.1, 0.9, Color("#8c877d"), Vector3(0, 0.45, 0), true)
	Mats.cylinder(well, 0.85, 0.05, Color("#3d7fb8"), Vector3(0, 0.8, 0))
	for x in [-0.95, 0.95]:
		Mats.box(well, Vector3(0.15, 2.2, 0.15), Color("#6b4a2b"), Vector3(x, 1.1, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(2.6, 0.8, 1.6)
	Mats.mesh(well, roof, Color("#b5523b"), Vector3(0, 2.5, 0))


static func _stall(parent: Node3D, pos: Vector3) -> void:
	var stall := Node3D.new()
	stall.position = pos
	parent.add_child(stall)
	Mats.box(stall, Vector3(3.0, 1.0, 1.2), Color("#8b5a2b"), Vector3(0, 0.5, 0), Vector3.ZERO, true)
	for x in [-1.4, 1.4]:
		Mats.box(stall, Vector3(0.12, 2.6, 0.12), Color("#6b4a2b"), Vector3(x, 1.3, 0.8))
	for i in 4:
		Mats.box(stall, Vector3(0.85, 0.12, 2.2), Color("#d9483b") if i % 2 == 0 else Color("#f4efe6"), Vector3(-1.275 + i * 0.85, 2.6, 0.5))
	Mats.sphere(stall, 0.15, Color("#e9b949"), Vector3(-0.8, 1.15, 0))
	Mats.sphere(stall, 0.12, Color("#6be4ff"), Vector3(0.2, 1.12, 0.1), 1.5)
	Mats.box(stall, Vector3(0.4, 0.3, 0.3), Color("#7a9a4a"), Vector3(0.9, 1.15, -0.1))


static func _lantern(parent: Node3D, pos: Vector3) -> void:
	Mats.box(parent, Vector3(0.15, 2.6, 0.15), Color("#3b2a1e"), pos + Vector3(0, 1.3, 0), Vector3.ZERO, true)
	Mats.sphere(parent, 0.22, Color("#ffd27a"), pos + Vector3(0, 2.75, 0), 2.5)
	Mats.light(parent, Color("#ffc870"), 1.0, 7.0, pos + Vector3(0, 2.6, 0))


static func _fence(parent: Node3D, terrain: Terrain) -> void:
	var gates := [0.0, PI / 2.0, PI, -PI / 2.0]
	var post_count := 72
	var wood := Color("#8a6a45")
	var prev = null
	for i in post_count + 1:
		var angle := TAU * i / post_count
		var in_gap := false
		for g in gates:
			if absf(angle_difference(angle, g)) < 0.12:
				in_gap = true
		if in_gap:
			prev = null
			continue
		var x := cos(angle) * FENCE_RADIUS
		var z := sin(angle) * FENCE_RADIUS
		var post := Vector3(x, terrain.height_at(x, z), z)
		Mats.box(parent, Vector3(0.2, 1.2, 0.2), wood, post + Vector3(0, 0.6, 0))
		if prev != null:
			var mid: Vector3 = (post + prev) / 2.0
			var length: float = post.distance_to(prev)
			var yaw := atan2(post.x - prev.x, post.z - prev.z)
			Mats.box(parent, Vector3(0.12, 0.12, length), wood, mid + Vector3(0, 0.9, 0), Vector3(0, yaw, 0), true)
			Mats.box(parent, Vector3(0.12, 0.12, length), wood, mid + Vector3(0, 0.45, 0), Vector3(0, yaw, 0))
		prev = post
	var east := Vector3(FENCE_RADIUS, terrain.height_at(FENCE_RADIUS, 0), 0)
	for z in [-2.6, 2.6]:
		Mats.box(parent, Vector3(0.35, 3.6, 0.35), wood.darkened(0.2), east + Vector3(0, 1.8, z), Vector3.ZERO, true)
	Mats.box(parent, Vector3(0.4, 0.4, 5.8), wood.darkened(0.2), east + Vector3(0, 3.6, 0))
	Mats.label(parent, "Brightvale", east + Vector3(0.3, 4.2, 0), 96, Color("#ffe7a8")).billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
