class_name Cave
extends Node3D
## The dark cave at the foot of the western cliff. Origin is the entrance on
## the ground; the tunnel runs toward local -X. Entering darkens the world
## (via Events.cave_entered) and plays a low rumble.

const LENGTH := 26.0
const WIDTH := 8.0
const HEIGHT := 5.0

var _rock := Color("#5d5850")


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var x := 0.0
	while x > -LENGTH:
		for side in [-1.0, 1.0]:
			var pos := Vector3(x - 2.0, (HEIGHT + 3.0) / 2.0 - 2.0, side * (WIDTH / 2.0 + 1.0))
			Mats.box(self, Vector3(4.4, HEIGHT + 3.0, 2.0 + rng.randf() * 0.6), _rock.lightened(rng.randf() * 0.08), pos, Vector3(0, rng.randf_range(-0.08, 0.08), 0), true)
		x -= 4.0
	Mats.box(self, Vector3(2.0, HEIGHT + 3.0, WIDTH + 4.0), _rock, Vector3(-LENGTH - 1.0, (HEIGHT + 3.0) / 2.0 - 2.0, 0), Vector3.ZERO, true)
	Mats.box(self, Vector3(LENGTH + 2.0, 2.5, WIDTH + 5.0), _rock.darkened(0.1), Vector3(-LENGTH / 2.0, HEIGHT + 1.25, 0), Vector3.ZERO, true)

	for i in 10:
		var boulder := Mats.sphere(self, rng.randf_range(2.0, 3.5), _rock.lightened(rng.randf() * 0.1), Vector3(rng.randf_range(-LENGTH, 0), HEIGHT + 2.0, rng.randf_range(-WIDTH / 2.0, WIDTH / 2.0)))
		boulder.scale = Vector3(1.4, 0.7, 1.2)
	for side in [-1.0, 1.0]:
		Mats.sphere(self, 2.4, _rock, Vector3(0.8, 1.6, side * (WIDTH / 2.0 + 1.4))).scale = Vector3(0.9, 1.3, 0.9)
	Mats.box(self, Vector3(2.4, 1.2, WIDTH + 3.0), _rock.darkened(0.15), Vector3(0.6, HEIGHT + 0.3, 0), Vector3(0, 0, 0.12))

	for i in 14:
		var stalactite := Mats.mesh(self, Mats.cone_mesh(0.3, rng.randf_range(0.6, 1.6), 5), _rock.darkened(0.2), Vector3(rng.randf_range(-LENGTH + 1, -2), HEIGHT - 0.5, rng.randf_range(-WIDTH / 2.0 + 0.6, WIDTH / 2.0 - 0.6)))
		stalactite.rotation.x = PI

	for spot in [Vector3(-8, 0, -3.2), Vector3(-15, 0, 3.3), Vector3(-21, 0, -3.0)]:
		for j in 4:
			Mats.sphere(self, rng.randf_range(0.1, 0.22), Color("#6be4ff"), spot + Vector3(rng.randf_range(-0.5, 0.5), 0.15, rng.randf_range(-0.4, 0.4)), 2.5)
		Mats.light(self, Color("#6be4ff"), 0.6, 4.0, spot + Vector3(0, 0.6, 0))
	for j in 6:
		var crystal := Mats.box(self, Vector3(0.25, rng.randf_range(0.6, 1.4), 0.25), Color("#b06cff"), Vector3(-LENGTH + 1.2, 0.4, rng.randf_range(-2.5, 2.5)), Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)))
		crystal.material_override = Mats.toon(Color("#b06cff"), 2.0)

	var veil := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH + 0.5, HEIGHT + 0.5)
	veil.mesh = quad
	var veil_mat := StandardMaterial3D.new()
	veil_mat.albedo_color = Color(0, 0, 0, 0.96)
	veil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veil.material_override = veil_mat
	veil.position = Vector3(-1.2, HEIGHT / 2.0, 0)
	veil.rotation.y = PI / 2.0
	add_child(veil)

	var interior := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(LENGTH - 1.0, HEIGHT, WIDTH)
	col.shape = shape
	col.position = Vector3(-LENGTH / 2.0 - 1.0, HEIGHT / 2.0, 0)
	interior.add_child(col)
	interior.body_entered.connect(_on_interior.bind(true))
	interior.body_exited.connect(_on_interior.bind(false))
	add_child(interior)

	var rumble := AudioStreamPlayer3D.new()
	rumble.stream = _make_rumble()
	rumble.position = Vector3(-LENGTH * 0.7, 2.0, 0)
	rumble.unit_size = 6.0
	rumble.max_distance = 45.0
	rumble.autoplay = true
	add_child(rumble)


func _on_interior(body: Node, inside: bool) -> void:
	if body.is_in_group("player"):
		Events.cave_entered.emit(inside)


## Local points the world uses to place content inside.
func chest_spot() -> Vector3:
	return to_global(Vector3(-LENGTH + 3.0, 0, 0))


func monster_spot() -> Vector3:
	return to_global(Vector3(-14.0, 0.5, 2.0))


func lore_spot() -> Vector3:
	return to_global(Vector3(-4.0, 0, -3.2))


## A few seconds of brown noise with a slow throb: the "something breathing in the deep" sound.
static func _make_rumble() -> AudioStreamWAV:
	var rate := 22050
	var frames := rate * 6
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var brown := 0.0
	for i in frames:
		brown = clampf(brown * 0.995 + rng.randf_range(-1.0, 1.0) * 0.04, -1.0, 1.0)
		var t := float(i) / rate
		var breath := 0.55 + 0.45 * sin(TAU * t / 3.0)
		var growl := sin(TAU * 42.0 * t) * 0.25 * maxf(0.0, sin(TAU * t / 6.0))
		data.encode_s16(i * 2, int(clampf((brown * 2.2 * breath + growl) * 0.5, -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = frames
	return stream
