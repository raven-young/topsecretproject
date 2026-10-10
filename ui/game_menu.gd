class_name GameMenu
extends CanvasLayer
## The adventurer's pack: Inventory, Crafting, Equipment, Profile (radar
## chart + trait dusts), Journal (quests, lore, personality history), System.
## Tab toggles it, I opens Inventory, P opens Profile, Esc opens System.

const TABS := ["Inventory", "Crafting", "Equipment", "Profile", "Journal", "System"]
const CATEGORIES := [["craft", "Craft Items"], ["weapon", "Weapons & Gear"], ["other", "Other"]]
const SLOT_NAMES := {"weapon": "Weapon", "armor": "Armor", "accessory": "Accessory"}

var is_open := false
var _root: Control
var _tabs: TabContainer
var _pages: Dictionary = {}
var _category := 0
var _selected_item := ""
var _selected_recipe := 0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 70
	panel.offset_top = 50
	panel.offset_right = -70
	panel.offset_bottom = -50
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var header := HBoxContainer.new()
	col.add_child(header)
	header.add_child(UIStyle.label("Adventurer's Pack", 28, UIStyle.ACCENT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header.add_child(UIStyle.label("Tab / Esc to close", 16, UIStyle.MUTED))

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_tabs)
	for tab_name in TABS:
		var page := MarginContainer.new()
		page.name = tab_name
		_tabs.add_child(page)
		_pages[tab_name] = page
	_tabs.tab_changed.connect(func(_index: int): _refresh())

	Events.inventory_changed.connect(_refresh_if_open)
	Events.equipment_changed.connect(_refresh_if_open)
	Events.trait_changed.connect(_refresh_if_open.unbind(4))
	Events.gold_changed.connect(_refresh_if_open.unbind(1))


func _refresh_if_open() -> void:
	if is_open:
		_refresh.call_deferred()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if GameState.is_ui_locked() and not is_open:
		return
	var tab := ""
	if event.is_action_pressed("menu"):
		tab = TABS[_tabs.current_tab]
	elif event.is_action_pressed("inventory"):
		tab = "Inventory"
	elif event.is_action_pressed("profile"):
		tab = "Profile"
	elif event.is_action_pressed("pause"):
		tab = "System"
	else:
		return
	get_viewport().set_input_as_handled()
	if is_open and (event.is_action_pressed("menu") or event.is_action_pressed("pause") or TABS[_tabs.current_tab] == tab):
		close()
	else:
		open(tab)


func open(tab: String) -> void:
	if not is_open:
		is_open = true
		_root.visible = true
		GameState.lock_ui()
	_tabs.current_tab = TABS.find(tab)
	_refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	GameState.unlock_ui()


func _refresh() -> void:
	var tab_name: String = TABS[_tabs.current_tab]
	var page: Control = _pages[tab_name]
	UIStyle.clear(page)
	match tab_name:
		"Inventory":
			_build_inventory(page)
		"Crafting":
			_build_crafting(page)
		"Equipment":
			_build_equipment(page)
		"Profile":
			_build_profile(page)
		"Journal":
			_build_journal(page)
		"System":
			_build_system(page)


# --- Inventory ----------------------------------------------------------------------

func _build_inventory(page: Control) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	page.add_child(col)
	var tabs := HBoxContainer.new()
	col.add_child(tabs)
	for i in CATEGORIES.size():
		var btn := UIStyle.button(CATEGORIES[i][1], _select_category.bind(i))
		btn.toggle_mode = true
		btn.button_pressed = i == _category
		tabs.add_child(btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	tabs.add_child(UIStyle.label("%d gold" % GameState.inventory.gold, 20, UIStyle.ACCENT))

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	col.add_child(body)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(420, 0)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(list)
	var ids := GameState.inventory.ids_in_category(CATEGORIES[_category][0], ItemDB.items)
	for id in ids:
		list.add_item("%s   x%d" % [ItemDB.item_name(id), GameState.inventory.count(id)])
		if id == _selected_item:
			list.select(list.item_count - 1)
	if ids.is_empty():
		list.add_item("(nothing here yet: go explore!)")
		list.set_item_disabled(0, true)
	list.item_selected.connect(_select_item.bind(ids))

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 10)
	body.add_child(details)
	if _selected_item == "" or not GameState.inventory.has(_selected_item):
		details.add_child(UIStyle.label("Select an item to see its details.", 18, UIStyle.MUTED))
		return
	var def := ItemDB.get_item(_selected_item)
	details.add_child(UIStyle.label(def.get("name", _selected_item), 26, UIStyle.ACCENT))
	details.add_child(UIStyle.label(def.get("desc", ""), 18, UIStyle.TEXT, true))
	details.add_child(UIStyle.label(_stat_line(def), 18, UIStyle.GOOD))
	if def.has("use"):
		details.add_child(UIStyle.button("Use", func(): GameState.use_item(_selected_item)))
	elif def.has("slot"):
		var btn := UIStyle.button("Equip", func(): GameState.equip_item(_selected_item))
		if not Equipment.can_equip(def, GameState.profile.job):
			btn.disabled = true
			btn.text = "Equip (%s only)" % str(def.get("job", "")).capitalize()
		details.add_child(btn)


func _select_category(index: int) -> void:
	_category = index
	_selected_item = ""
	_refresh()


func _select_item(index: int, ids: Array) -> void:
	if index < ids.size():
		_selected_item = ids[index]
		_refresh()


func _select_recipe(index: int) -> void:
	_selected_recipe = index
	_refresh()


func _stat_line(def: Dictionary) -> String:
	var parts: Array[String] = []
	for stat in [["attack", "ATK"], ["defense", "DEF"], ["max_hp", "Max HP"]]:
		if def.has(stat[0]):
			parts.append("+%d %s" % [int(def[stat[0]]), stat[1]])
	if def.has("slot"):
		parts.append(SLOT_NAMES.get(def["slot"], ""))
	if def.get("job", "") != "":
		parts.append("%s only" % str(def["job"]).capitalize())
	return "  ·  ".join(parts)


# --- Crafting -----------------------------------------------------------------------

func _build_crafting(page: Control) -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	page.add_child(body)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(420, 0)
	body.add_child(list)
	var recipes := ItemDB.recipes
	for i in recipes.size():
		var recipe: Dictionary = recipes[i]
		list.add_item(ItemDB.item_name(recipe["output"]))
		if not Crafting.can_craft(recipe, GameState.inventory):
			list.set_item_custom_fg_color(i, UIStyle.MUTED)
	_selected_recipe = clampi(_selected_recipe, 0, recipes.size() - 1)
	if recipes.is_empty():
		return
	list.select(_selected_recipe)
	list.item_selected.connect(_select_recipe)

	var recipe: Dictionary = recipes[_selected_recipe]
	var def := ItemDB.get_item(recipe["output"])
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 10)
	body.add_child(details)
	details.add_child(UIStyle.label(def.get("name", ""), 26, UIStyle.ACCENT))
	details.add_child(UIStyle.label(def.get("desc", ""), 18, UIStyle.TEXT, true))
	details.add_child(UIStyle.label(_stat_line(def), 18, UIStyle.GOOD))
	details.add_child(UIStyle.label("Requires:", 18, UIStyle.MUTED))
	var inputs: Dictionary = recipe["inputs"]
	for id in inputs:
		var have := GameState.inventory.count(id)
		var need := int(inputs[id])
		details.add_child(UIStyle.label("  %s   %d / %d" % [ItemDB.item_name(id), have, need], 18, UIStyle.GOOD if have >= need else UIStyle.BAD))
	var craft := UIStyle.button("Craft", func(): GameState.craft(recipe))
	craft.disabled = not Crafting.can_craft(recipe, GameState.inventory)
	details.add_child(craft)


