class_name ChestPlacement
extends RefCounted
## Picks which candidate spots get a hidden chest. Seeded per save, so every
## playthrough has a different layout that stays the same across loads.


## Returns `amount` distinct indices in [0, candidate_count).
static func pick(candidate_count: int, amount: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var indices := range(candidate_count)
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	return indices.slice(0, mini(amount, candidate_count))
