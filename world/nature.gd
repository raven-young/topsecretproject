class_name Nature
extends RefCounted
## Scatters trees, rocks, flowers and grass with MultiMeshes. Deterministic,
## so the world looks the same every session.


static func populate(parent: Node3D, terrain: Terrain, is_clear: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var body := StaticBody3D.new()
	parent.add_child(body)

	var round_trees: Array[Transform3D] = []
	var pines: Array[Transform3D] = []
	var leaf_colors: Array[Color] = []
	var pine_colors: Array[Color] = []
	var attempts := 0
	while round_trees.size() + pines.size() < 420 and attempts < 6000:
		attempts += 1
		var x := rng.randf_range(-180.0, 180.0)
		var z := rng.randf_range(-180.0, 180.0)
		var h := terrain.height_at(x, z)
		if h < 1.5 or h > 32.0 or terrain.slope_at(x, z) > 0.6 or not is_clear.call(x, z):
			continue
		var s := rng.randf_range(0.8, 1.4)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(x, h, z))
		if h > 14.0 or rng.randf() < 0.35:
			pines.append(xf)
			pine_colors.append(Color("#2f6b45").lightened(rng.randf() * 0.15))
		else:
			round_trees.append(xf)
			leaf_colors.append(Color("#4f9a43").lerp(Color("#8cc152"), rng.randf()))
		var trunk_col := CollisionShape3D.new()
		var trunk_shape := CylinderShape3D.new()
		trunk_shape.radius = 0.35 * s
		trunk_shape.height = 3.0 * s
		trunk_col.shape = trunk_shape
		trunk_col.position = Vector3(x, h + 1.5 * s, z)
		body.add_child(trunk_col)

	var all_trees: Array[Transform3D] = round_trees + pines
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.28
	trunk.height = 2.6
	_multimesh(parent, trunk, all_trees, [], Vector3(0, 1.3, 0), Color("#6b4a2b"))
	var canopy := Mats.sphere_mesh(1.7, 7)
	_multimesh(parent, canopy, round_trees, leaf_colors, Vector3(0, 3.4, 0))
	var pine_cone := Mats.cone_mesh(1.5, 4.0, 7)
	_multimesh(parent, pine_cone, pines, pine_colors, Vector3(0, 3.6, 0))

	var rocks: Array[Transform3D] = []
	attempts = 0
	while rocks.size() < 160 and attempts < 3000:
		attempts += 1
		var x := rng.randf_range(-185.0, 185.0)
		var z := rng.randf_range(-185.0, 185.0)
		var h := terrain.height_at(x, z)
		if h < -1.0 or not is_clear.call(x, z):
			continue
		var size := Vector3(rng.randf_range(0.6, 2.4), rng.randf_range(0.4, 1.6), rng.randf_range(0.6, 2.2))
		var basis := Basis.from_euler(Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.4))
		var xf := Transform3D(basis.scaled(size), Vector3(x, h + size.y * 0.25, z))
		rocks.append(xf)
		var rock_col := CollisionShape3D.new()
		var rock_shape := BoxShape3D.new()
		rock_shape.size = size
		rock_col.shape = rock_shape
		rock_col.transform = Transform3D(basis, xf.origin)
		body.add_child(rock_col)
	var rock_mesh := BoxMesh.new()
	_multimesh(parent, rock_mesh, rocks, [], Vector3.ZERO, Color("#8f8a80"))

	var flowers: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var grass: Array[Transform3D] = []
	var palette := [Color("#f2d24b"), Color("#e8607a"), Color("#f4f0e6"), Color("#8f7bd8"), Color("#f29b49")]
	for i in 4000:
		var x := rng.randf_range(-170.0, 170.0)
		var z := rng.randf_range(-170.0, 170.0)
		var h := terrain.height_at(x, z)
		if h < 1.3 or h > 26.0 or terrain.slope_at(x, z) > 0.5 or not is_clear.call(x, z):
			continue
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), Vector3(x, h, z))
		if i % 3 == 0:
			flowers.append(xf)
			flower_colors.append(palette[rng.randi() % palette.size()])
		else:
			grass.append(xf)
	_multimesh(parent, Mats.sphere_mesh(0.1, 5), flowers, flower_colors, Vector3(0, 0.12, 0))
	_multimesh(parent, Mats.cone_mesh(0.12, 0.5, 3), grass, [], Vector3(0, 0.2, 0), Color("#5aa548"))


static func _multimesh(parent: Node3D, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], offset: Vector3, flat_color := Color.WHITE) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		var xf := transforms[i]
		mm.set_instance_transform(i, Transform3D(xf.basis, xf.origin + xf.basis * offset))
		mm.set_instance_color(i, colors[i] if i < colors.size() else flat_color)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mats.vertex_colored()
	parent.add_child(mmi)
