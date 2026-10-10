extends Node3D
## Builds the vertical-slice island (terrain, village, cave, puzzles, chests,
## NPCs, monsters, lore), then spawns the player and the UI layers.

const VILLAGE_SPAWN := Vector2(0, 6)
const CAVE_ENTRANCE := Vector2(-70, 10)
const FIRE_CAMP := Vector2(62, -50)
const MOCHI_SPOT := Vector2(58, -38)
const HIDDEN_CHEST_COUNT := 5
## Candidate spots for randomly placed chests: cliff plateau, hill slope,
## north woods, beach, lake shore, east meadow, ruins, behind a village house.
const HIDDEN_CHEST_SPOTS := [
	Vector2(-130, 20), Vector2(-120, 112), Vector2(112, -42), Vector2(-20, -120),
	Vector2(0, 150), Vector2(96, 102), Vector2(150, 20), Vector2(60, -140), Vector2(-22, -18),
]
const SLIME_SPAWNS := [
	Vector2(50, 10), Vector2(55, -8), Vector2(62, 30), Vector2(48, -30), Vector2(105, -45),
	Vector2(-45, 45), Vector2(-55, -50), Vector2(25, 95), Vector2(-20, 120), Vector2(130, 10),
]
const NPCS := [
	{"id": "elder", "name": "Elder Bram", "dialogue": "elder", "pos": Vector2(0, -7), "outfit": "#6d4c8f",
		"look": {"hair_style": 4, "hair_color": 4, "face": 1, "body": 1, "skin": 1}},
	{"id": "guard", "name": "Guard Tomas", "dialogue": "guard", "pos": Vector2(33, 2), "outfit": "#7f8a99",
		"look": {"hair_style": 0, "hair_color": 1, "face": 1, "body": 2, "skin": 2}},
	{"id": "lina", "name": "Lina", "dialogue": "lina", "pos": Vector2(10, 7), "outfit": "#e6b84a", "scale": 0.7,
		"look": {"hair_style": 3, "hair_color": 3, "face": 0, "body": 0, "skin": 0}},
	{"id": "pip", "name": "Pip the Merchant", "dialogue": "pip", "pos": Vector2(-8, 7.8), "outfit": "#c96f2e",
		"look": {"hair_style": 1, "hair_color": 2, "face": 0, "body": 2, "skin": 3}},
	{"id": "sela", "name": "Old Sela", "dialogue": "sela", "pos": Vector2(7.5, -0.5), "outfit": "#6b6458",
		"look": {"hair_style": 2, "hair_color": 4, "face": 2, "body": 0, "skin": 4}},
]
const FOG_COLOR := Color("#c9dcef")
const FOG_DENSITY := 0.0025
const SUN_ENERGY := 1.2

var terrain: Terrain
var player: Player
var env: Environment
var sun: DirectionalLight3D
var _npcs: Dictionary = {}
var _mochi: NPC


func _ready() -> void:
	var fresh_start := GameState.player_position == null
	if GameState.profile == null:
		# Launched straight into the world from the editor: use a default hero.
		GameState.new_game(PlayerProfile.new())
	_build_environment()
	terrain = Terrain.new()
	add_child(terrain)
	_build_water()
	Nature.populate(self, terrain, _is_clear)
	var anchors := Village.build(self, terrain)
	_spawn_flame_source(anchors["campfire"], "Take a flame from the campfire")
	_make_chest("hollis_house", "house", anchors["hollis_chest"], anchors["hollis_chest_yaw"], false, "Hollis")
	_build_cave()
	_build_brazier_puzzle()
	_build_sky_pillar()
	_spawn_hidden_chests()
	_spawn_npcs()
	_spawn_monsters()
	_spawn_lore(Vector2(4, -9), "brightvale")
	_spawn_lore(Vector2(-125, 32), "starfall")
	_spawn_player()
	add_child(Hud.new())
	add_child(DialogueBox.new())
	add_child(GameMenu.new())
	Events.cave_entered.connect(_on_cave_entered)
	Events.flag_set.connect(_on_flag_set)
	if fresh_start:
		Events.toast.emit("Welcome to Brightvale, %s!" % GameState.profile.player_name)
		Events.toast.emit("Talk to Elder Bram in the village square.")


func ground(x: float, z: float) -> Vector3:
	return Vector3(x, terrain.height_at(x, z), z)


