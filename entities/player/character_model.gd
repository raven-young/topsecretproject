class_name CharacterModel
extends Node3D
## Low-poly humanoid built from primitives so every appearance option can be
## swapped at runtime. Faces +Z. Used by the player, NPCs and the creator.

const HAIR_STYLES := ["Short", "Spiky", "Long", "Ponytail", "Bald"]
const FACES := ["Cheerful", "Serious", "Sleepy"]
const BODY_TYPES := ["Slim", "Average", "Sturdy"]
const SKIN_TONES := ["#f7dcc8", "#e9b993", "#c98c5c", "#94603d", "#5c3a26"]
const HAIR_COLORS := ["#2a1d15", "#6b3e1f", "#d8a645", "#c4432f", "#ece6da", "#4a6fd6", "#e27bb6"]
const JOB_COLORS := {"fighter": "#b8433a", "mage": "#4c4fb8", "ranger": "#3f8a4a"}
const BODY_WIDTH := [0.85, 1.0, 1.25]

var appearance: Dictionary = {"hair_style": 0, "hair_color": 0, "face": 0, "body": 1, "skin": 1}
var job := "fighter"
## Overrides the job colour when set (NPC clothing).
var outfit_color := Color(0, 0, 0, 0)

var _root: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _weapon_mount: Node3D
var _weapon_id := ""
var _walk_time := 0.0
var _attacking := false


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	if _root:
		_root.free()
	_root = Node3D.new()
	add_child(_root)
	var skin := Color(SKIN_TONES[_index("skin", SKIN_TONES.size())])
	var hair := Color(HAIR_COLORS[_index("hair_color", HAIR_COLORS.size())])
	var outfit := outfit_color if outfit_color.a > 0.0 else Color(JOB_COLORS.get(job, "#777777"))
	var width: float = BODY_WIDTH[_index("body", BODY_WIDTH.size())]

	_leg_l = _limb(Vector3(0.13 * width, 0.82, 0), 0.12, 0.8, outfit.darkened(0.55))
	_leg_r = _limb(Vector3(-0.13 * width, 0.82, 0), 0.12, 0.8, outfit.darkened(0.55))
	for leg in [_leg_l, _leg_r]:
		Mats.box(leg, Vector3(0.2, 0.12, 0.3), Color("#3b2a1e"), Vector3(0, -0.78, 0.04))

	var torso := CapsuleMesh.new()
	torso.radius = 0.26
	torso.height = 0.8
	Mats.mesh(_root, torso, outfit, Vector3(0, 1.16, 0)).scale = Vector3(width, 1.0, width * 0.75)
	Mats.cylinder(_root, 0.27 * width, 0.08, Color("#3b2a1e"), Vector3(0, 0.92, 0))
	if job == "mage" and outfit_color.a == 0.0:
		Mats.cylinder(_root, 0.44 * width, 0.62, outfit.darkened(0.15), Vector3(0, 0.62, 0), false, 0.27 * width)

	_arm_l = _limb(Vector3(0.34 * width, 1.44, 0), 0.075, 0.62, outfit, skin)
	_arm_r = _limb(Vector3(-0.34 * width, 1.44, 0), 0.075, 0.62, outfit, skin)
	_weapon_mount = Node3D.new()
	_weapon_mount.position = Vector3(0, -0.62, 0.05)
	_arm_r.add_child(_weapon_mount)

	Mats.sphere(_root, 0.22, skin, Vector3(0, 1.74, 0))
	_build_face(hair)
	_build_hair(hair)
	set_weapon(_weapon_id)


func _index(key: String, size: int) -> int:
	return clampi(int(appearance.get(key, 0)), 0, size - 1)


func _limb(pivot_pos: Vector3, radius: float, length: float, color: Color, hand_color := Color(0, 0, 0, 0)) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	_root.add_child(pivot)
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = length
	Mats.mesh(pivot, cap, color, Vector3(0, -length / 2.0, 0))
	if hand_color.a > 0.0:
		Mats.sphere(pivot, radius * 1.2, hand_color, Vector3(0, -length, 0))
	return pivot


func _build_face(hair: Color) -> void:
	var face := _index("face", FACES.size())
	for side in [-1.0, 1.0]:
		var eye := Mats.sphere(_root, 0.035, Color("#1b1b24"), Vector3(0.075 * side, 1.74, 0.195))
		if face == 2:
			eye.scale = Vector3(1.2, 0.3, 1.0)
		if face == 1:
			Mats.box(_root, Vector3(0.09, 0.022, 0.02), hair.darkened(0.3), Vector3(0.075 * side, 1.785, 0.205), Vector3(0, 0, -0.3 * side))
		if face == 0:
			Mats.sphere(_root, 0.035, Color("#f29c9c"), Vector3(0.125 * side, 1.69, 0.165)).scale = Vector3(1, 0.6, 0.4)
	var mouth_width: float = [0.1, 0.06, 0.05][face]
	Mats.box(_root, Vector3(mouth_width, 0.022, 0.02), Color("#8c3b3b"), Vector3(0, 1.655, 0.205))


