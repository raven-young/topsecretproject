extends Node
## State of the current playthrough: who the player is, what they carry and
## what they have done. Gameplay changes state through these methods so every
## change is announced on the Events bus.

const BASE_STATS := {
	"fighter": {"attack": 10, "defense": 4, "max_hp": 120},
	"mage": {"attack": 9, "defense": 2, "max_hp": 90},
	"ranger": {"attack": 8, "defense": 3, "max_hp": 100},
}
const STARTER_WEAPONS := {"fighter": "wooden_sword", "mage": "apprentice_staff", "ranger": "short_bow"}
const STARTING_GOLD := 10
const FIRST_KILL_FLAG := "first_monster_killed"

var profile: PlayerProfile
var personality := Personality.new()
var inventory := Inventory.new()
var equipment := Equipment.new()
var flags: Dictionary = {}
var opened_chests: Dictionary = {}
var solved_puzzles: Dictionary = {}
var lore_found: Dictionary = {}
var trait_log: Array = []
var chest_seed := 0
var player_position = null
var hp := 100
var ui_locks := 0


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()


func reset() -> void:
	personality = Personality.new()
	inventory = Inventory.new()
	equipment = Equipment.new()
	flags = {}
	opened_chests = {}
	solved_puzzles = {}
	lore_found = {}
	trait_log = []
	player_position = null
	chest_seed = 0
	ui_locks = 0


func new_game(new_profile: PlayerProfile) -> void:
	reset()
	profile = new_profile
	inventory.gold = STARTING_GOLD
	var starter: String = STARTER_WEAPONS.get(profile.job, "wooden_sword")
	inventory.add(starter)
	equipment.equip(starter, ItemDB.get_item(starter), inventory, profile.job)
	chest_seed = randi()
	hp = max_hp()


# --- Stats -------------------------------------------------------------------

func base_stat(stat: String) -> int:
	if profile == null:
		return 0
	var stats: Dictionary = BASE_STATS.get(profile.job, BASE_STATS["fighter"])
	return int(stats.get(stat, 0))


func attack_power() -> int:
	return base_stat("attack") + equipment.total_stat("attack", ItemDB.items)


func defense() -> int:
	return base_stat("defense") + equipment.total_stat("defense", ItemDB.items)


func max_hp() -> int:
	return base_stat("max_hp") + equipment.total_stat("max_hp", ItemDB.items)


# --- Personality ---------------------------------------------------------------

func change_trait(trait_name: String, delta: int, reason: String) -> void:
	var applied := personality.apply(trait_name, delta)
	if applied == 0:
		return
	trait_log.push_front({"trait": trait_name, "delta": applied, "reason": reason})
	Events.trait_changed.emit(trait_name, personality.get_value(trait_name), applied, reason)


func apply_effects(effects: Dictionary, reason: String) -> void:
	for trait_name in effects:
		change_trait(trait_name, int(effects[trait_name]), reason)


# --- Items ---------------------------------------------------------------------

func give_item(id: String, amount := 1) -> void:
	if id == "" or amount <= 0:
		return
	inventory.add(id, amount)
	Events.toast.emit("+%d %s" % [amount, ItemDB.item_name(id)])
	Events.inventory_changed.emit()


func take_item(id: String, amount := 1) -> bool:
	if not inventory.remove(id, amount):
		return false
	Events.inventory_changed.emit()
	return true


func add_gold(amount: int) -> bool:
	if not inventory.add_gold(amount):
		return false
	if amount > 0:
		Events.toast.emit("+%d gold" % amount)
	elif amount < 0:
		Events.toast.emit("-%d gold" % -amount)
	Events.gold_changed.emit(inventory.gold)
	return true


func give_loot(loot: Dictionary) -> void:
	if int(loot.get("gold", 0)) > 0:
		add_gold(int(loot["gold"]))
	var items: Dictionary = loot.get("items", {})
	for id in items:
		give_item(id, int(items[id]))


func use_item(id: String) -> bool:
	var def := ItemDB.get_item(id)
	if not inventory.has(id):
		return false
	match str(def.get("use", "")):
		"heal":
			if hp >= max_hp():
				Events.toast.emit("Already at full health.")
				return false
			heal(int(def.get("amount", 0)))
		"trait":
			var trait_name: String = def.get("trait", "")
			if personality.get_value(trait_name) >= Personality.MAX_VALUE:
				Events.toast.emit("%s is already at its peak." % trait_name.capitalize())
				return false
			change_trait(trait_name, int(def.get("amount", 1)), "Used %s" % def.get("name", id))
		_:
			return false
	inventory.remove(id)
	Events.inventory_changed.emit()
	return true


func equip_item(id: String) -> bool:
	if not equipment.equip(id, ItemDB.get_item(id), inventory, profile.job):
		return false
	_after_equipment_change()
	return true


func unequip_slot(slot: String) -> bool:
	if not equipment.unequip(slot, inventory):
		return false
	_after_equipment_change()
	return true


