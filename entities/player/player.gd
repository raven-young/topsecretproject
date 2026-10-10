class_name Player
extends CharacterBody3D
## Third-person explorer: movement, camera, swimming, carrying fire,
## interaction and class-based attacks.

const WALK_SPEED := 6.0
const SPRINT_SPEED := 10.0
const SWIM_SPEED := 3.5
const JUMP_VELOCITY := 9.0
const GRAVITY := 22.0
const MAX_STAMINA := 100.0
const WATER_LEVEL := 0.0
const INTERACT_RANGE := 2.8
const MOUSE_SENSITIVITY := 0.003
const FLAME_DURATION := 60.0
const RESPAWN_POINT := Vector3(0, 4, 6)
const ATTACK_COOLDOWNS := {"fighter": 0.45, "mage": 0.7, "ranger": 0.55}

var model: CharacterModel
var stamina := MAX_STAMINA
var flame_time := 0.0
var swimming := false
var _yaw: Node3D
var _arm: SpringArm3D
var _camera: Camera3D
var _lantern: OmniLight3D
var _flame: Node3D
var _attack_cd := 0.0
var _hurt_cd := 0.0
var _focus: Node = null
var _prompt := ""
var _safe_position := RESPAWN_POINT
var _safe_timer := 0.0


func _ready() -> void:
	add_to_group("player")
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	col.shape = capsule
	col.position.y = 0.9
	add_child(col)
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.5

	model = CharacterModel.new()
	model.appearance = GameState.profile.appearance
	model.job = GameState.profile.job
	add_child(model)
	model.set_weapon(GameState.equipment.slots["weapon"])

	_build_camera()
	_lantern = Mats.light(self, Color("#ffd9a0"), 1.4, 9.0, Vector3(0, 2.2, 0.3))
	_lantern.visible = false
	_flame = Node3D.new()
	_flame.position = Vector3(0.45, 1.3, 0.25)
	model.add_child(_flame)
	Mats.sphere(_flame, 0.12, Color("#ff8a2a"), Vector3.ZERO, 4.0)
	Mats.light(_flame, Color("#ff9a3c"), 1.5, 6.0)
	_flame.visible = false

	_safe_position = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Events.equipment_changed.connect(func(): model.set_weapon(GameState.equipment.slots["weapon"]))
	Events.player_died.connect(_on_died)
	Events.cave_entered.connect(func(inside: bool): _lantern.visible = inside)


func _build_camera() -> void:
	_yaw = Node3D.new()
	_yaw.position.y = 1.6
	add_child(_yaw)
	_arm = SpringArm3D.new()
	_arm.spring_length = 5.0
	_arm.margin = 0.3
	_arm.rotation.x = -0.35
	_arm.add_excluded_object(get_rid())
	_yaw.add_child(_arm)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 70.0
	_arm.add_child(_camera)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		_arm.rotation.x = clampf(_arm.rotation.x - event.relative.y * MOUSE_SENSITIVITY, -1.2, 0.45)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("quick_save"):
		SaveSystem.save_game()


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_hurt_cd = maxf(0.0, _hurt_cd - delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := _yaw.global_basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	dir = dir.normalized() * minf(input.length(), 1.0)

	swimming = global_position.y < WATER_LEVEL - 1.1 or (swimming and global_position.y < WATER_LEVEL - 0.6 and not is_on_floor())
	var sprinting := Input.is_action_pressed("sprint") and dir.length() > 0.1 and stamina > 0.0 and not swimming
	var speed := SWIM_SPEED if swimming else (SPRINT_SPEED if sprinting else WALK_SPEED)
	var accel := 1.0 - exp(-12.0 * delta)
	velocity.x = lerpf(velocity.x, dir.x * speed, accel)
	velocity.z = lerpf(velocity.z, dir.z * speed, accel)

	if swimming:
		var float_speed := (WATER_LEVEL - 1.0 - global_position.y) * 4.0
		velocity.y = lerpf(velocity.y, float_speed, 1.0 - exp(-4.0 * delta))
		if Input.is_action_just_pressed("jump"):
			velocity.y = 5.0
		stamina -= 6.0 * delta
		if flame_time > 0.0:
			_extinguish("The water put out my flame...")
		if stamina <= 0.0:
			_rescue("Too tired to keep swimming... I washed back ashore.")
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		elif Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
		if sprinting:
			stamina -= 25.0 * delta
		elif is_on_floor():
			stamina += 20.0 * delta
	stamina = clampf(stamina, 0.0, MAX_STAMINA)

	move_and_slide()

	if dir.length() > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-12.0 * delta))
	model.animate(Vector2(velocity.x, velocity.z).length(), delta)

	_safe_timer -= delta
	if _safe_timer <= 0.0 and is_on_floor() and not swimming and global_position.y > 0.3:
		_safe_position = global_position
		_safe_timer = 0.5
	if global_position.y < -40.0:
		_rescue("Whoa, that was a long fall...")
	GameState.player_position = global_position

	_update_focus()
	if Input.is_action_just_pressed("interact") and _focus:
		_focus.interact(self)
	if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0 and not swimming:
		_attack()


