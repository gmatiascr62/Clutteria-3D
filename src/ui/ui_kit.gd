class_name UiKit
extends RefCounted
## Tema visual y widgets reutilizables construidos por código.

const BG := Color(0.11, 0.13, 0.17, 0.96)
const PANEL := Color(0.16, 0.19, 0.25, 0.97)
const ACCENT := Color(0.98, 0.76, 0.22)
const GOOD := Color(0.35, 0.78, 0.45)
const BAD := Color(0.9, 0.35, 0.3)
const TEXT := Color(0.96, 0.95, 0.92)
const MUTED := Color(0.7, 0.72, 0.76)

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_stylebox("normal", "Button", _box(Color(0.24, 0.3, 0.4), 14))
	t.set_stylebox("hover", "Button", _box(Color(0.3, 0.37, 0.5), 14))
	t.set_stylebox("pressed", "Button", _box(Color(0.2, 0.25, 0.33), 14))
	t.set_stylebox("disabled", "Button", _box(Color(0.2, 0.22, 0.26, 0.7), 14))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 18))
	t.set_stylebox("panel", "Panel", _box(PANEL, 18))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	var grab := _box(ACCENT, 10)
	t.set_stylebox("slider", "HSlider", _box(Color(0.3, 0.32, 0.38), 6))
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_stylebox("panel", "TabContainer", _box(PANEL, 12))
	t.set_stylebox("tab_selected", "TabContainer", _box(Color(0.3, 0.37, 0.5), 10))
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color(0.18, 0.21, 0.27), 10))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color(0.26, 0.3, 0.4), 10))
	t.set_font_size("font_size", "TabContainer", 22)
	_theme = t
	return t


static func _box(c: Color, radius: int, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s


static func box(c: Color, radius := 14, pad := 12) -> StyleBoxFlat:
	return _box(c, radius, pad)


## wrap_width > 0 activa el ajuste de línea con ese ancho mínimo.
static func label(text: String, size := 22, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, wrap_width := 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if wrap_width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_width, 0)
	return l


static func button(text: String, cb: Callable, color := Color(0.24, 0.3, 0.4), min_size := Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_stylebox_override("normal", _box(color, 14))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.12), 14))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.15), 14))
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b


static func fullscreen(ctrl: Control) -> Control:
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return ctrl


## Diálogo modal. buttons: Array de [texto, Callable, color opcional, habilitado opcional].
## Las Callables reciben nada; el diálogo se cierra antes de llamarlas
## salvo que la entrada tenga "keep" como quinto elemento.
static func dialog(parent: Node, title: String, body: String, buttons: Array, extra: Control = null, opaque := false) -> Control:
	var root := Control.new()
	fullscreen(root)
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.08, 1.0 if opaque else 0.72)
	fullscreen(dim)
	root.add_child(dim)
	var center := CenterContainer.new()
	fullscreen(center)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	if title != "":
		vb.add_child(label(title, 32, ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	if body != "":
		var b := label(body, 22, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 520)
		vb.add_child(b)
	if extra:
		vb.add_child(extra)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	if buttons.size() > 2:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		vb.add_child(grid)
		for spec in buttons:
			grid.add_child(_dialog_button(root, spec))
	else:
		vb.add_child(row)
		for spec in buttons:
			row.add_child(_dialog_button(root, spec))
	parent.add_child(root)
	return root


static func _dialog_button(root: Control, spec: Array) -> Button:
	var color: Color = spec[2] if spec.size() > 2 and spec[2] is Color else Color(0.24, 0.3, 0.4)
	var keep: bool = spec.size() > 4 and spec[4] == "keep"
	var cb: Callable = spec[1]
	var b := button(spec[0], func():
		if not keep:
			root.queue_free()
		cb.call(), color, Vector2(250, 66))
	if spec.size() > 3 and spec[3] == false:
		b.disabled = true
	return b


static func toast(parent: Node, text: String, color := TEXT, duration := 1.6) -> void:
	var l := label(text, 26, color, HORIZONTAL_ALIGNMENT_CENTER, 500)
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := PanelContainer.new()
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", _box(Color(0.08, 0.09, 0.12, 0.88), 16))
	bg.add_child(l)
	bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bg.position = Vector2(-260, 96)
	bg.custom_minimum_size = Vector2(520, 0)
	bg.anchor_left = 0.5
	bg.anchor_right = 0.5
	parent.add_child(bg)
	var tw := bg.create_tween()
	tw.tween_interval(duration)
	tw.tween_property(bg, "modulate:a", 0.0, 0.35)
	tw.tween_callback(bg.queue_free)


static func coins_text(n: int) -> String:
	return "● %d" % n


static func hearts_text(n: int) -> String:
	return "♥ %d/%d" % [n, Balance.MAX_LIVES]
