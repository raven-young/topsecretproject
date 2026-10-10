extends Node
## Read-only game content loaded from data/*.json: items, recipes, loot
## tables, lore and quests. Dialogue files are loaded on demand.

var items: Dictionary = {}
var recipes: Array = []
var loot_tables: Dictionary = {}
var lore: Dictionary = {}
var quests: Dictionary = {}


func _ready() -> void:
	items = _as_dict(load_json("res://data/items.json"))
	loot_tables = _as_dict(load_json("res://data/loot_tables.json"))
	lore = _as_dict(load_json("res://data/lore.json"))
	quests = _as_dict(load_json("res://data/quests.json"))
	var recipe_data = load_json("res://data/recipes.json")
	recipes = recipe_data if recipe_data is Array else []


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	return str(get_item(id).get("name", id))


func load_dialogue(id: String) -> Dictionary:
	return _as_dict(load_json("res://data/dialogue/%s.json" % id))


static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data file: %s" % path)
		return null
	var data = JSON.parse_string(file.get_as_text())
	if data == null:
		push_error("Invalid JSON in %s" % path)
	return data


static func _as_dict(data: Variant) -> Dictionary:
	return data if data is Dictionary else {}