func _process(delta: float) -> void:
	if flame_time > 0.0:
		flame_time -= delta
		if flame_time <= 0.0:
			_extinguish("Oh no, the flame went out...")


# --- Interaction ------------------------------------------------------------------

func _update_focus() -> void:
	var best: Node = null
	var best_dist := INTERACT_RANGE
	var best_prompt := ""
	for node in get_tree().get_nodes_in_group("interactable"):
		var dist := global_position.distance_to(node.global_position)
		if dist < best_dist:
			var prompt: String = node.get_prompt()
			if prompt != "":
				best = node
				best_dist = dist
				best_prompt = prompt
	_focus = best
	var text := "[E] " + best_prompt if best else ""
	if text != _prompt:
		_prompt = text
		Events.interaction_prompt.emit(text)


func carry_flame() -> void:
	if flame_time <= 0.0:
		Events.player_say.emit("I'd better hurry before this flame dies out.")
	flame_time = FLAME_DURATION
	_flame.visible = true


func _extinguish(line: String) -> void:
	flame_time = 0.0
	_flame.visible = false
	Events.player_say.emit(line)


# --- Combat -----------------------------------------------------------------------

func _attack() -> void:
	var job := GameState.profile.job
	_attack_cd = ATTACK_COOLDOWNS.get(job, 0.5)
	var aim := _aim_direction()
	model.rotation.y = atan2(aim.x, aim.z)
	model.play_attack(job != "fighter")
	match job:
		"fighter":
			_melee()
		"mage":
			_shoot(aim, 22.0, 0.0, "fire")
		"ranger":
			_shoot(aim, 38.0, 4.0, "none")


func _aim_direction() -> Vector3:
	var origin := _camera.global_position
	var forward := -_camera.global_basis.z
	var target := origin + forward * 60.0
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		target = hit["position"]
	var to_target := target - (global_position + Vector3.UP * 1.3)
	return to_target.normalized() if to_target.length() > 1.0 else forward


func _melee() -> void:
	var facing := Vector3(sin(model.rotation.y), 0.0, cos(model.rotation.y))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		if to_enemy.length() < 2.6 and facing.dot(to_enemy.normalized()) > 0.3:
			enemy.take_damage(GameState.attack_power(), global_position)


func _shoot(aim: Vector3, speed: float, gravity: float, element: String) -> void:
	var bolt := Projectile.new().setup(aim, speed, GameState.attack_power(), element, gravity, self)
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector3.UP * 1.3 + aim * 0.6


func take_hit(amount: int, from_position: Vector3) -> void:
	if _hurt_cd > 0.0 or GameState.hp <= 0:
		return
	_hurt_cd = 0.6
	var push := global_position - from_position
	push.y = 0.0
	velocity = push.normalized() * 8.0 + Vector3.UP * 4.0
	model.pop()
	GameState.damage_player(amount)


func _on_died() -> void:
	var lost := GameState.inventory.gold / 10
	if lost > 0:
		GameState.add_gold(-lost)
	GameState.full_heal()
	global_position = RESPAWN_POINT
	velocity = Vector3.ZERO
	Events.cave_entered.emit(false)
	Events.player_say.emit("Ugh... the villagers must have carried me home.")


func _rescue(line: String) -> void:
	global_position = _safe_position + Vector3.UP * 0.5
	velocity = Vector3.ZERO
	stamina = MAX_STAMINA
	swimming = false
	Events.player_say.emit(line)
