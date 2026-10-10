class_name PlayerProfile
extends RefCounted
## Who the player created: name, class and look. Appearance values are
## indices into the option lists in CharacterModel.

const JOBS := ["fighter", "mage", "ranger"]

var player_name := "Wanderer"
var job := "fighter"
var appearance: Dictionary = {"hair_style": 0, "hair_color": 0, "face": 0, "body": 1, "skin": 1}


func to_dict() -> Dictionary:
	return {"name": player_name, "job": job, "appearance": appearance.duplicate()}


func load_dict(data: Dictionary) -> void:
	player_name = str(data.get("name", "Wanderer"))
	var saved_job := str(data.get("job", "fighter"))
	job = saved_job if saved_job in JOBS else "fighter"
	var saved_look: Dictionary = data.get("appearance", {})
	for key in appearance:
		appearance[key] = int(saved_look.get(key, appearance[key]))
