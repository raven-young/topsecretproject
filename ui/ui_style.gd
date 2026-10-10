class_name UIStyle
extends RefCounted
## Shared colours, theme and small widget helpers for all menus.

const BG := Color(0.08, 0.09, 0.13, 0.94)
const PANEL_LIGHT := Color(0.14, 0.15, 0.21, 0.95)
const ACCENT := Color("#e9b949")
const TEXT := Color("#f2ead8")
const MUTED := Color("#a49d8c")
const GOOD := Color("#8fd47a")
const BAD := Color("#e8757a")

static var _theme: Theme


static func panel(color := BG, radius := 12, padding := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(padding)
	sb.border_color = Color(ACCENT, 0.35)
	sb.set_border_width_all(1)
	return sb


static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font_size = 18
	_theme.set_stylebox("panel", "PanelContainer", panel())
	_theme.set_stylebox("panel", "Panel", panel())
	_theme.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := panel(PANEL_LIGHT, 8, 10)
		match state:
			"hover":
				sb.bg_color = PANEL_LIGHT.lightened(0.12)
				sb.border_color = ACCENT
			"pressed":
				sb.bg_color = Color(ACCENT, 0.35)
				sb.border_color = ACCENT
			"disabled":
				sb.bg_color = Color(PANEL_LIGHT, 0.5)
				sb.border_color = Color(MUTED, 0.2)
			"focus":
				sb.draw_center = false
				sb.border_color = ACCENT
				sb.set_border_width_all(2)
		_theme.set_stylebox(state, "Button", sb)
	_theme.set_color("font_color", "Button", TEXT)
	_theme.set_color("font_hover_color", "Button", ACCENT)
	_theme.set_color("font_disabled_color", "Button", MUTED)
	_theme.set_stylebox("panel", "TabContainer", panel(BG, 10, 16))
	_theme.set_stylebox("panel", "ItemList", panel(PANEL_LIGHT, 8, 8))
	_theme.set_color("font_color", "ItemList", TEXT)
	_theme.set_stylebox("normal", "LineEdit", panel(PANEL_LIGHT, 8, 10))
	return _theme


static func label(text: String, size := 18, color := TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	return b


static func bar(color: Color, height := 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(240, height)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.5)
	back.set_corner_radius_all(4)
	b.add_theme_stylebox_override("fill", fill)
	b.add_theme_stylebox_override("background", back)
	return b


static func clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
