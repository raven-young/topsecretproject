class_name DialogueBox
extends CanvasLayer
## Plays data-driven dialogue (data/dialogue/*.json) and lore texts. Choices
## can change traits, require traits, cost gold, give items and set flags.
## Keys 1-9 pick a choice, Esc leaves.

var _root: Control
var _speaker: Label
var _text: Label
var _choices: VBoxContainer
var _dialogue: Dictionary = {}
var _npc_name := ""
var _open := false


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	_root.visible = false
	add_child(_root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 220
	panel.offset_right = -220
	panel.offset_top = -200
	panel.offset_bottom = -30
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	_speaker = UIStyle.label("", 24, UIStyle.ACCENT)
	col.add_child(_speaker)
	_text = UIStyle.label("", 20, UIStyle.TEXT, true)
	col.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	col.add_child(_choices)

	Events.dialogue_requested.connect(open_dialogue)
	Events.show_text.connect(open_text)


func open_dialogue(dialogue_id: String, npc_name: String) -> void:
	var dialogue := ItemDB.load_dialogue(dialogue_id)
	if dialogue.is_empty():
		return
	_dialogue = dialogue
	_npc_name = npc_name
	_begin()
	_show_node(DialogueLogic.pick_start(_dialogue, GameState.flags))


func open_text(title: String, text: String) -> void:
	_dialogue = {"nodes": {"text": {"speaker": title, "text": text}}}
	_npc_name = title
	_begin()
	_show_node("text")


func _begin() -> void:
	if not _open:
		_open = true
		_root.visible = true
		GameState.lock_ui()


func _show_node(node_id: String) -> void:
	var node: Dictionary = _dialogue.get("nodes", {}).get(node_id, {})
	if node.is_empty():
		_close()
		return
	if node.has("on_enter"):
		GameState.apply_dialogue_outcome(node["on_enter"], _npc_name)
	_speaker.text = node.get("speaker", _npc_name)
	_text.text = _format(node.get("text", ""))
	UIStyle.clear(_choices)

	var shown := 0
	for choice in node.get("choices", []):
		if not DialogueLogic.conditions_met(choice, GameState.flags):
			continue
		shown += 1
		var locked := DialogueLogic.locked_reason(choice, GameState.personality, GameState.inventory.gold)
		var btn := UIStyle.button("%d. %s%s" % [shown, DialogueLogic.tag(choice), _format(choice.get("text", "..."))], _choose.bind(choice))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if locked != "":
			btn.disabled = true
			btn.tooltip_text = "Requires " + locked
			btn.text += "   (needs %s)" % locked
		_choices.add_child(btn)
	if shown == 0:
		var next: String = node.get("next", "")
		_choices.add_child(UIStyle.button("Continue" if next != "" else "Leave", _advance.bind(next)))
	_focus_first.call_deferred()


func _focus_first() -> void:
	for btn in _choices.get_children():
		if btn is Button and not btn.disabled:
			btn.grab_focus()
			return


func _choose(choice: Dictionary) -> void:
	GameState.apply_dialogue_outcome(choice, _npc_name)
	_advance(choice.get("next", ""))


func _advance(next: String) -> void:
	if next == "":
		_close()
	else:
		_show_node(next)


func _close() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	GameState.unlock_ui()
	Events.dialogue_finished.emit()


func _input(event: InputEvent) -> void:
	if not _open or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action_pressed("pause"):
		_close()
		get_viewport().set_input_as_handled()
		return
	var number: int = event.physical_keycode - KEY_1
	var buttons := _choices.get_children()
	if number >= 0 and number < buttons.size():
		var btn: Button = buttons[number]
		if not btn.disabled:
			btn.pressed.emit()
		get_viewport().set_input_as_handled()


func _format(text: String) -> String:
	return text.replace("{name}", GameState.profile.player_name)
