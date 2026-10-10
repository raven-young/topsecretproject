class_name Inventory
extends RefCounted
## Item stacks (item_id -> count) plus gold.

signal changed

var items: Dictionary = {}
var gold := 0


func add(id: String, amount := 1) -> void:
	if id == "" or amount <= 0:
		return
	items[id] = count(id) + amount
	changed.emit()


func remove(id: String, amount := 1) -> bool:
	if amount <= 0 or count(id) < amount:
		return false
	items[id] = count(id) - amount
	if items[id] == 0:
		items.erase(id)
	changed.emit()
	return true


func count(id: String) -> int:
	return int(items.get(id, 0))


func has(id: String, amount := 1) -> bool:
	return count(id) >= amount


## Adds (or with a negative amount, spends) gold. Fails if it would go below 0.
func add_gold(amount: int) -> bool:
	if gold + amount < 0:
		return false
	gold += amount
	changed.emit()
	return true


## Item ids whose definition has the given category, sorted by display name.
func ids_in_category(category: String, item_defs: Dictionary) -> Array:
	var ids := items.keys().filter(func(id): return item_defs.get(id, {}).get("category", "other") == category)
	ids.sort_custom(func(a, b): return str(item_defs[a].get("name", a)) < str(item_defs[b].get("name", b)))
	return ids


func to_dict() -> Dictionary:
	return {"items": items.duplicate(), "gold": gold}


func load_dict(data: Dictionary) -> void:
	items = {}
	var saved: Dictionary = data.get("items", {})
	for id in saved:
		if int(saved[id]) > 0:
			items[id] = int(saved[id])
	gold = maxi(0, int(data.get("gold", 0)))
	changed.emit()
