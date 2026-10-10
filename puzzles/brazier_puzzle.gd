class_name BrazierPuzzle
extends Puzzle
## Solved when every registered brazier is lit.

var braziers: Array[Brazier] = []


func add_brazier(brazier: Brazier) -> void:
	braziers.append(brazier)
	if is_solved:
		brazier.set_lit()
	brazier.lit.connect(_check)


func _check() -> void:
	for brazier in braziers:
		if not brazier.is_lit:
			Events.toast.emit("%d of %d flames lit" % [braziers.filter(func(b): return b.is_lit).size(), braziers.size()])
			return
	mark_solved()
