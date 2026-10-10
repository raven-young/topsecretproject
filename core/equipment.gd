class_name Equipment
extends RefCounted
## Equipped item per slot. Equipping moves the item out of the inventory;
## unequipping puts it back.

const SLOTS := ["weapon", "armor", "accessory"]

var slots: Dictionary = {"weapon": "", "armor": "", "accessory": ""}


static func can_equip(item_def: Dictionary, job: String) -> bool:
	if not item_def.get("slot", "") in SLOTS:
		return false
	var required_job: String = item_def.get("job", "")
	return required_job == "" or required_job == job


func equip(id: String, item_def: Dictionary, inventory, job: String) -> bool:
	if not can_equip(item_def, job) or not inventory.has(id):
		return false
	var slot: String = item_def["slot"]
	inventory.remove(id)
	if slots[slot] != "":
		inventory.add(slots[slot])
	slots[slot] = id
	return true


func unequip(slot: String, inventory) -> bool:
	if slots.get(slot, "") == "":
		return false
	inventory.add(slots[slot])
	slots[slot] = ""
	return true


func total_stat(stat: String, item_defs: Dictionary) -> int:
	var total := 0
	for slot in SLOTS:
		if slots[slot] != "":
			total += int(item_defs.get(slots[slot], {}).get(stat, 0))
	return total


func to_dict() -> Dictionary:
	return slots.duplicate()


func load_dict(data: Dictionary) -> void:
	for slot in SLOTS:
		slots[slot] = str(data.get(slot, ""))
