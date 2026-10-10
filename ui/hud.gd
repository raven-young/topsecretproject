class_name Hud
extends CanvasLayer
## On-screen info: health, stamina, gold, interaction prompt, the player's
## spoken thoughts and toast notifications (loot, trait changes...).

var _hp_bar: ProgressBar
var _hp_label: Label
var _stamina_bar: ProgressBar
var _gold_label: Label
var _flame_label: Label
var _prompt: Label
var _speech: PanelContainer
var _speech_label: Label
var _speech_time := 0.0
var _toasts: VBoxContainer


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)

	var status := PanelContainer.new()
	status.position = Vector2(20, 20)
	status.add_theme_stylebox_override("panel", UIStyle.panel(Color(0.08, 0.09, 0.13, 0.7)))
	root.add_child(status)
	var col := VBoxContainer.new()
	status.add_child(col)
	var profile := GameState.profile
	col.add_child(UIStyle.label("%s  ·  %s" % [profile.player_name, profile.job.capitalize()], 20, UIStyle.ACCENT))
	_hp_bar = UIStyle.bar(Color("#d9534f"), 16)
	col.add_child(_hp_bar)
	_hp_label = UIStyle.label("", 14, UIStyle.MUTED)
	col.add_child(_hp_label)
	_stamina_bar = UIStyle.bar(Color("#7ccf6a"), 8)
	col.add_child(_stamina_bar)
	_gold_label = UIStyle.label("", 16, UIStyle.ACCENT)
	col.add_child(_gold_label)
	_flame_label = UIStyle.label("", 16, Color("#ff9a3c"))
	col.add_child(_flame_label)

	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.position = Vector2(-440, 20)
	_toasts.custom_minimum_size = Vector2(420, 0)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	_prompt = UIStyle.label("", 22, UIStyle.TEXT)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-300, -120)
	_prompt.size = Vector2(600, 30)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(_prompt)

	_speech = PanelContainer.new()
	_speech.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speech.position = Vector2(-380, -230)
	_speech.custom_minimum_size = Vector2(760, 0)
	_speech.visible = false
	root.add_child(_speech)
	_speech_label = UIStyle.label("", 20, UIStyle.TEXT, true)
	_speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech.add_child(_speech_label)

	var help := UIStyle.label("WASD move · Shift sprint · Space jump · E interact · LMB attack · Tab menu · I inventory · P profile · F5 save", 14, UIStyle.MUTED)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(20, -34)
	root.add_child(help)

	if profile.job != "fighter":
		var crosshair := UIStyle.label("+", 26, Color(1, 1, 1, 0.7))
		crosshair.set_anchors_preset(Control.PRESET_CENTER)
		crosshair.position = Vector2(-7, -18)
		root.add_child(crosshair)

	Events.toast.connect(_toast)
	Events.trait_changed.connect(_on_trait_changed)
	Events.player_say.connect(_say)
	Events.interaction_prompt.connect(func(text: String): _prompt.text = text)


func _process(delta: float) -> void:
	var max_hp := GameState.max_hp()
	_hp_bar.max_value = max_hp
	_hp_bar.value = GameState.hp
	_hp_label.text = "HP %d / %d" % [GameState.hp, max_hp]
	_gold_label.text = "%d gold" % GameState.inventory.gold
	var player := get_tree().get_first_node_in_group("player") as Player
	if player:
		_stamina_bar.value = player.stamina
		_flame_label.text = "Carrying fire: %ds" % ceili(player.flame_time) if player.flame_time > 0.0 else ""
	if _speech_time > 0.0:
		_speech_time -= delta
		if _speech_time <= 0.0:
			_speech.visible = false


func _say(text: String) -> void:
	_speech_label.text = "%s: \"%s\"" % [GameState.profile.player_name, text]
	_speech.visible = true
	_speech_time = 4.5


func _on_trait_changed(trait_name: String, new_value: int, delta: int, reason: String) -> void:
	var color := UIStyle.GOOD if delta > 0 else UIStyle.BAD
	_toast("%s %s  (now %s)\n%s" % [trait_name.capitalize(), Personality.signed(delta), Personality.signed(new_value), reason], color)


func _toast(text: String, color := UIStyle.TEXT) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIStyle.panel(Color(0.08, 0.09, 0.13, 0.82), 8, 10))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIStyle.label(text, 17, color, true)
	box.add_child(l)
	_toasts.add_child(box)
	while _toasts.get_child_count() > 7:
		_toasts.get_child(0).free()
	var tween := box.create_tween()
	tween.tween_interval(3.5)
	tween.tween_property(box, "modulate:a", 0.0, 0.6)
	tween.tween_callback(box.queue_free)
