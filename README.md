# Wanderlight

An open-world exploration RPG vertical slice in **Godot 4.7** (GDScript).
Explore an island, find hidden treasure chests, solve puzzles, and become
someone: your personality traits start at 0 and change through what you
say and do. Some places and conversations only open to certain personalities.

## Run it

```sh
godot --path .            # play (opens the character creator)
godot -e --path .         # open in the editor, then press F5
```

The first time, or after adding new `class_name` scripts, run `godot --headless --import` once.

## Controls

| Key | Action |
| --- | --- |
| WASD / arrows | Move (physical keys, so it works on AZERTY/QWERTZ too) |
| Mouse | Camera |
| Shift | Sprint (uses stamina) |
| Space | Jump / swim up |
| E | Interact (talk, open, read, take fire) |
| Left click / J | Attack (Fighter melee, Mage fire bolt, Ranger arrow) |
| Tab | Adventurer's Pack (Inventory, Crafting, Equipment, Profile, Journal, System) |
| I / P | Jump straight to Inventory / Profile |
| 1–9 | Pick a dialogue choice |
| Esc | Close menu or dialogue / open System menu |
| F5 | Quick save |

## What's in the slice

- **Character creation**: name, hair style and colour, face, body type, skin tone, class (Fighter, Mage, Ranger). All five traits start at 0.
- **Personality** (Courage, Empathy, Humbleness, Kindness, Alignment, from −10 to +10): changes through dialogue choices and world actions, with a toast and a journal entry for each change. Shown as a radar chart in the Profile tab.
- **Brightvale village**: Elder Bram (intro quest), Guard Tomas (slime quest, with a Kindness-gated option), Lina (lost kitten quest), Pip the merchant (shop, rumours, an evil-only steal option), Old Sela (give or mock).
- **The dark cave** (west): needs **Courage ≥ 2**. Below that, your hero refuses to go in. Earn courage in the village first.
- **Hill of Three Flames** (north-east): carry fire from the ancient fire up the hill (60 s) to light three braziers, or, as a Mage, shoot them with fire bolts. Unseals a chest.
- **Sky Pillar** (south-east lake): a jumping puzzle up a spiral of floating platforms, two of them moving.
- **Hidden chests**: 5 of 9 candidate spots are picked randomly per save (cliff top, beach, woods, behind a house...). One chest inside a village house belongs to someone, so opening it is stealing (−Alignment).
- **Loot and crafting**: gold, wood, iron ore, mana crystals, slime gel, healing items and trait dusts. 7 recipes (iron sword, crystal staff, iron bow, armour, charms, potions).
- **Equipment**: weapon, armour and accessory slots with class restrictions and stats.
- **Combat**: slimes that wander, chase and drop loot, plus a tougher Gloom Slime in the cave.
- **Lore stones**: 5 discoveries about the world's history, collected in the Journal.
- **Save/load**: JSON at `user://save.json`, including the trait history, flags, chests, puzzles and position.

## Project layout

```
autoload/   events.gd (signal bus) · game_state.gd · item_db.gd (loads data/) · save_system.gd
core/       pure logic, no scenes: personality, inventory, crafting, loot_table,
            chest_placement, equipment, dialogue_logic, player_profile
data/       items.json · recipes.json · loot_tables.json · lore.json · quests.json · dialogue/*.json
entities/   player (controller, model, projectiles) · npc · monster/slime · chest · props
gates/      trait_gate.gd: blocks a passage unless a trait is in range
puzzles/    puzzle.gd (base) · brazier_puzzle · jump_puzzle · moving_platform
world/      world.gd (builds the island) · terrain · nature · village · cave · mats (materials)
ui/         character_creator · hud · dialogue_box · game_menu · radar_chart · ui_style
tests/      run_tests.gd (unit + data) · integration_test (plays the loop) · screenshots
```

All geometry is grey-box, built from primitives in code, so it can be swapped for real
models (Kenney / Quaternius packs) without touching gameplay.

## Adding content (no new code needed)

- **Item**: add an entry to `data/items.json` (`category`: `craft`, `weapon` or `other`; optional `slot`, `job`, `attack`, `defense`, `max_hp`, `use`: `heal`/`trait`).
- **Recipe**: add `{"output": id, "inputs": {id: n}}` to `data/recipes.json`.
- **Dialogue**: add `data/dialogue/<id>.json` and point an NPC at it in `world/world.gd` (`NPCS`). A choice can carry:
  - `effects`: `{"kindness": 1}` with a `reason` (logged in the Journal)
  - `require`: `{"trait": "courage", "min": 2}` or `{"gold": 5}` (shown as `[Courage 2]`)
  - `give`, `take`, `gold`, `set_flag`, `if_flag` / `unless_flag`, `next`
- **Trait gate**: create a `TraitGate` with `trait_name`, `min_value` / `max_value` and `refusal_line`.
- **Chest spot**: add a `Vector2` to `HIDDEN_CHEST_SPOTS` in `world/world.gd`.

## Tests

```sh
godot --headless --path . -s tests/run_tests.gd                   # 222 unit + data-integrity checks
godot --headless --path . res://tests/integration_test.tscn       # 68 checks playing the core loop
godot --path . res://tests/screenshots.tscn -- /some/output/dir   # reference screenshots (opens a window)
```

The data-integrity tests catch broken references, such as a recipe using an unknown item,
a dialogue `next` pointing to a missing node, or an effect on a trait that doesn't exist.
Run them after editing `data/`.

## Open design questions

- The Profile chart is a **pentagon** (5 traits). Add a 6th trait (e.g. Curiosity) for a hexagon. The chart and systems handle any number of traits.
- **Trait dusts** stay as a rare chest boost on top of behaviour-driven changes. Remove them from `data/loot_tables.json` if traits should change through behaviour only.

## Natural next steps

Real art and animations · climbing and gliding · a bigger map using the Terrain3D addon ·
more puzzle types (pressure plates, elemental water/wind) · crafting stations · day/night ·
NPC reactions to personality (e.g. greetings that change with Alignment) · sound and music.
