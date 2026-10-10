class_name Personality
extends RefCounted
## The five personality traits. Every trait starts at 0 and only moves through
## what the player says and does. Pure logic, no scene access.

const TRAITS := ["courage", "empathy", "humbleness", "kindness", "alignment"]
const MIN_VALUE := -10
const MAX_VALUE := 10

var values: Dictionary = {}


func _init() -> void:
	for trait_name in TRAITS:
		values[trait_name] = 0


func get_value(trait_name: String) -> int:
	return int(values.get(trait_name, 0))


## Changes a trait and returns the delta actually applied after clamping.
func apply(trait_name: String, delta: int) -> int:
	if not values.has(trait_name):
		push_warning("Unknown trait: %s" % trait_name)
		return 0
	var old := get_value(trait_name)
	values[trait_name] = clampi(old + delta, MIN_VALUE, MAX_VALUE)
	return get_value(trait_name) - old


func meets(trait_name: String, min_value := MIN_VALUE, max_value := MAX_VALUE) -> bool:
	var value := get_value(trait_name)
	return value >= min_value and value <= max_value


func to_dict() -> Dictionary:
	return values.duplicate()


func load_dict(data: Dictionary) -> void:
	for trait_name in TRAITS:
		values[trait_name] = clampi(int(data.get(trait_name, 0)), MIN_VALUE, MAX_VALUE)


static func describe(trait_name: String, value: int) -> String:
	if trait_name == "alignment":
		if value >= 3:
			return "Good"
		if value <= -3:
			return "Evil"
		return "Neutral"
	if value <= -6:
		return "Very low"
	if value <= -2:
		return "Low"
	if value < 2:
		return "Neutral"
	if value < 6:
		return "High"
	return "Very high"


static func signed(value: int) -> String:
	return ("+%d" % value) if value > 0 else str(value)
