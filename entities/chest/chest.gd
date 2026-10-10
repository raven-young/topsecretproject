class_name Chest
extends StaticBody3D
## Treasure chest. Can be sealed by a puzzle (`locked`), dimly lit when hidden,
## and belong to someone (opening it is stealing, which lowers alignment).

var chest_id := ""
var loot_table := "common"
var owned_by := ""
var hidden := false
var locked := false
var lock_hint := "It's sealed by some kind of ancient magic... there must be a way to break it."
var _opened := false
var _lid: Node3D
var _glow: OmniLight3D
var _seal: MeshInstance3D


func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.75, 0.7)
	col.shape = shape
	col.position.y = 0.375
	add_child(col)

	var wood := Color("#8b5a2b")
	var metal := Color("#d4a83a")
	Mats.box(self, Vector3(1.0, 0.5, 0.7), wood, Vector3(0, 0.25, 0))
	for x in [-0.35, 0.35]:
		Mats.box(self, Vector3(0.08, 0.52, 0.72), metal, Vector3(x, 0.25, 0))
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.5, -0.35)
	add_child(_lid)
	Mats.box(_lid, Vector3(1.02, 0.22, 0.72), wood.lightened(0.1), Vector3(0, 0.11, 0.35))
	Mats.box(_lid, Vector3(0.14, 0.16, 0.06), metal, Vector3(0, 0.02, 0.72))

	_glow = Mats.light(self, Color("#ffd36b"), 0.35 if hidden else 0.9, 3.5, Vector3(0, 1.0, 0))
	_seal = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.75
	ring.outer_radius = 0.85
	_seal.mesh = ring
	_seal.material_override = Mats.toon(Color("#6be4ff", 0.8), 3.0)
	_seal.position.y = 0.4
	_seal.visible = locked
	add_child(_seal)

	if GameState.opened_chests.has(chest_id):
		_opened = true
		_lid.rotation.x = -1.9
		_glow.visible = false
		_seal.visible = false


func _process(delta: float) -> void:
	if _seal.visible:
		_seal.rotate_y(delta * 0.8)


func get_prompt() -> String:
	if _opened:
		return ""
	if locked:
		return "Inspect the sealed chest"
	if owned_by != "":
		return "Open %s's chest (it isn't yours...)" % owned_by
	return "Open chest"


func interact(_player: Node) -> void:
	if _opened:
		return
	if locked:
		Events.player_say.emit(lock_hint)
		return
	_open()


func unlock() -> void:
	if not locked:
		return
	locked = false
	var tween := create_tween()
	tween.tween_property(_seal, "scale", Vector3(2.5, 2.5, 2.5), 0.6)
	tween.tween_callback(func(): _seal.visible = false)


func _open() -> void:
	_opened = true
	GameState.opened_chests[chest_id] = true
	var tween := create_tween()
	tween.tween_property(_lid, "rotation:x", -1.9, 0.5).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(_glow, "light_energy", 0.0, 1.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(chest_id) ^ GameState.chest_seed
	GameState.give_loot(LootTable.roll(ItemDB.loot_tables.get(loot_table, {}), rng))
	if owned_by != "":
		GameState.change_trait("alignment", -1, "Took %s's belongings without asking" % owned_by)
	Events.chest_opened.emit(chest_id)
