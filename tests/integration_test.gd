extends Node
## Plays through the vertical slice's core loop against the real world scene.
## Run: godot --headless --path . res://tests/integration_test.tscn

var _passed := 0
var _failed := 0
var _said: Array[String] = []
var world: Node3D
var player: Player


func _ready() -> void:
	Events.player_say.connect(func(text: String): _said.append(text))
	var profile := PlayerProfile.new()
	profile.player_name = "Tester"
	profile.job = "mage"
	GameState.new_game(profile)
	world = load("res://world/main.tscn").instantiate()
	add_child(world)
	player = world.player
	await _frames(5)

	print("-> _test_starting_state()")
	await _test_starting_state()
	print("-> _test_cave_gate()")
	await _test_cave_gate()
	print("-> _test_chests_and_stealing()")
	_test_chests_and_stealing()
	print("-> _test_puzzles()")
	await _test_puzzles()
	print("-> _test_crafting_and_dust()")
	_test_crafting_and_dust()
	print("-> _test_combat()")
	await _test_combat()
	print("-> _test_dialogue_and_menus()")
	await _test_dialogue_and_menus()
	print("-> _test_mochi_and_quests()")
	_test_mochi_and_quests()
	print("-> _test_save_round_trip()")
	_test_save_round_trip()

	print("\nINTEGRATION: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", label)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _find(type) -> Array:
	return _all(world).filter(func(n): return is_instance_of(n, type))


func _all(node: Node) -> Array:
	var out := [node]
	for c in node.get_children():
		out.append_array(_all(c))
	return out


func _chest(id: String) -> Chest:
	for c in _find(Chest):
		if c.chest_id == id:
			return c
	return null


func _test_starting_state() -> void:
	for t in Personality.TRAITS:
		check(GameState.personality.get_value(t) == 0, "%s starts at 0" % t)
	check(GameState.equipment.slots["weapon"] == "apprentice_staff", "mage starts with staff")
	check(GameState.inventory.gold == GameState.STARTING_GOLD, "starting gold")
	check(_find(NPC).size() == 6, "5 villagers + Mochi spawned")
	check(_find(Slime).size() >= 8, "slimes spawned")
	check(_find(Chest).size() >= 8, "chests spawned (house, cave, hill, pillar, hidden)")
	var hidden := _find(Chest).filter(func(c): return c.chest_id.begins_with("hidden_"))
	check(hidden.size() == world.HIDDEN_CHEST_COUNT, "%d hidden chests placed" % world.HIDDEN_CHEST_COUNT)
	check(player.global_position.y > 2.0, "player spawned on the ground")


func _test_cave_gate() -> void:
	var gate: TraitGate = _find(TraitGate)[0]
	await _frames(2)
	check(not gate._wall_shape.disabled, "cave wall closed at courage 0")
	player.global_position = gate.global_position + Vector3(3, 0.5, 0)
	await _frames(4)
	check(_said.any(func(s): return "can't see anything" in s), "character refuses to enter the dark cave")
	check(not gate._wall_shape.disabled, "wall stays closed")

	# Earn courage through village conversations.
	var elder: Dictionary = ItemDB.load_dialogue("elder")
	GameState.apply_dialogue_outcome(elder["nodes"]["ask"]["choices"][1], "Elder Bram")
	var guard: Dictionary = ItemDB.load_dialogue("guard")
	GameState.apply_dialogue_outcome(guard["nodes"]["intro"]["choices"][0], "Guard Tomas")
	check(GameState.personality.get_value("courage") == 2, "dialogue raised courage to 2")
	check(GameState.personality.get_value("humbleness") == 1, "honest answer raised humbleness")
	check(GameState.trait_log.size() == 3, "trait changes logged with reasons")

	player.global_position = gate.global_position + Vector3(12, 0.5, 0)
	await _frames(3)
	player.global_position = gate.global_position + Vector3(3, 0.5, 0)
	await _frames(4)
	check(gate._wall_shape.disabled, "wall opens once courage is 2")

	var cave: Cave = _find(Cave)[0]
	player.global_position = cave.global_position + Vector3(-10, 0.5, 0)
	await _frames(4)
	check(GameState.has_flag("cave_braved"), "entering the cave is recorded")
	check(GameState.personality.get_value("courage") == 3, "braving the cave raised courage")
	await _frames(90)
	check(world.env.ambient_light_energy < 0.5, "the world darkens inside the cave")


func _test_chests_and_stealing() -> void:
	var cave_chest := _chest("cave_chest")
	cave_chest.interact(player)
	check(GameState.opened_chests.has("cave_chest"), "cave chest opened")
	check(GameState.inventory.has("dust_courage"), "cave chest gave Dust of Courage")
	check(GameState.inventory.has("mana_crystal", 2), "cave chest gave mana crystals")
	check(cave_chest.get_prompt() == "", "opened chest no longer interactable")

	var align_before := GameState.personality.get_value("alignment")
	_chest("hollis_house").interact(player)
	check(GameState.personality.get_value("alignment") == align_before - 1, "stealing from a house lowers alignment")