func _is_clear(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if p.length() < 44.0:
		return false
	if x > -100.0 and x < -60.0 and z > -4.0 and z < 24.0:
		return false
	if p.distance_to(Terrain.HILL_CENTER) < 15.0 or p.distance_to(Terrain.LAKE_CENTER) < 14.0:
		return false
	if p.distance_to(FIRE_CAMP) < 5.0:
		return false
	for spot in HIDDEN_CHEST_SPOTS:
		if p.distance_to(spot) < 3.0:
			return false
	return true


# --- Environment ------------------------------------------------------------------

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#4f8fd6")
	sky_mat.sky_horizon_color = Color("#cfe3f5")
	sky_mat.ground_horizon_color = Color("#cfe3f5")
	sky_mat.ground_bottom_color = Color("#5a6b5a")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_density = FOG_DENSITY
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = SUN_ENERGY
	sun.light_color = Color("#fff3dc")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _build_water() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 700)
	water.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.52, 0.78, 0.72)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	mat.metallic = 0.2
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _on_cave_entered(inside: bool) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(env, "ambient_light_energy", 0.04 if inside else 1.0, 1.2)
	tween.tween_property(env, "background_energy_multiplier", 0.1 if inside else 1.0, 1.2)
	tween.tween_property(env, "fog_light_color", Color(0.01, 0.01, 0.02) if inside else FOG_COLOR, 1.2)
	tween.tween_property(env, "fog_density", 0.05 if inside else FOG_DENSITY, 1.2)
	tween.tween_property(sun, "light_energy", 0.1 if inside else SUN_ENERGY, 1.2)
	if inside and not GameState.has_flag("cave_braved"):
		GameState.set_flag("cave_braved")
		GameState.change_trait("courage", 1, "Braved the dark cave")
		Events.player_say.emit("It's so dark... but I'm doing this.")


func _on_flag_set(flag: String) -> void:
	if flag == "mochi_found" and _mochi:
		_mochi.global_position = _npcs["lina"].global_position + Vector3(1.2, 0, 0.8)


# --- Places -----------------------------------------------------------------------

func _build_cave() -> void:
	var cave := Cave.new()
	cave.position = ground(CAVE_ENTRANCE.x, CAVE_ENTRANCE.y)
	add_child(cave)
	var gate := TraitGate.new()
	gate.trait_name = "courage"
	gate.min_value = 2
	gate.refusal_line = "Uhm, I can't see anything in there... and it doesn't sound empty. Let's not go in."
	gate.width = Cave.WIDTH
	gate.height = Cave.HEIGHT
	gate.position = cave.position + Vector3(0.5, 0, 0)
	add_child(gate)
	_make_chest("cave_chest", "cave", cave.chest_spot(), -PI / 2.0)
	_spawn_slime(cave.monster_spot(), true)
	var stone := LoreStone.new()
	stone.lore_id = "cave"
	stone.position = cave.lore_spot()
	add_child(stone)


func _build_brazier_puzzle() -> void:
	var top := ground(Terrain.HILL_CENTER.x, Terrain.HILL_CENTER.y)
	var puzzle := BrazierPuzzle.new()
	puzzle.puzzle_id = "hill_braziers"
	puzzle.position = top
	add_child(puzzle)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var p := ground(top.x + cos(a) * 11.0, top.z + sin(a) * 11.0)
		Mats.box(self, Vector3(1.0, 3.2, 0.7), Color("#8c877d"), p + Vector3(0, 1.4, 0), Vector3(0, -a, 0.05), true)
	for i in 3:
		var a := TAU * i / 3.0
		var brazier := Brazier.new()
		brazier.position = ground(top.x + cos(a) * 6.0, top.z + sin(a) * 6.0) - top
		puzzle.add_child(brazier)
		puzzle.add_brazier(brazier)
	var chest := _make_chest("hill_chest", "puzzle", top, 0.0, false, "", not puzzle.is_solved)
	chest.lock_hint = "A chest sealed with three dark flame marks... like the three braziers around it."
	puzzle.solved.connect(chest.unlock)
	_spawn_flame_source(ground(FIRE_CAMP.x, FIRE_CAMP.y), "Take a flame from the ancient fire")
	_spawn_lore(Vector2(top.x, top.z + 9.0), "braziers")


