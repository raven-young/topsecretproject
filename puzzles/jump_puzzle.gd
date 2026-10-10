class_name JumpPuzzle
extends Puzzle
## The Sky Pillar: a spiral of floating platforms around a stone pillar.
## Reaching the top solves it. Origin is the pillar's base at water level.

const RADIUS := 8.0
const STEP_ANGLE := 0.61
const STEP_HEIGHT := 1.35
const COUNT := 14
const PILLAR_TOP := 20.0
const MOVING := {5: Vector3(0, 1.0, 0), 10: Vector3(0, 0, 0)}

var _stone := Color("#a39e93")


func _ready() -> void:
	super()
	Mats.cylinder(self, 3.0, PILLAR_TOP + 14.0, _stone.darkened(0.15), Vector3(0, (PILLAR_TOP - 14.0) / 2.0, 0), true)
	for i in COUNT:
		var pos := platform_position(i)
		if MOVING.has(i):
			var mover := MovingPlatform.new()
			var radial := Vector3(pos.x, 0, pos.z).normalized() * 1.8
			mover.offset = MOVING[i] if MOVING[i] != Vector3.ZERO else radial
			mover.period = 3.5
			mover.position = pos
			add_child(mover)
		else:
			Mats.box(self, Vector3(3, 0.5, 3), _stone, pos, Vector3(0, -i * STEP_ANGLE, 0), true)

	var goal := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.0
	shape.height = 2.0
	col.shape = shape
	goal.add_child(col)
	goal.position.y = PILLAR_TOP + 1.0
	goal.body_entered.connect(_on_goal_entered)
	add_child(goal)


func platform_position(i: int) -> Vector3:
	var angle := i * STEP_ANGLE
	var r := RADIUS if i < COUNT - 1 else 5.0
	return Vector3(cos(angle) * r, 1.0 + i * STEP_HEIGHT, sin(angle) * r)


func _on_goal_entered(body: Node) -> void:
	if body.is_in_group("player") and not is_solved:
		mark_solved()
		GameState.change_trait("courage", 1, "Climbed to the top of the Sky Pillar")