func _test_puzzles() -> void:
	var hill := _chest("hill_chest")
	check(hill.locked, "hill chest sealed before braziers are lit")
	hill.interact(player)
	check(not GameState.opened_chests.has("hill_chest"), "sealed chest can't be opened")
	var puzzle: BrazierPuzzle = _find(BrazierPuzzle)[0]
	player.carry_flame()
	check(player.flame_time > 0.0, "player carries a flame")
	for b in puzzle.braziers:
		b.interact(player)
	check(puzzle.is_solved and GameState.solved_puzzles.has("hill_braziers"), "lighting all braziers solves puzzle")
	check(not hill.locked, "solving unseals the chest")
	hill.interact(player)
	check(GameState.opened_chests.has("hill_chest"), "hill chest opened after solving")

	var pillar: JumpPuzzle = _find(JumpPuzzle)[0]
	var courage := GameState.personality.get_value("courage")
	player.global_position = pillar.global_position + Vector3(0, JumpPuzzle.PILLAR_TOP + 0.6, 0)
	await _frames(4)
	check(pillar.is_solved, "reaching the pillar top solves the jump puzzle")
	check(GameState.personality.get_value("courage") == courage + 1, "climbing the pillar raised courage")
	check(not _chest("pillar_chest").locked, "pillar chest unsealed")


func _test_crafting_and_dust() -> void:
	var recipe: Dictionary = ItemDB.recipes.filter(func(r): return r["output"] == "crystal_staff")[0]
	GameState.give_item("wood", 2)
	GameState.give_item("mana_crystal", 3)
	check(GameState.craft(recipe), "crafting crystal staff")
	check(GameState.inventory.has("crystal_staff"), "crafted item in inventory")
	var atk := GameState.attack_power()
	check(GameState.equip_item("crystal_staff"), "equip crafted staff")
	check(GameState.attack_power() > atk, "equipping raised attack")
	check(GameState.inventory.has("apprentice_staff"), "old weapon returned to pack")
	check(not GameState.equip_item("iron_sword"), "can't equip what you don't have")
	GameState.give_item("iron_sword")
	check(not GameState.equip_item("iron_sword"), "mage can't equip a fighter sword")

	var courage := GameState.personality.get_value("courage")
	check(GameState.use_item("dust_courage"), "use Dust of Courage")
	check(GameState.personality.get_value("courage") == courage + 1, "dust raised courage")


func _test_combat() -> void:
	var slime: Slime = _find(Slime).filter(func(s): return s.display_name == "Slime")[0]
	var hp := GameState.hp
	player.global_position = slime.global_position + Vector3(0.8, 0.2, 0)
	await _frames(10)
	check(GameState.hp < hp, "slime contact damages player")
	slime.take_damage(999, player.global_position)
	check(GameState.has_flag(GameState.FIRST_KILL_FLAG), "first kill recorded")
	await _frames(30)
	check(not is_instance_valid(slime), "dead slime removed")

	var bolt := Projectile.new().setup(Vector3.FORWARD, 20.0, 5, "fire", 0.0, player)
	world.add_child(bolt)
	check(bolt.element == "fire", "mage projectile is fire")


func _test_dialogue_and_menus() -> void:
	var box: DialogueBox = _find(DialogueBox)[0]
	box.open_dialogue("guard", "Guard Tomas")
	check(GameState.is_ui_locked(), "dialogue locks UI")
	check(box._speaker.text == "Guard Tomas", "dialogue shows speaker")
	check(GameState.has_flag("slime_reward_given"), "returning to guard after a kill gives reward")
	box._close()
	check(not GameState.is_ui_locked(), "closing dialogue unlocks UI")

	box.open_dialogue("pip", "Pip")
	var steal: Button = null
	for b in box._choices.get_children():
		if "pocket a crystal" in b.text:
			steal = b
	check(steal != null and steal.disabled, "evil-only choice shown but locked for a non-evil hero")
	check(steal != null and "[Alignment ≤ -2]" in steal.text, "locked choice shows its trait tag")
	box._close()

	var menu: GameMenu = _find(GameMenu)[0]
	for tab in GameMenu.TABS:
		menu.open(tab)
		await get_tree().process_frame
		check(menu._pages[tab].get_child_count() > 0, "menu tab %s builds" % tab)
	menu.close()
	check(not GameState.is_ui_locked(), "menu close unlocks UI")


func _test_mochi_and_quests() -> void:
	var lina: Dictionary = ItemDB.load_dialogue("lina")
	GameState.apply_dialogue_outcome(lina["nodes"]["intro"]["choices"][0], "Lina")
	var mochi: NPC = _find(NPC).filter(func(n): return n.is_cat)[0]
	var before := mochi.global_position
	GameState.set_flag("mochi_found")
	check(mochi.global_position.distance_to(before) > 20.0, "Mochi goes home when found")
	check(DialogueLogic.pick_start(lina, GameState.flags) == "reunion", "Lina's reunion dialogue unlocks")


func _test_save_round_trip() -> void:
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.from_dict(snapshot)
	var again: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	check(snapshot == again, "save data round trips through JSON")
	check(GameState.personality.get_value("courage") == int(snapshot["personality"]["courage"]), "traits restored")
	check(GameState.opened_chests.has("cave_chest"), "opened chests restored")
	check(GameState.player_position is Vector3, "player position restored")
