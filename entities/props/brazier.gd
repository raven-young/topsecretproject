class_name Brazier
extends StaticBody3D
## An ancient brazier. Lit by a carried flame or by a mage's fire bolt.

signal lit

var is_lit := false
var _flame: Node3D


func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 1.3
	col.shape = shape
	col.position.y = 0.65
	add_child(col)
	var stone := Color("#8c877d")
	Mats.cylinder(self, 0.35, 1.0, stone, Vector3(0, 0.5, 0), false, 0.25)
	Mats.cylinder(self, 0.4, 0.3, stone.darkened(0.2), Vector3(0, 1.15, 0), false, 0.6)

	var sensor := Area3D.new()
	sensor.add_to_group("flammable")
	var sensor_col := CollisionShape3D.new()
	var sensor_shape := SphereShape3D.new()
	sensor_shape.radius = 0.9
	sensor_col.shape = sensor_shape
	sensor.add_child(sensor_col)
	sensor.position.y = 1.2
	add_child(sensor)

	_flame = Node3D.new()
	_flame.position.y = 1.45
	add_child(_flame)
	Mats.mesh(_flame, Mats.cone_mesh(0.35, 0.9, 6), Color("#ff8a2a"), Vector3(0, 0.3, 0), 4.0)
	Mats.light(_flame, Color("#ff9a3c"), 2.5, 10.0, Vector3(0, 0.8, 0))
	_flame.visible = is_lit


func get_prompt() -> String:
	if is_lit:
		return ""
	var player := get_tree().get_first_node_in_group("player") as Player
	return "Light the brazier" if player and player.flame_time > 0.0 else "Inspect the brazier"


func interact(player: Node) -> void:
	if is_lit:
		return
	if player.flame_time > 0.0:
		ignite()
	elif GameState.profile.job == "mage":
		Events.player_say.emit("Cold ashes... maybe one of my fire bolts could light it?")
	else:
		Events.player_say.emit("Cold ashes... I'd need a flame to light this.")


func ignite() -> void:
	if is_lit:
		return
	set_lit()
	lit.emit()


func set_lit() -> void:
	is_lit = true
	if _flame:
		_flame.visible = true
