extends SceneTree
## Headless unit tests for core/ logic and data integrity.
## Run: godot --headless --path . -s tests/run_tests.gd

const PersonalityLib = preload("res://core/personality.gd")
const InventoryLib = preload("res://core/inventory.gd")
const CraftingLib = preload("res://core/crafting.gd")
const LootLib = preload("res://core/loot_table.gd")
const PlacementLib = preload("res://core/chest_placement.gd")
const EquipmentLib = preload("res://core/equipment.gd")
const DialogueLib = preload("res://core/dialogue_logic.gd")
const ProfileLib = preload("res://core/player_profile.gd")

var _passed := 0
var _failed := 0


func _init() -> void:
	_test_personality()
	_test_inventory()
	_test_crafting()
	_test_loot()
	_test_chest_placement()
	_test_equipment()
	_test_dialogue_logic()
	_test_profile_round_trip()
	_test_data_integrity()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", label)


func _test_personality() -> void:
	var p = PersonalityLib.new()
	for t in PersonalityLib.TRAITS:
		check(p.get_value(t) == 0, "trait %s starts at 0" % t)
	check(p.apply("courage", 3) == 3, "apply returns delta")
	check(p.apply("courage", 20) == 7, "apply clamps at max and reports real delta")
	check(p.get_value("courage") == 10, "courage capped at 10")
	check(p.apply("courage", -30) == -20, "apply clamps at min")
	check(p.get_value("courage") == -10, "courage floored at -10")
	check(p.apply("nonsense", 1) == 0, "unknown trait ignored")
	p.load_dict({"courage": 2, "kindness": 99})
	check(p.meets("courage", 2), "gate passes at threshold")
	check(not p.meets("courage", 3), "gate fails below threshold")
	check(p.get_value("kindness") == 10, "load clamps values")
	check(p.meets("alignment", -10, -0) and not p.meets("alignment", -10, -1), "max bound respected")
	check(PersonalityLib.describe("alignment", 5) == "Good", "alignment describe good")
	check(PersonalityLib.describe("alignment", -5) == "Evil", "alignment describe evil")


func _test_inventory() -> void:
	var inv = InventoryLib.new()
	inv.add("wood", 3)
	check(inv.count("wood") == 3, "add stacks")
	check(not inv.remove("wood", 4), "cannot remove more than owned")
	check(inv.remove("wood", 3) and not inv.items.has("wood"), "empty stacks are erased")
	check(inv.add_gold(10) and not inv.add_gold(-11) and inv.gold == 10, "gold cannot go negative")
	inv.add("iron_ore", 2)
	var copy = InventoryLib.new()
	copy.load_dict(inv.to_dict())
	check(copy.count("iron_ore") == 2 and copy.gold == 10, "inventory round trip")
	var defs := {"iron_ore": {"name": "Iron", "category": "craft"}, "sword": {"name": "Sword", "category": "weapon"}}
	inv.add("sword")
	check(inv.ids_in_category("craft", defs) == ["iron_ore"], "category filter")


func _test_crafting() -> void:
	var inv = InventoryLib.new()
	var recipe := {"output": "iron_sword", "inputs": {"wood": 2, "iron_ore": 3}}
	inv.add("wood", 2)
	inv.add("iron_ore", 1)
	check(CraftingLib.missing(recipe, inv) == {"iron_ore": 2}, "missing lists shortfall")
	check(not CraftingLib.craft(recipe, inv), "cannot craft without inputs")
	check(inv.count("wood") == 2, "failed craft consumes nothing")
	inv.add("iron_ore", 2)
	check(CraftingLib.craft(recipe, inv), "craft succeeds with inputs")
	check(inv.count("wood") == 0 and inv.count("iron_ore") == 0 and inv.count("iron_sword") == 1, "craft consumes inputs and adds output")


func _test_loot() -> void:
	var table := {"gold": [5, 10], "guaranteed": {"gem": 1}, "rolls": [3, 3],
		"entries": [{"id": "wood", "weight": 1, "count": [1, 1]}, {"id": "", "weight": 1}]}
	var a := RandomNumberGenerator.new()
	a.seed = 42
	var b := RandomNumberGenerator.new()
	b.seed = 42
	var r1: Dictionary = LootLib.roll(table, a)
	var r2: Dictionary = LootLib.roll(table, b)
	check(r1 == r2, "same seed gives same loot")
	check(r1["gold"] >= 5 and r1["gold"] <= 10, "gold within range")
	check(r1["items"].get("gem", 0) == 1, "guaranteed item present")
	check(not r1["items"].has(""), "empty roll adds nothing")
	check(r1["items"].get("wood", 0) <= 3, "roll count respected")


func _test_chest_placement() -> void:
	var picks: Array = PlacementLib.pick(9, 5, 1234)
	check(picks.size() == 5, "picks requested amount")
	var unique := {}
	for i in picks:
		unique[i] = true
		check(i >= 0 and i < 9, "index in range")
	check(unique.size() == 5, "picks are distinct")
	check(PlacementLib.pick(9, 5, 1234) == picks, "placement deterministic for a seed")
	check(PlacementLib.pick(3, 5, 1).size() == 3, "never more picks than candidates")


