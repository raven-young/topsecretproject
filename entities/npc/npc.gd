class_name NPC
extends StaticBody3D
## A villager (or animal) you can talk to. Conversation content lives in
## data/dialogue/<dialogue_id>.json.

var npc_name := "Villager"
var dialogue_id := ""
var appearance: Dictionary = {}
var outfit_color := Color("#8a6d4b")
var body_scale := 1.0
var is_cat := false
var _model: Node3D


func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4 * body_scale
	shape.height = maxf(1.8 * body_scale, shape.radius * 2.0)
	col.shape = shape
	col.position.y = shape.height / 2.0
	add_child(col)
	if is_cat:
		_model = _build_cat()
	else:
		var character := CharacterModel.new()
		character.appearance = appearance
		character.outfit_color = outfit_color
		_model = character
		add_child(character)
	_model.scale = Vector3.ONE * body_scale
	Mats.label(self, npc_name, Vector3(0, 2.15 * body_scale + 0.2, 0), 40, Color("#ffe7a8"))


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(global_position) < 6.0:
		var to_player := player.global_position - global_position
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(to_player.x, to_player.z), 1.0 - exp(-5.0 * delta))


func face_towards(point: Vector3) -> void:
	var to_point := point - global_position
	if _model:
		_model.rotation.y = atan2(to_point.x, to_point.z)


func get_prompt() -> String:
	return ("Pet %s" if is_cat else "Talk to %s") % npc_name


func interact(_player: Node) -> void:
	Events.dialogue_requested.emit(dialogue_id, npc_name)


func _build_cat() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var fur := Color("#e8913a")
	var body := CapsuleMesh.new()
	body.radius = 0.16
	body.height = 0.6
	Mats.mesh(root, body, fur, Vector3(0, 0.25, 0)).rotation.x = PI / 2.0
	Mats.sphere(root, 0.15, fur, Vector3(0, 0.42, 0.3))
	for side in [-1.0, 1.0]:
		Mats.mesh(root, Mats.cone_mesh(0.05, 0.12, 4), fur, Vector3(0.08 * side, 0.58, 0.3))
		Mats.sphere(root, 0.025, Color("#1b1b24"), Vector3(0.06 * side, 0.45, 0.43))
	var tail := Mats.cylinder(root, 0.035, 0.45, Color("#ffffff"), Vector3(0, 0.42, -0.38))
	tail.rotation.x = -0.6
	for x in [-0.08, 0.08]:
		for z in [-0.18, 0.18]:
			Mats.cylinder(root, 0.04, 0.2, fur, Vector3(x, 0.1, z))
	return root
