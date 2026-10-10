class_name DialogueLogic
extends RefCounted
## Rules for data-driven dialogue (see data/dialogue/*.json):
## - "starts": [{"if_flag": f | [f], "unless_flag": f | [f], "node": id}], first match wins,
##   falling back to "start".
## - A choice may carry "require": {"trait": t, "min": n, "max": n, "gold": n}; unmet
##   requirements show the choice disabled with a tag like "[Courage 2]".
## - Choices and nodes ("on_enter") may carry "effects", "gold", "give", "take", "set_flag".


static func pick_start(dialogue: Dictionary, flags: Dictionary) -> String:
	for entry in dialogue.get("starts", []):
		if conditions_met(entry, flags):
			return str(entry.get("node", ""))
	return str(dialogue.get("start", ""))


static func conditions_met(cond: Dictionary, flags: Dictionary) -> bool:
	for flag in _as_list(cond.get("if_flag")):
		if not flags.get(flag, false):
			return false
	for flag in _as_list(cond.get("unless_flag")):
		if flags.get(flag, false):
			return false
	return true


## Empty string when the choice can be picked, otherwise what is missing.
static func locked_reason(choice: Dictionary, personality, gold: int) -> String:
	var req: Dictionary = choice.get("require", {})
	if req.has("trait"):
		var trait_name: String = req["trait"]
		var value: int = personality.get_value(trait_name)
		if req.has("min") and value < int(req["min"]):
			return "%s %d (you have %d)" % [trait_name.capitalize(), int(req["min"]), value]
		if req.has("max") and value > int(req["max"]):
			return "%s at most %d (you have %d)" % [trait_name.capitalize(), int(req["max"]), value]
	if req.has("gold") and gold < int(req["gold"]):
		return "%d gold" % int(req["gold"])
	return ""


## The "[Courage 2] " prefix shown on trait-gated choices.
static func tag(choice: Dictionary) -> String:
	var req: Dictionary = choice.get("require", {})
	if not req.has("trait"):
		return ""
	var trait_label := str(req["trait"]).capitalize()
	if req.has("min"):
		return "[%s %d] " % [trait_label, int(req["min"])]
	if req.has("max"):
		return "[%s ≤ %d] " % [trait_label, int(req["max"])]
	return ""


static func _as_list(value: Variant) -> Array:
	if value is Array:
		return value
	if value is String and value != "":
		return [value]
	return []
