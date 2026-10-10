class_name Projectile
extends Area3D
## Fire bolt (mage) or arrow (ranger). Fire bolts also ignite anything in the
## "flammable" group, which is how mages can solve brazier puzzles from afar.

var velocity := Vector3.ZERO
var damage := 10
var element := "none"
var gravity_amount := 0.0
var shooter: Node = null
var _life := 3.0


func setup(direction: Vector3, speed: float, hit_damage: int, hit_element: String, gravity: float, from_shooter: Node) -> Projectile:
	velocity = direction * speed
	damage = hit_damage
	element = hit_element
	gravity_amount = gravity
	shooter = from_shooter
	return self


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	col.shape = shape
	add_child(col)
	if element == "fire":
		Mats.sphere(self, 0.2, Color("#ff8a2a"), Vector3.ZERO, 4.0)
		Mats.light(self, Color("#ff9a3c"), 2.0, 5.0)
	else:
		var shaft := Mats.box(self, Vector3(0.04, 0.04, 0.8), Color("#d9c7a3"))
		shaft.position.z = -0.2
		Mats.box(self, Vector3(0.08, 0.08, 0.12), Color("#8a8f99"), Vector3(0, 0, -0.62))
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	velocity.y -= gravity_amount * delta
	global_position += velocity * delta
	if velocity.length_squared() > 0.01 and absf(velocity.normalized().y) < 0.99:
		look_at(global_position + velocity, Vector3.UP)
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position - velocity.normalized())
	queue_free()


func _on_area_entered(area: Area3D) -> void:
	if element == "fire" and area.is_in_group("flammable"):
		area.get_parent().ignite()
		queue_free()
