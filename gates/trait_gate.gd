class_name TraitGate
extends Node3D
## Blocks a passage unless the player's personality allows it. When the
## trait is out of range, an invisible wall stays up and the character says
## why they won't go in. The wall faces +X (approach from +X).

var trait_name := "courage"
var min_value := Personality.MIN_VALUE
var max_value := Personality.MAX_VALUE
var refusal_line := "I don't want to go in there."
var width := 8.0
var height := 5.0
var _wall_shape: CollisionShape3D
var _cooldown := 0.0


func _ready() -> void:
	var wall := StaticBody3D.new()
	_wall_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, height, width)
	_wall_shape.shape = box
	_wall_shape.position.y = height / 2.0
	wall.add_child(_wall_shape)
	add_child(wall)

	var sensor := Area3D.new()
	var sensor_col := CollisionShape3D.new()
	var sensor_box := BoxShape3D.new()
	sensor_box.size = Vector3(4.0, height, width + 2.0)
	sensor_col.shape = sensor_box
	sensor_col.position = Vector3(2.5, height / 2.0, 0)
	sensor.add_child(sensor_col)
	sensor.body_entered.connect(_on_body_entered)
	add_child(sensor)
	_set_open(_allowed())


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func _allowed() -> bool:
	return GameState.personality.meets(trait_name, min_value, max_value)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var allowed := _allowed()
	_set_open(allowed)
	if not allowed and _cooldown <= 0.0:
		_cooldown = 3.0
		Events.player_say.emit(refusal_line)
		Events.toast.emit("(Your %s holds you back.)" % trait_name.capitalize())


func _set_open(open: bool) -> void:
	_wall_shape.set_deferred("disabled", open)
