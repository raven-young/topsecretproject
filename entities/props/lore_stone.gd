class_name LoreStone
extends StaticBody3D
## A carved standing stone. Reading it adds an entry to the journal.

var lore_id := ""


func _ready() -> void:
	add_to_group("interactable")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.8, 0.4)
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	Mats.box(self, Vector3(0.9, 1.8, 0.4), Color("#7f8a8c"), Vector3(0, 0.9, 0), Vector3(0.05, 0, 0.04))
	Mats.box(self, Vector3(0.5, 0.6, 0.05), Color("#6be4ff"), Vector3(0, 1.1, 0.21)).material_override = Mats.toon(Color("#6be4ff"), 1.5)


func get_prompt() -> String:
	return "Read the old stone" + ("" if GameState.lore_found.has(lore_id) else " (new)")


func interact(_player: Node) -> void:
	var entry: Dictionary = ItemDB.lore.get(lore_id, {})
	GameState.discover_lore(lore_id)
	Events.show_text.emit(entry.get("title", "Old Stone"), entry.get("text", "The carving is worn away."))
