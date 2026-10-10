extends Node
## Writes and reads GameState as JSON in the user data folder.

const SAVE_PATH := "user://save.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save file: %s" % FileAccess.get_open_error())
		Events.toast.emit("Saving failed!")
		return false
	file.store_string(JSON.stringify(GameState.to_dict(), "\t"))
	Events.toast.emit("Game saved")
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		push_error("Save file is corrupted")
		return false
	GameState.from_dict(data)
	return true
