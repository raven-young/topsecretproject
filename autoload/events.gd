extends Node
## Global signal bus. Gameplay code emits, UI listens, so neither needs a
## reference to the other.

signal trait_changed(trait_name: String, new_value: int, delta: int, reason: String)
signal inventory_changed
signal gold_changed(new_amount: int)
signal equipment_changed
signal toast(text: String)
signal player_say(text: String)
signal show_text(title: String, text: String)
signal dialogue_requested(dialogue_id: String, npc_name: String)
signal dialogue_finished
signal interaction_prompt(text: String)
signal chest_opened(chest_id: String)
signal puzzle_solved(puzzle_id: String)
signal lore_discovered(lore_id: String)
signal monster_killed(monster_type: String)
signal flag_set(flag: String)
signal player_health_changed(hp: int, max_hp: int)
signal player_died
signal cave_entered(inside: bool)