func craft(recipe: Dictionary) -> bool:
	if not Crafting.craft(recipe, inventory):
		return false
	Events.toast.emit("Crafted %s" % ItemDB.item_name(recipe["output"]))
	Events.inventory_changed.emit()
	return true


func _after_equipment_change() -> void:
	hp = mini(hp, max_hp())
	Events.equipment_changed.emit()
	Events.inventory_changed.emit()
	_emit_health()


# --- Health --------------------------------------------------------------------

func damage_player(amount: int) -> void:
	if hp <= 0:
		return
	hp = maxi(0, hp - maxi(1, amount - defense() / 2))
	_emit_health()
	if hp == 0:
		Events.player_died.emit()


func heal(amount: int) -> void:
	hp = mini(max_hp(), hp + amount)
	_emit_health()


func full_heal() -> void:
	heal(max_hp())


func _emit_health() -> void:
	Events.player_health_changed.emit(hp, max_hp())


# --- Flags & world events ----------------------------------------------------------

func set_flag(flag: String) -> void:
	if flag == "" or has_flag(flag):
		return
	flags[flag] = true
	Events.flag_set.emit(flag)


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func apply_dialogue_outcome(outcome: Dictionary, npc_name: String) -> void:
	var reason: String = outcome.get("reason", "Spoke with %s" % npc_name)
	if outcome.has("gold"):
		add_gold(int(outcome["gold"]))
	var taken: Dictionary = outcome.get("take", {})
	for id in taken:
		take_item(id, int(taken[id]))
	var given: Dictionary = outcome.get("give", {})
	for id in given:
		give_item(id, int(given[id]))
	apply_effects(outcome.get("effects", {}), reason)
	if outcome.has("set_flag"):
		set_flag(outcome["set_flag"])


func register_kill(monster_type: String) -> void:
	Events.monster_killed.emit(monster_type)
	if not has_flag(FIRST_KILL_FLAG):
		set_flag(FIRST_KILL_FLAG)
		change_trait("courage", 1, "Defeated your first monster")


func discover_lore(lore_id: String) -> void:
	if lore_found.has(lore_id):
		return
	lore_found[lore_id] = true
	Events.lore_discovered.emit(lore_id)
	Events.toast.emit("New discovery: %s" % ItemDB.lore.get(lore_id, {}).get("title", lore_id))


# --- UI lock (menus and dialogue pause the world and free the mouse) ------------------

func lock_ui() -> void:
	ui_locks += 1
	_apply_lock()


func unlock_ui() -> void:
	ui_locks = maxi(0, ui_locks - 1)
	_apply_lock()


func release_all_locks() -> void:
	ui_locks = 0
	_apply_lock()


func is_ui_locked() -> bool:
	return ui_locks > 0


func _apply_lock() -> void:
	get_tree().paused = ui_locks > 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if ui_locks > 0 else Input.MOUSE_MODE_CAPTURED


# --- Save data -------------------------------------------------------------------

func to_dict() -> Dictionary:
	var pos = null
	if player_position is Vector3:
		pos = [player_position.x, player_position.y, player_position.z]
	return {
		"version": 1,
		"profile": profile.to_dict(),
		"personality": personality.to_dict(),
		"inventory": inventory.to_dict(),
		"equipment": equipment.to_dict(),
		"flags": flags,
		"opened_chests": opened_chests,
		"solved_puzzles": solved_puzzles,
		"lore_found": lore_found,
		"trait_log": trait_log,
		"chest_seed": chest_seed,
		"hp": hp,
		"player_position": pos,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	profile = PlayerProfile.new()
	profile.load_dict(data.get("profile", {}))
	personality.load_dict(data.get("personality", {}))
	inventory.load_dict(data.get("inventory", {}))
	equipment.load_dict(data.get("equipment", {}))
	flags = data.get("flags", {})
	opened_chests = data.get("opened_chests", {})
	solved_puzzles = data.get("solved_puzzles", {})
	lore_found = data.get("lore_found", {})
	trait_log = data.get("trait_log", [])
	chest_seed = int(data.get("chest_seed", 0))
	hp = clampi(int(data.get("hp", max_hp())), 1, max_hp())
	var pos = data.get("player_position")
	if pos is Array and pos.size() == 3:
		player_position = Vector3(pos[0], pos[1], pos[2])


# --- Input map ---------------------------------------------------------------------
# Physical keys, so WASD sits in the same place on AZERTY/QWERTZ keyboards.

func _setup_input() -> void:
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("jump", [KEY_SPACE])
	_bind_keys("sprint", [KEY_SHIFT])
	_bind_keys("interact", [KEY_E])
	_bind_keys("attack", [KEY_J])
	_bind_mouse("attack", MOUSE_BUTTON_LEFT)
	_bind_keys("menu", [KEY_TAB])
	_bind_keys("inventory", [KEY_I])
	_bind_keys("profile", [KEY_P])
	_bind_keys("pause", [KEY_ESCAPE])
	_bind_keys("quick_save", [KEY_F5])


func _bind_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