func _build_hair(hair: Color) -> void:
	var style := _index("hair_style", HAIR_STYLES.size())
	if style == 4:
		return
	var cap := SphereMesh.new()
	cap.radius = 0.235
	cap.height = 0.235
	cap.is_hemisphere = true
	cap.radial_segments = 12
	cap.rings = 4
	Mats.mesh(_root, cap, hair, Vector3(0, 1.79, -0.005)).scale = Vector3(1.04, 1.0, 1.06)
	Mats.sphere(_root, 0.225, hair, Vector3(0, 1.74, -0.045)).scale = Vector3(1.03, 0.92, 1.0)
	match style:
		1:
			for i in 6:
				var angle := TAU * i / 6.0
				var spike := Mats.mesh(_root, Mats.cone_mesh(0.07, 0.24, 6), hair, Vector3(cos(angle) * 0.12, 1.98, sin(angle) * 0.12 - 0.03))
				spike.rotation = Vector3(sin(angle) * 0.6, 0, -cos(angle) * 0.6)
		2:
			Mats.box(_root, Vector3(0.44, 0.55, 0.13), hair, Vector3(0, 1.55, -0.16))
		3:
			Mats.sphere(_root, 0.09, hair, Vector3(0, 1.8, -0.26))
			var tail := CapsuleMesh.new()
			tail.radius = 0.06
			tail.height = 0.38
			Mats.mesh(_root, tail, hair, Vector3(0, 1.6, -0.3))


func set_weapon(item_id: String) -> void:
	_weapon_id = item_id
	if _weapon_mount == null:
		return
	for child in _weapon_mount.get_children():
		child.free()
	if item_id == "":
		return
	var upgraded := item_id.begins_with("iron") or item_id.begins_with("crystal")
	var wood := Color("#7a5230")
	if "sword" in item_id:
		var blade := Color("#c9d1d9") if upgraded else Color("#b08a5a")
		Mats.box(_weapon_mount, Vector3(0.05, 0.08, 0.8), blade, Vector3(0, 0, 0.5))
		Mats.box(_weapon_mount, Vector3(0.24, 0.05, 0.05), Color("#5a4632"), Vector3(0, 0, 0.1))
	elif "staff" in item_id:
		Mats.cylinder(_weapon_mount, 0.03, 1.5, wood, Vector3(0, 0.35, 0))
		var orb := Color("#b06cff") if upgraded else Color("#ff9a3c")
		Mats.sphere(_weapon_mount, 0.09, orb, Vector3(0, 1.12, 0), 2.0)
	elif "bow" in item_id:
		var limb := Color("#8a8f99") if upgraded else wood
		Mats.box(_weapon_mount, Vector3(0.04, 0.3, 0.05), limb, Vector3(0, 0, 0.12))
		Mats.box(_weapon_mount, Vector3(0.04, 0.45, 0.05), limb, Vector3(0, 0.34, 0.06), Vector3(0.35, 0, 0))
		Mats.box(_weapon_mount, Vector3(0.04, 0.45, 0.05), limb, Vector3(0, -0.34, 0.06), Vector3(-0.35, 0, 0))
		Mats.box(_weapon_mount, Vector3(0.01, 1.05, 0.01), Color("#eeeeee"), Vector3(0, 0, -0.04))


## Simple procedural walk cycle. `speed` is horizontal speed in m/s.
func animate(speed: float, delta: float) -> void:
	if _leg_l == null:
		return
	var amount := clampf(speed / 6.0, 0.0, 1.4)
	_walk_time += delta * (3.0 + speed * 1.3)
	var swing := sin(_walk_time) * 0.7 * amount
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.8
	if not _attacking:
		_arm_r.rotation.x = swing * 0.8
	_root.position.y = absf(sin(_walk_time)) * 0.05 * amount


func play_attack(ranged: bool) -> void:
	if _arm_r == null:
		return
	_attacking = true
	var tween := create_tween()
	if ranged:
		tween.tween_property(_arm_r, "rotation:x", -1.55, 0.08)
		tween.tween_interval(0.15)
	else:
		_arm_r.rotation.x = -2.6
		tween.tween_property(_arm_r, "rotation:x", -0.3, 0.16).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_arm_r, "rotation:x", 0.0, 0.18)
	tween.tween_callback(func(): _attacking = false)


func pop() -> void:
	var tween := create_tween()
	scale = Vector3(1.15, 0.85, 1.15)
	tween.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC)