# --- Equipment ----------------------------------------------------------------------

func _build_equipment(page: Control) -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 40)
	page.add_child(body)
	var slots_col := VBoxContainer.new()
	slots_col.custom_minimum_size = Vector2(520, 0)
	slots_col.add_theme_constant_override("separation", 12)
	body.add_child(slots_col)
	slots_col.add_child(UIStyle.label("Equipped", 24, UIStyle.ACCENT))
	for slot in Equipment.SLOTS:
		var row := HBoxContainer.new()
		slots_col.add_child(row)
		var name_label := UIStyle.label(SLOT_NAMES[slot], 18, UIStyle.MUTED)
		name_label.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_label)
		var id: String = GameState.equipment.slots[slot]
		var item_label := UIStyle.label(ItemDB.item_name(id) + "   " + _stat_line(ItemDB.get_item(id)) if id != "" else "(empty)", 18)
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_label)
		if id != "":
			row.add_child(UIStyle.button("Unequip", func(): GameState.unequip_slot(slot)))
	slots_col.add_child(HSeparator.new())
	slots_col.add_child(UIStyle.label("Attack %d   ·   Defense %d   ·   Max HP %d" % [GameState.attack_power(), GameState.defense(), GameState.max_hp()], 20, UIStyle.GOOD))

	var gear_col := VBoxContainer.new()
	gear_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_col.add_theme_constant_override("separation", 8)
	body.add_child(gear_col)
	gear_col.add_child(UIStyle.label("In your pack", 24, UIStyle.ACCENT))
	var any := false
	for id in GameState.inventory.ids_in_category("weapon", ItemDB.items):
		var def := ItemDB.get_item(id)
		var btn := UIStyle.button("Equip %s   %s" % [def.get("name", id), _stat_line(def)], func(): GameState.equip_item(id))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.disabled = not Equipment.can_equip(def, GameState.profile.job)
		gear_col.add_child(btn)
		any = true
	if not any:
		gear_col.add_child(UIStyle.label("No spare gear. Craft or find some!", 18, UIStyle.MUTED))


