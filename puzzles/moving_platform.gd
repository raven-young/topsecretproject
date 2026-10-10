class_name MovingPlatform
extends AnimatableBody3D
## Platform oscillating around its start position along `offset`.

var offset := Vector3(0, 1, 0)
var period := 4.0
var size := Vector3(3, 0.5, 3)
var color := Color("#a39e93")
var _base := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	_base = position
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
	Mats.box(self, size, color)
	Mats.box(self, Vector3(size.x * 0.6, 0.05, size.z * 0.6), Color("#6be4ff"), Vector3(0, size.y / 2.0, 0)).material_override = Mats.toon(Color("#6be4ff"), 1.0)


func _physics_process(delta: float) -> void:
	_time += delta
	position = _base + offset * sin(_time * TAU / period)
