class_name Slime
extends CharacterBody3D
## Hopping slime: wanders near home, chases the player when close, deals
## contact damage, drops loot from a table on death.

const GRAVITY := 22.0
const LEASH := 30.0

var display_name := "Slime"
var max_hp := 30
var damage := 8
var aggro_range := 12.0
var color := Color("#6fd36b")
var loot_table := "slime"
var hp := 30
var _home := Vector3.ZERO
var _hop_timer := 0.0
var _attack_cd := 0.0
var _dead := false
var _body: MeshInstance3D
var _material: StandardMaterial3D
var _label: Label3D


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	_home = global_position
	_hop_timer = randf_range(0.5, 2.0)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.55
	col.shape = shape
	col.position.y = 0.55
	add_child(col)

	_body = MeshInstance3D.new()
	_body.mesh = Mats.sphere_mesh(0.6, 14)
	_body.position.y = 0.5
	_body.scale = Vector3(1.0, 0.8, 1.0)
	_material = Mats.toon(Color(color, 0.85)).duplicate()
	_body.material_override = _material
	add_child(_body)
	for side in [-1.0, 1.0]:
		Mats.sphere(_body, 0.08, Color("#1b1b24"), Vector3(0.2 * side, 0.15, 0.5))

	_label = Mats.label(self, "", Vector3(0, 1.5, 0), 36, Color("#ffd0d0"))
	_label.visible = false


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_hop_timer -= delta
	_attack_cd -= delta
	var player := get_tree().get_first_node_in_group("player") as Player
	var to_player := Vector3.ZERO
	var dist := INF
	if player:
		to_player = player.global_position - global_position
		dist = to_player.length()
	var chasing := dist < aggro_range and _home.distance_to(global_position) < LEASH

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		if _hop_timer <= 0.0:
			_hop(to_player, chasing)
	move_and_slide()

	if player and dist < 1.5 and _attack_cd <= 0.0:
		player.take_hit(damage, global_position)
		_attack_cd = 1.0
	if global_position.y < -30.0:
		queue_free()


func _hop(to_player: Vector3, chasing: bool) -> void:
	var dir: Vector3
	if chasing:
		dir = Vector3(to_player.x, 0.0, to_player.z).normalized()
		_hop_timer = 0.7
	else:
		var to_home := _home - global_position
		to_home.y = 0.0
		dir = to_home.normalized() if to_home.length() > 8.0 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		_hop_timer = randf_range(1.5, 3.5)
	velocity = dir * (5.5 if chasing else 2.5) + Vector3.UP * (5.0 if chasing else 3.5)
	if dir.length() > 0.0:
		rotation.y = atan2(dir.x, dir.z)
	var tween := create_tween()
	_body.scale = Vector3(1.25, 0.55, 1.25)
	tween.tween_property(_body, "scale", Vector3(0.9, 1.0, 0.9), 0.2)
	tween.tween_property(_body, "scale", Vector3(1.0, 0.8, 1.0), 0.3)


func take_damage(amount: int, from_position: Vector3) -> void:
	if _dead:
		return
	hp -= amount
	aggro_range = 25.0
	var push := global_position - from_position
	push.y = 0.0
	velocity = push.normalized() * 6.0 + Vector3.UP * 3.0
	_label.text = "%s  %d/%d" % [display_name, maxi(hp, 0), max_hp]
	_label.visible = true
	_material.emission_enabled = true
	_material.emission = Color.WHITE
	_material.emission_energy_multiplier = 2.0
	create_tween().tween_property(_material, "emission_energy_multiplier", 0.0, 0.25)
	if hp <= 0:
		_die()


func _die() -> void:
	_dead = true
	remove_from_group("enemies")
	collision_layer = 0
	_label.visible = false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	GameState.give_loot(LootTable.roll(ItemDB.loot_tables.get(loot_table, {}), rng))
	GameState.register_kill("slime")
	var tween := create_tween()
	tween.tween_property(_body, "scale", Vector3(1.7, 0.05, 1.7), 0.3)
	tween.tween_callback(queue_free)
