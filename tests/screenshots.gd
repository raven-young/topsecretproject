extends Node
## Captures a few reference screenshots (needs a real window, not --headless).
## Run: godot --path . res://tests/screenshots.tscn -- <output_dir>

var out_dir := "user://screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)

	var creator: Control = load("res://ui/character_creator.tscn").instantiate()
	add_child(creator)
	await _wait(30)
	_shot("01_creator")
	creator.queue_free()

	var profile := PlayerProfile.new()
	profile.player_name = "Ana"
	profile.job = "mage"
	profile.appearance = {"hair_style": 3, "hair_color": 3, "face": 0, "body": 1, "skin": 1}
	GameState.new_game(profile)
	var world: Node3D = load("res://world/main.tscn").instantiate()
	add_child(world)
	var player: Player = world.player
	await _wait(60)
	_shot("02_village")

	player.global_position = Vector3(-55, 6, 10)
	player._yaw.rotation.y = PI / 2.0
	await _wait(40)
	_shot("03_cave_entrance")

	player.global_position = world.ground(Terrain.HILL_CENTER.x, Terrain.HILL_CENTER.y + 14) + Vector3.UP
	player._yaw.rotation.y = 0.0
	player._arm.rotation.x = -0.6
	await _wait(40)
	_shot("04_hill_braziers")

	player.global_position = Vector3(Terrain.LAKE_CENTER.x + 24, 3, Terrain.LAKE_CENTER.y)
	player._yaw.rotation.y = PI / 2.0
	player._arm.rotation.x = -0.1
	await _wait(40)
	_shot("05_sky_pillar")

	player.global_position = Vector3(-60, 6, 10)
	await _wait(20)
	_shot("06_cave_closeup")

	GameState.change_trait("kindness", 2, "Screenshot setup")
	GameState.change_trait("courage", 1, "Screenshot setup")
	for child in world.get_children():
		if child is DialogueBox:
			child.open_dialogue("guard", "Guard Tomas")
	await _wait(10)
	_shot("07_dialogue")
	for child in world.get_children():
		if child is DialogueBox:
			child._close()
		if child is GameMenu:
			child.open("Profile")
	await _wait(10)
	_shot("08_profile_menu")
	get_tree().quit()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name: String) -> void:
	var path := out_dir.path_join(name + ".png")
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