# --- Profile ------------------------------------------------------------------------

func _build_profile(page: Control) -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	page.add_child(body)
	var profile := GameState.profile

	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(320, 0)
	info.add_theme_constant_override("separation", 8)
	body.add_child(info)
	info.add_child(UIStyle.label(profile.player_name, 30, UIStyle.ACCENT))
	info.add_child(UIStyle.label(profile.job.capitalize(), 20))
	var look := profile.appearance
	info.add_child(UIStyle.label("%s hair · %s face · %s build" % [
		CharacterModel.HAIR_STYLES[look["hair_style"]], CharacterModel.FACES[look["face"]], CharacterModel.BODY_TYPES[look["body"]]], 16, UIStyle.MUTED, true))
	info.add_child(HSeparator.new())
	info.add_child(UIStyle.label("Attack %d · Defense %d" % [GameState.attack_power(), GameState.defense()], 18))
	info.add_child(UIStyle.label("HP %d / %d" % [GameState.hp, GameState.max_hp()], 18))
	info.add_child(UIStyle.label("Chests opened: %d" % GameState.opened_chests.size(), 18))
	info.add_child(UIStyle.label("Discoveries: %d / %d" % [GameState.lore_found.size(), ItemDB.lore.size()], 18))
	info.add_child(UIStyle.label("Puzzles solved: %d" % GameState.solved_puzzles.size(), 18))
	info.add_child(HSeparator.new())
	info.add_child(UIStyle.label("Everyone starts at 0. Your traits grow and shrink with what you say and do, and some places and conversations open only to certain personalities.", 15, UIStyle.MUTED, true))

	var chart := RadarChart.new()
	chart.custom_minimum_size = Vector2(440, 440)
	var names: Array = Personality.TRAITS.map(func(t): return str(t).capitalize())
	var values: Array = Personality.TRAITS.map(func(t): return GameState.personality.get_value(t))
	chart.set_data(names, values)
	body.add_child(chart)

	var traits := VBoxContainer.new()
	traits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	traits.add_theme_constant_override("separation", 10)
	body.add_child(traits)
	traits.add_child(UIStyle.label("Personality", 24, UIStyle.ACCENT))
	for t in Personality.TRAITS:
		var value := GameState.personality.get_value(t)
		var row := HBoxContainer.new()
		traits.add_child(row)
		var name_label := UIStyle.label(t.capitalize(), 18)
		name_label.custom_minimum_size = Vector2(130, 0)
		row.add_child(name_label)
		var value_label := UIStyle.label(Personality.signed(value), 18, UIStyle.GOOD if value > 0 else (UIStyle.BAD if value < 0 else UIStyle.TEXT))
		value_label.custom_minimum_size = Vector2(50, 0)
		row.add_child(value_label)
		row.add_child(UIStyle.label(Personality.describe(t, value), 16, UIStyle.MUTED))
		var dust_id := "dust_%s" % t
		if GameState.inventory.has(dust_id):
			row.add_child(UIStyle.button("Use %s (x%d)" % [ItemDB.item_name(dust_id), GameState.inventory.count(dust_id)], func(): GameState.use_item(dust_id)))