func _test_equipment() -> void:
	var eq = EquipmentLib.new()
	var inv = InventoryLib.new()
	var sword := {"slot": "weapon", "job": "fighter", "attack": 10}
	var staff := {"slot": "weapon", "job": "mage", "attack": 11}
	inv.add("sword")
	inv.add("staff")
	check(not eq.equip("staff", staff, inv, "fighter"), "job restriction enforced")
	check(eq.equip("sword", sword, inv, "fighter") and not inv.has("sword"), "equip moves item out of inventory")
	check(eq.total_stat("attack", {"sword": sword}) == 10, "stat totals")
	inv.add("sword2")
	check(eq.equip("sword2", sword, inv, "fighter") and inv.has("sword"), "swap returns previous item")
	check(eq.unequip("weapon", inv) and inv.has("sword2"), "unequip returns item")


func _test_dialogue_logic() -> void:
	var dlg := {"start": "a", "starts": [{"if_flag": ["x", "y"], "node": "both"}, {"if_flag": "x", "node": "only_x"}]}
	check(DialogueLib.pick_start(dlg, {}) == "a", "default start")
	check(DialogueLib.pick_start(dlg, {"x": true}) == "only_x", "single flag start")
	check(DialogueLib.pick_start(dlg, {"x": true, "y": true}) == "both", "all flags required")
	check(not DialogueLib.conditions_met({"unless_flag": "z"}, {"z": true}), "unless_flag hides")
	var p = PersonalityLib.new()
	var brave := {"require": {"trait": "courage", "min": 2}}
	check(DialogueLib.locked_reason(brave, p, 0) != "", "trait requirement locks")
	p.apply("courage", 2)
	check(DialogueLib.locked_reason(brave, p, 0) == "", "trait requirement unlocks")
	check(DialogueLib.tag(brave) == "[Courage 2] ", "tag shows requirement")
	check(DialogueLib.locked_reason({"require": {"gold": 5}}, p, 4) != "", "gold requirement")


func _test_profile_round_trip() -> void:
	var a = ProfileLib.new()
	a.player_name = "Ana"
	a.job = "mage"
	a.appearance["hair_style"] = 3
	var b = ProfileLib.new()
	b.load_dict(a.to_dict())
	check(b.player_name == "Ana" and b.job == "mage" and b.appearance["hair_style"] == 3, "profile round trip")
	b.load_dict({"job": "pirate"})
	check(b.job == "fighter", "invalid job falls back")


func _test_data_integrity() -> void:
	var items: Dictionary = _json("res://data/items.json")
	check(not items.is_empty(), "items.json loads")
	for id in items:
		var def: Dictionary = items[id]
		check(def.get("category", "") in ["craft", "weapon", "other"], "%s has a valid category" % id)
		if def.get("use", "") == "trait":
			check(def.get("trait", "") in PersonalityLib.TRAITS, "%s targets a real trait" % id)
	for starter in ["wooden_sword", "apprentice_staff", "short_bow"]:
		check(items.has(starter), "starter weapon %s exists" % starter)

	for recipe in _json("res://data/recipes.json"):
		check(items.has(recipe["output"]), "recipe output %s exists" % recipe["output"])
		for id in recipe["inputs"]:
			check(items.has(id), "recipe input %s exists" % id)

	var tables: Dictionary = _json("res://data/loot_tables.json")
	for table_id in tables:
		for entry in tables[table_id].get("entries", []):
			var id: String = entry.get("id", "")
			check(id == "" or items.has(id), "loot %s item %s exists" % [table_id, id])
		for id in tables[table_id].get("guaranteed", {}):
			check(items.has(id), "loot %s guaranteed %s exists" % [table_id, id])

	var dir := DirAccess.open("res://data/dialogue")
	for file_name in dir.get_files():
		if file_name.get_extension() == "json":
			_check_dialogue(file_name, _json("res://data/dialogue/" + file_name), items)


func _check_dialogue(file_name: String, dlg: Dictionary, items: Dictionary) -> void:
	var nodes: Dictionary = dlg.get("nodes", {})
	check(nodes.has(dlg.get("start", "")), "%s start node exists" % file_name)
	for entry in dlg.get("starts", []):
		check(nodes.has(entry["node"]), "%s start %s exists" % [file_name, entry["node"]])
	for node_id in nodes:
		var node: Dictionary = nodes[node_id]
		if node.has("next"):
			check(nodes.has(node["next"]), "%s:%s next exists" % [file_name, node_id])
		var outcomes: Array = node.get("choices", []).duplicate()
		if node.has("on_enter"):
			outcomes.append(node["on_enter"])
		for outcome in outcomes:
			if outcome.has("next"):
				check(nodes.has(outcome["next"]), "%s:%s choice next %s exists" % [file_name, node_id, outcome["next"]])
			for id in outcome.get("give", {}):
				check(items.has(id), "%s gives real item %s" % [file_name, id])
			for t in outcome.get("effects", {}):
				check(t in PersonalityLib.TRAITS, "%s effect on real trait %s" % [file_name, t])
			var req: Dictionary = outcome.get("require", {})
			if req.has("trait"):
				check(req["trait"] in PersonalityLib.TRAITS, "%s requires real trait" % file_name)


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
