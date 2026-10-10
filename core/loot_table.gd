class_name LootTable
extends RefCounted
## Rolls a loot table:
## {"gold": [min, max], "guaranteed": {id: n}, "rolls": [min, max],
##  "entries": [{"id": id, "weight": w, "count": [min, max]}]}
## An entry with an empty id is a "nothing" roll.


## Returns {"gold": int, "items": {id: count}}.
static func roll(table: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var result := {"gold": 0, "items": {}}
	var gold_range: Array = table.get("gold", [0, 0])
	result["gold"] = rng.randi_range(int(gold_range[0]), int(gold_range[1]))

	var guaranteed: Dictionary = table.get("guaranteed", {})
	for id in guaranteed:
		_add(result["items"], id, int(guaranteed[id]))

	var entries: Array = table.get("entries", [])
	var total_weight := 0.0
	for entry in entries:
		total_weight += float(entry.get("weight", 1))
	if total_weight <= 0.0:
		return result

	var roll_range: Array = table.get("rolls", [1, 1])
	var roll_count := rng.randi_range(int(roll_range[0]), int(roll_range[1]))
	for i in roll_count:
		var pick := rng.randf() * total_weight
		for entry in entries:
			pick -= float(entry.get("weight", 1))
			if pick <= 0.0:
				var count_range: Array = entry.get("count", [1, 1])
				_add(result["items"], str(entry.get("id", "")), rng.randi_range(int(count_range[0]), int(count_range[1])))
				break
	return result


static func _add(items: Dictionary, id: String, amount: int) -> void:
	if id == "" or amount <= 0:
		return
	items[id] = int(items.get(id, 0)) + amount