# --- Journal ------------------------------------------------------------------------

func _build_journal(page: Control) -> void:
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	page.add_child(body)

	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	left_scroll.add_child(left)
	left.add_child(UIStyle.label("Quests", 24, UIStyle.ACCENT))
	var any_quest := false
	for flag in ItemDB.quests:
		if not GameState.has_flag(flag):
			continue
		any_quest = true
		var quest: Dictionary = ItemDB.quests[flag]
		var done: bool = quest.get("done_flag", "") != "" and GameState.has_flag(quest["done_flag"])
		left.add_child(UIStyle.label(("✓ " if done else "• ") + quest["title"], 20, UIStyle.MUTED if done else UIStyle.TEXT))
		if not done:
			left.add_child(UIStyle.label(quest["desc"], 16, UIStyle.MUTED, true))
	if not any_quest:
		left.add_child(UIStyle.label("No quests yet. Talk to the villagers.", 16, UIStyle.MUTED))
	left.add_child(HSeparator.new())
	left.add_child(UIStyle.label("Discoveries", 24, UIStyle.ACCENT))
	for lore_id in GameState.lore_found:
		var entry: Dictionary = ItemDB.lore.get(lore_id, {})
		left.add_child(UIStyle.label(entry.get("title", lore_id), 19, UIStyle.TEXT))
		left.add_child(UIStyle.label(entry.get("text", ""), 15, UIStyle.MUTED, true))
	if GameState.lore_found.is_empty():
		left.add_child(UIStyle.label("Find and read the carved stones around the island.", 16, UIStyle.MUTED))

	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	right_scroll.add_child(right)
	right.add_child(UIStyle.label("Who you're becoming", 24, UIStyle.ACCENT))
	if GameState.trait_log.is_empty():
		right.add_child(UIStyle.label("Your choices will be remembered here.", 16, UIStyle.MUTED))
	for entry in GameState.trait_log.slice(0, 40):
		var delta := int(entry["delta"])
		right.add_child(UIStyle.label("%s %s  ·  %s" % [str(entry["trait"]).capitalize(), Personality.signed(delta), entry["reason"]], 16, UIStyle.GOOD if delta > 0 else UIStyle.BAD, true))


# --- System -------------------------------------------------------------------------

func _build_system(page: Control) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(360, 0)
	page.add_child(col)
	col.add_child(UIStyle.label("Game", 24, UIStyle.ACCENT))
	col.add_child(UIStyle.button("Resume", close))
	col.add_child(UIStyle.button("Save game", func(): SaveSystem.save_game()))
	col.add_child(UIStyle.button("Save and quit to title", func():
		SaveSystem.save_game()
		GameState.release_all_locks()
		get_tree().change_scene_to_file("res://ui/character_creator.tscn")))
	col.add_child(UIStyle.button("Save and quit game", func():
		SaveSystem.save_game()
		get_tree().quit()))
	col.add_child(UIStyle.label("Saves to %s" % ProjectSettings.globalize_path(SaveSystem.SAVE_PATH), 14, UIStyle.MUTED, true))