func _build_sky_pillar() -> void:
	var puzzle := JumpPuzzle.new()
	puzzle.puzzle_id = "sky_pillar"
	puzzle.position = Vector3(Terrain.LAKE_CENTER.x, 0, Terrain.LAKE_CENTER.y)
	add_child(puzzle)
	var top := puzzle.position + Vector3(0, JumpPuzzle.PILLAR_TOP, 0)
	var chest := _make_chest("pillar_chest", "pillar", top, PI, false, "", not puzzle.is_solved)
	puzzle.solved.connect(chest.unlock)

	# Stepping stones from the first platform back toward dry land.
	var first := puzzle.position + puzzle.platform_position(0)
	var x := first.x + 3.4
	var last := first
	for i in 14:
		if terrain.height_at(x, first.z) > 0.6:
			break
		last = Vector3(x, 0.1, first.z + sin(i * 1.3) * 0.8)
		Mats.box(self, Vector3(2.2, 1.2, 2.2), Color("#8c877d"), last, Vector3(0, i * 0.5, 0), true)
		x += 3.2
	_spawn_lore(Vector2(x + 2.5, first.z + 2.0), "pillar")


func _spawn_hidden_chests() -> void:
	var valid: Array = []
	for i in HIDDEN_CHEST_SPOTS.size():
		var p: Vector2 = HIDDEN_CHEST_SPOTS[i]
		if terrain.height_at(p.x, p.y) > 0.8:
			valid.append(i)
	for pick in ChestPlacement.pick(valid.size(), HIDDEN_CHEST_COUNT, GameState.chest_seed):
		var index: int = valid[pick]
		var p: Vector2 = HIDDEN_CHEST_SPOTS[index]
		_make_chest("hidden_%d" % index, "hidden", ground(p.x, p.y), float(index) * 1.7, true)


# --- Spawning helpers ---------------------------------------------------------------

func _make_chest(id: String, table: String, pos: Vector3, yaw := 0.0, hidden := false, owner_name := "", locked := false) -> Chest:
	var chest := Chest.new()
	chest.chest_id = id
	chest.loot_table = table
	chest.hidden = hidden
	chest.owned_by = owner_name
	chest.locked = locked
	chest.position = pos
	chest.rotation.y = yaw
	add_child(chest)
	return chest


func _spawn_flame_source(pos: Vector3, prompt: String) -> void:
	var fire := FlameSource.new()
	fire.prompt = prompt
	fire.position = pos
	add_child(fire)


func _spawn_lore(p: Vector2, lore_id: String) -> void:
	var stone := LoreStone.new()
	stone.lore_id = lore_id
	stone.position = ground(p.x, p.y)
	stone.rotation.y = atan2(-p.x, -p.y)
	add_child(stone)


func _spawn_npcs() -> void:
	for data in NPCS:
		var npc := NPC.new()
		npc.npc_name = data["name"]
		npc.dialogue_id = data["dialogue"]
		npc.appearance = data["look"]
		npc.outfit_color = Color(data["outfit"])
		npc.body_scale = data.get("scale", 1.0)
		var p: Vector2 = data["pos"]
		npc.position = ground(p.x, p.y)
		add_child(npc)
		npc.face_towards(Vector3(0, npc.position.y, 0) if p.length() > 1.0 else Vector3(0, 0, 10))
		_npcs[data["id"]] = npc

	_mochi = NPC.new()
	_mochi.npc_name = "Mochi"
	_mochi.dialogue_id = "mochi"
	_mochi.is_cat = true
	_mochi.body_scale = 0.4
	if GameState.has_flag("mochi_found"):
		_mochi.position = _npcs["lina"].position + Vector3(1.2, 0, 0.8)
	else:
		_mochi.position = ground(MOCHI_SPOT.x, MOCHI_SPOT.y)
	add_child(_mochi)


func _spawn_monsters() -> void:
	for p in SLIME_SPAWNS:
		if terrain.height_at(p.x, p.y) > 0.3:
			_spawn_slime(ground(p.x, p.y) + Vector3.UP * 0.5, false)


func _spawn_slime(pos: Vector3, gloom: bool) -> void:
	var slime := Slime.new()
	if gloom:
		slime.display_name = "Gloom Slime"
		slime.color = Color("#8a5bd6")
		slime.max_hp = 45
		slime.damage = 10
	slime.position = pos
	add_child(slime)


func _spawn_player() -> void:
	player = Player.new()
	if GameState.player_position is Vector3:
		player.position = GameState.player_position + Vector3.UP * 0.3
	else:
		player.position = ground(VILLAGE_SPAWN.x, VILLAGE_SPAWN.y) + Vector3.UP * 0.5
	add_child(player)
	GameState._emit_health()
