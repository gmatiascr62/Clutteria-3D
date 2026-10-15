class_name VectorIcon
extends Control
## Íconos dibujados con polígonos (no dependen de glifos de la fuente).

@export var kind := "star"
@export var color := Color(1, 0.8, 0.2)
@export var filled := true


static func make(p_kind: String, p_color: Color, size := 28.0, p_filled := true) -> VectorIcon:
	var i := VectorIcon.new()
	i.kind = p_kind
	i.color = p_color
	i.filled = p_filled
	i.custom_minimum_size = Vector2(size, size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func set_filled(v: bool) -> void:
	filled = v
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var col := color if filled else Color(color, 0.25)
	match kind:
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var r := s * (0.48 if i % 2 == 0 else 0.2)
				var a := -PI / 2 + i * PI / 5
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, col)
		"coin":
			draw_circle(c, s * 0.45, col.darkened(0.2))
			draw_circle(c, s * 0.36, col)
			draw_rect(Rect2(c - Vector2(s * 0.06, s * 0.2), Vector2(s * 0.12, s * 0.4)), col.darkened(0.25))
		"heart":
			var pts := PackedVector2Array()
			for i in 40:
				var t := TAU * i / 40.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts.append(c + Vector2(x, y) * s / 36.0)
			draw_colored_polygon(pts, col)
		"clock":
			draw_circle(c, s * 0.45, col)
			draw_circle(c, s * 0.36, Color(0.1, 0.12, 0.16))
			draw_line(c, c + Vector2(0, -s * 0.28), col, 3)
			draw_line(c, c + Vector2(s * 0.2, 0), col, 3)
		"pause":
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.35), Vector2(s * 0.2, s * 0.7)), col)
			draw_rect(Rect2(c + Vector2(s * 0.1, -s * 0.35), Vector2(s * 0.2, s * 0.7)), col)
		"eye":
			var pts := PackedVector2Array()
			for i in 24:
				var t := TAU * i / 24.0
				pts.append(c + Vector2(cos(t) * s * 0.46, sin(t) * s * 0.26))
			draw_colored_polygon(pts, col)
			draw_circle(c, s * 0.17, Color(0.1, 0.12, 0.16))
			draw_circle(c, s * 0.08, col)
		"papelera":
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.25), Vector2(s * 0.6, s * 0.65)), col)
			draw_rect(Rect2(c + Vector2(-s * 0.38, -s * 0.36), Vector2(s * 0.76, s * 0.08)), col)
			draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.45), Vector2(s * 0.2, s * 0.08)), col)
			for k in 3:
				draw_rect(Rect2(c + Vector2(-s * 0.18 + k * s * 0.14, -s * 0.15), Vector2(s * 0.06, s * 0.45)), Color(0.1, 0.12, 0.16, 0.8))
		"iman":
			draw_arc(c + Vector2(0, -s * 0.05), s * 0.28, 0, PI, 16, col, s * 0.16)
			draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 0.4), Vector2(s * 0.16, s * 0.35)), col)
			draw_rect(Rect2(c + Vector2(s * 0.2, -s * 0.4), Vector2(s * 0.16, s * 0.35)), col)
			draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 0.45), Vector2(s * 0.16, s * 0.1)), Color(0.85, 0.85, 0.9))
			draw_rect(Rect2(c + Vector2(s * 0.2, -s * 0.45), Vector2(s * 0.16, s * 0.1)), Color(0.85, 0.85, 0.9))
		"mezclador":
			draw_arc(c, s * 0.32, 0.3, PI - 0.3, 16, col, s * 0.1)
			draw_arc(c, s * 0.32, PI + 0.3, TAU - 0.3, 16, col, s * 0.1)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.45, -s * 0.02), c + Vector2(-s * 0.2, -s * 0.02), c + Vector2(-s * 0.33, s * 0.18)]), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.45, s * 0.02), c + Vector2(s * 0.2, s * 0.02), c + Vector2(s * 0.33, -s * 0.18)]), col)
		"reloj":
			draw_circle(c, s * 0.42, col)
			draw_circle(c, s * 0.33, Color(0.1, 0.12, 0.16))
			draw_line(c, c + Vector2(0, -s * 0.24), col, 3)
			draw_line(c, c + Vector2(s * 0.17, s * 0.06), col, 3)
		"lock":
			draw_arc(c + Vector2(0, -s * 0.08), s * 0.2, PI, TAU, 12, col, s * 0.08)
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.08), Vector2(s * 0.6, s * 0.45)), col)
		"key":
			draw_circle(c + Vector2(-s * 0.2, 0), s * 0.18, col)
			draw_circle(c + Vector2(-s * 0.2, 0), s * 0.08, Color(0.1, 0.12, 0.16))
			draw_rect(Rect2(c + Vector2(-s * 0.05, -s * 0.05), Vector2(s * 0.45, s * 0.1)), col)
			draw_rect(Rect2(c + Vector2(s * 0.25, 0), Vector2(s * 0.08, s * 0.16)), col)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.3, 0), c + Vector2(-s * 0.08, s * 0.25), c + Vector2(s * 0.35, -s * 0.28)]), col, s * 0.12)
