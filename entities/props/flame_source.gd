class_name FlameSource
extends StaticBody3D
## A fire that never goes out. Interacting lets the player carry its flame.

var prompt := "Take a flame from the fire"
var _light: OmniLight3D
var _flame: MeshInstance3D


func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.7
	shape.height = 0.5
	col.shape = shape
	col.position.y = 0.25
	add_child(col)
	for i in 6:
		var stone := Mats.sphere(self, 0.16, Color("#7d7a73"), Vector3(cos(TAU * i / 6.0) * 0.6, 0.1, sin(TAU * i / 6.0) * 0.6))
		stone.scale = Vector3(1.2, 0.7, 1.0)
	for angle in [0.0, PI / 2.0]:
		var log_mesh := Mats.cylinder(self, 0.08, 0.9, Color("#5a3d22"), Vector3(0, 0.12, 0))
		log_mesh.rotation = Vector3(PI / 2.0, angle, 0)
	_flame = Mats.mesh(self, Mats.cone_mesh(0.3, 0.8, 6), Color("#ff8a2a"), Vector3(0, 0.55, 0), 4.0)
	_light = Mats.light(self, Color("#ff9a3c"), 2.0, 8.0, Vector3(0, 1.0, 0))


func _process(_delta: float) -> void:
	_light.light_energy = 1.8 + randf() * 0.5
	_flame.scale.y = 0.9 + randf() * 0.2


func get_prompt() -> String:
	return prompt


func interact(player: Node) -> void:
	player.carry_flame()
