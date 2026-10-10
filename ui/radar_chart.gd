class_name RadarChart
extends Control
## Personality radar chart over N axes. The scale runs -10..10, with 0 drawn
## as the highlighted middle ring so negative traits are visible.

var labels: Array = []
var values: Array = []
var min_value := -10.0
var max_value := 10.0
var fill_color := Color(0.91, 0.73, 0.29, 0.35)
var line_color := Color("#e9b949")
var grid_color := Color(1, 1, 1, 0.12)
var zero_color := Color(1, 1, 1, 0.4)


func set_data(new_labels: Array, new_values: Array) -> void:
	labels = new_labels
	values = new_values
	queue_redraw()


func _draw() -> void:
	var n := labels.size()
	if n < 3:
		return
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 56.0
	for ring in [-10, -5, 0, 5, 10]:
		var pts := PackedVector2Array()
		for i in n + 1:
			pts.append(center + _dir(i % n, n) * radius * _ratio(ring))
		draw_polyline(pts, zero_color if ring == 0 else grid_color, 2.0 if ring == 0 else 1.0, true)
	for i in n:
		draw_line(center, center + _dir(i, n) * radius, grid_color, 1.0, true)

	var points := PackedVector2Array()
	for i in n:
		points.append(center + _dir(i, n) * radius * maxf(_ratio(values[i]), 0.03))
	for i in n:
		draw_colored_polygon(PackedVector2Array([center, points[i], points[(i + 1) % n]]), fill_color)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, line_color, 2.5, true)
	for p in points:
		draw_circle(p, 4.0, line_color)

	var font := get_theme_default_font()
	var font_size := 17
	for i in n:
		var text := "%s %s" % [labels[i], Personality.signed(int(values[i]))]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var anchor := center + _dir(i, n) * (radius + 30.0)
		draw_string(font, anchor - Vector2(text_size.x / 2.0, -font_size / 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UIStyle.TEXT)


func _ratio(value: float) -> float:
	return (value - min_value) / (max_value - min_value)


func _dir(i: int, n: int) -> Vector2:
	var angle := -PI / 2.0 + TAU * i / n
	return Vector2(cos(angle), sin(angle))
