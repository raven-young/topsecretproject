extends Control
## Title + character creation: name, look and class, with a live 3D preview.
## Personality is not picked here: every trait starts at 0 and is shaped by
## play.

const JOB_INFO := {
	"fighter": ["Fighter", "Melee. Tough and strong up close. Swings a sword."],
	"mage": ["Mage", "Magic, ranged. Casts fire bolts, which can also light things..."],
	"ranger": ["Ranger", "Physical, ranged. Fires fast arrows from afar."],
}

var _profile := PlayerProfile.new()
var _model: CharacterModel
var _name_edit: LineEdit
var _start_button: Button
var _job_desc: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UIStyle.theme()
	var bg := ColorRect.new()
	bg.color = Color("#141826")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var layout := HBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 40
	layout.offset_top = 30
	layout.offset_right = -40
	layout.offset_bottom = -30
	layout.add_theme_constant_override("separation", 30)
	add_child(layout)
	layout.add_child(_build_preview())

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	layout.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 12)
	scroll.add_child(form)
	_build_form(form)


func _process(delta: float) -> void:
	if _model:
		_model.rotation.y += delta * 0.6


func _build_preview() -> Control:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1d2336")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8090b0")
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 30, 0)
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.25, 3.3)
	camera.rotation_degrees.x = -6.0
	camera.fov = 45.0
	viewport.add_child(camera)
	var pedestal := Node3D.new()
	viewport.add_child(pedestal)
	Mats.cylinder(pedestal, 0.9, 0.2, Color("#3a3f55"), Vector3(0, -0.1, 0))
	_model = CharacterModel.new()
	_model.appearance = _profile.appearance
	_model.job = _profile.job
	_model.set_weapon(GameState.STARTER_WEAPONS[_profile.job])
	viewport.add_child(_model)
	return container


func _build_form(form: VBoxContainer) -> void:
	form.add_child(UIStyle.label("Wanderlight", 40, UIStyle.ACCENT))
	form.add_child(UIStyle.label("An island waits beyond the village fence.", 18, UIStyle.MUTED))
	if SaveSystem.has_save():
		form.add_child(UIStyle.button("Continue your journey", _continue))
		form.add_child(HSeparator.new())

	form.add_child(UIStyle.label("Create your hero", 26, UIStyle.TEXT))
	form.add_child(UIStyle.label("Name", 16, UIStyle.MUTED))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Your hero's name"
	_name_edit.max_length = 20
	_name_edit.text_changed.connect(func(_t: String): _update_start())
	form.add_child(_name_edit)

	_option(form, "Hair style", CharacterModel.HAIR_STYLES, "hair_style")
	_swatches(form, "Hair colour", CharacterModel.HAIR_COLORS, "hair_color")
	_option(form, "Face", CharacterModel.FACES, "face")
	_option(form, "Body type", CharacterModel.BODY_TYPES, "body")
	_swatches(form, "Skin tone", CharacterModel.SKIN_TONES, "skin")

	form.add_child(UIStyle.label("Class", 16, UIStyle.MUTED))
	var jobs := HBoxContainer.new()
	form.add_child(jobs)
	var group := ButtonGroup.new()
	for job in PlayerProfile.JOBS:
		var btn := UIStyle.button(JOB_INFO[job][0], _set_job.bind(job))
		btn.toggle_mode = true
		btn.button_group = group
		btn.button_pressed = job == _profile.job
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		jobs.add_child(btn)
	_job_desc = UIStyle.label(JOB_INFO[_profile.job][1], 16, UIStyle.TEXT, true)
	form.add_child(_job_desc)

	form.add_child(HSeparator.new())
	form.add_child(UIStyle.label("Personality: Courage, Empathy, Humbleness, Kindness and Alignment all start at 0. Who you become depends on how you treat people and what you dare to do out there.", 16, UIStyle.MUTED, true))
	_start_button = UIStyle.button("Begin your adventure", _start)
	_start_button.disabled = true
	form.add_child(_start_button)


func _option(form: VBoxContainer, title: String, options: Array, key: String) -> void:
	form.add_child(UIStyle.label(title, 16, UIStyle.MUTED))
	var option := OptionButton.new()
	for o in options:
		option.add_item(o)
	option.selected = _profile.appearance[key]
	option.item_selected.connect(func(index: int): _set_look(key, index))
	form.add_child(option)


func _swatches(form: VBoxContainer, title: String, colors: Array, key: String) -> void:
	form.add_child(UIStyle.label(title, 16, UIStyle.MUTED))
	var row := HBoxContainer.new()
	form.add_child(row)
	var group := ButtonGroup.new()
	for i in colors.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(40, 40)
		btn.toggle_mode = true
		btn.button_group = group
		btn.button_pressed = i == _profile.appearance[key]
		for state in ["normal", "hover", "pressed", "focus"]:
			var sb := UIStyle.panel(Color(colors[i]), 20, 0)
			sb.border_color = UIStyle.ACCENT if state == "pressed" else Color(1, 1, 1, 0.2)
			sb.set_border_width_all(3 if state == "pressed" else 1)
			btn.add_theme_stylebox_override(state, sb)
		btn.pressed.connect(_set_look.bind(key, i))
		row.add_child(btn)


func _set_look(key: String, value: int) -> void:
	_profile.appearance[key] = value
	_model.appearance = _profile.appearance
	_model.rebuild()


func _set_job(job: String) -> void:
	_profile.job = job
	_job_desc.text = JOB_INFO[job][1]
	_model.job = job
	_model.set_weapon(GameState.STARTER_WEAPONS[job])
	_model.rebuild()


func _update_start() -> void:
	_start_button.disabled = _name_edit.text.strip_edges() == ""


func _start() -> void:
	_profile.player_name = _name_edit.text.strip_edges()
	GameState.new_game(_profile)
	get_tree().change_scene_to_file("res://world/main.tscn")


func _continue() -> void:
	if SaveSystem.load_game():
		get_tree().change_scene_to_file("res://world/main.tscn")
