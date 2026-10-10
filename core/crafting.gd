class_name Crafting
extends RefCounted
## Recipe checks and crafting. A recipe is
## {"output": id, "count": n, "inputs": {id: amount}}.


## Item id -> how many more are needed. Empty when the recipe can be crafted.
static func missing(recipe: Dictionary, inventory) -> Dictionary:
	var result := {}
	var inputs: Dictionary = recipe.get("inputs", {})
	for id in inputs:
		var short: int = int(inputs[id]) - inventory.count(id)
		if short > 0:
			result[id] = short
	return result


static func can_craft(recipe: Dictionary, inventory) -> bool:
	return missing(recipe, inventory).is_empty()


static func craft(recipe: Dictionary, inventory) -> bool:
	if not can_craft(recipe, inventory):
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for id in inputs:
		inventory.remove(id, int(inputs[id]))
	inventory.add(recipe["output"], int(recipe.get("count", 1)))
	return true
