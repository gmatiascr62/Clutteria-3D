class_name Hud
extends Control
## HUD horizontal de la fase de basura: cronómetro, progreso, estrellas y
## desafío, puntos de observación, pausa, herramientas y bandeja.

signal pause_pressed
signal tool_pressed(tool: String)
signal viewpoint_pressed(index: int)
signal tray_slot_pressed(index: int)
signal tutorial_skip

var tray_view: TrayView
var _time_label: Label
var _progress: ProgressBar
var _progress_label: Label
var _stars: Array = []
var _challenge_label: Label
var _coins_label: Label
var _lives_label: Label
var _tool_buttons: Dictionary = {}
var _vp_buttons: Array = []
var _tutorial_panel: PanelContainer
var _tutorial_label: Label
var _top: Control
var _left: Control
var _right: Control
var _bottom: Control
var interactive: Array[Control] = []


func build(viewpoints: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.fullscreen(self)
	theme = UiKit.theme()

	# Barra superior.
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 10
	top.add_theme_constant_override("separation", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_top = top
	var pause := Button.new()
	pause.custom_minimum_size = Vector2(64, 64)
	var pi := VectorIcon.make("pause", Color.WHITE, 30)
	pi.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause.add_child(pi)
	pause.pressed.connect(func():
		Sfx.play("click")
		pause_pressed.emit())
	top.add_child(pause)
	interactive.append(pause)

	var time_box := _chip()
	var thb := HBoxContainer.new()
	time_box.add_child(thb)
	thb.add_child(VectorIcon.make("clock", Color(0.6, 0.9, 1.0), 30))
	_time_label = UiKit.label("0:00", 30)
	_time_label.custom_minimum_size = Vector2(84, 0)
	thb.add_child(_time_label)
	top.add_child(time_box)

	var prog_box := _chip()
	var pvb := VBoxContainer.new()
	pvb.add_theme_constant_override("separation", 2)
	prog_box.add_child(pvb)
	_progress_label = UiKit.label("Basura 0/0", 18, UiKit.MUTED)
	pvb.add_child(_progress_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(190, 14)
	_progress.show_percentage = false
	_progress.add_theme_stylebox_override("background", UiKit.box(Color(0.25, 0.27, 0.32), 6, 0))
	_progress.add_theme_stylebox_override("fill", UiKit.box(UiKit.GOOD, 6, 0))
	pvb.add_child(_progress)
	top.add_child(prog_box)

	var star_box := _chip()
	var svb := VBoxContainer.new()
	svb.add_theme_constant_override("separation", 0)
	star_box.add_child(svb)
	var shb := HBoxContainer.new()
	shb.add_theme_constant_override("separation", 2)
	for i in 3:
		var st := VectorIcon.make("star", UiKit.ACCENT, 26)
		shb.add_child(st)
		_stars.append(st)
	svb.add_child(shb)
	_challenge_label = UiKit.label("", 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 230)
	svb.add_child(_challenge_label)
	top.add_child(star_box)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)

	var coin_box := _chip()
	var chb := HBoxContainer.new()
	coin_box.add_child(chb)
	chb.add_child(VectorIcon.make("coin", UiKit.ACCENT, 26))
	_coins_label = UiKit.label("0", 24)
	chb.add_child(_coins_label)
	top.add_child(coin_box)
	var life_box := _chip()
	var lhb := HBoxContainer.new()
	life_box.add_child(lhb)
	lhb.add_child(VectorIcon.make("heart", UiKit.BAD, 26))
	_lives_label = UiKit.label("5", 24)
	lhb.add_child(_lives_label)
	top.add_child(life_box)

	# Puntos de observación (izquierda).
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left.position = Vector2(12, -40 * viewpoints)
	left.anchor_top = 0.5
	left.anchor_bottom = 0.5
	left.offset_left = 12
	left.offset_top = -44 * viewpoints
	left.add_theme_constant_override("separation", 8)
	add_child(left)
	_left = left
	var eye := VectorIcon.make("eye", Color(0.6, 0.9, 1.0), 40)
	left.add_child(eye)
	for i in viewpoints:
		var b := UiKit.button(str(i + 1), func(): viewpoint_pressed.emit(i), Color(0.2, 0.45, 0.6), Vector2(72, 72))
		b.add_theme_font_size_override("font_size", 30)
		left.add_child(b)
		_vp_buttons.append(b)
		interactive.append(b)

	# Herramientas (derecha).
	var right := VBoxContainer.new()
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.anchor_top = 0.5
	right.anchor_bottom = 0.5
	right.offset_left = -112
	right.offset_right = -12
	right.offset_top = -200
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	_right = right
	for tool in ["papelera", "iman", "mezclador", "reloj"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(100, 92)
		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := VectorIcon.make(tool, Color(0.95, 0.9, 0.75), 40)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(ic)
		var l := UiKit.label("", 16, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(l)
		b.add_child(vb)
		var t: String = tool
		b.pressed.connect(func():
			Sfx.play("click")
			tool_pressed.emit(t))
		right.add_child(b)
		_tool_buttons[tool] = {"button": b, "label": l}
		interactive.append(b)

	# Bandeja (abajo).
	tray_view = TrayView.new()
	tray_view.anchor_left = 0.5
	tray_view.anchor_right = 0.5
	tray_view.anchor_top = 1.0
	tray_view.anchor_bottom = 1.0
	tray_view.offset_top = -(TrayView.SLOT + 30)
	tray_view.offset_bottom = -10
	tray_view.grow_horizontal = Control.GROW_DIRECTION_BOTH
	tray_view.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(tray_view)
	tray_view.slot_pressed.connect(func(i): tray_slot_pressed.emit(i))
	_bottom = tray_view
	interactive.append(tray_view)

	# Tutorial.
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.1, 0.25, 0.35, 0.92), 16))
	_tutorial_panel.anchor_left = 0.5
	_tutorial_panel.anchor_right = 0.5
	_tutorial_panel.offset_left = -330
	_tutorial_panel.offset_right = 330
	_tutorial_panel.offset_top = 92
	_tutorial_panel.visible = false
	var tvb := HBoxContainer.new()
	_tutorial_panel.add_child(tvb)
	_tutorial_label = UiKit.label("", 21, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 480)
	_tutorial_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tvb.add_child(_tutorial_label)
	var skip := UiKit.button("Saltar", func(): tutorial_skip.emit(), Color(0.3, 0.35, 0.45), Vector2(110, 52))
	tvb.add_child(skip)
	add_child(_tutorial_panel)
	interactive.append(_tutorial_panel)


func _chip() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(Color(0.1, 0.12, 0.16, 0.82), 14, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func update_state(session: RoomSession) -> void:
	_time_label.text = Game.format_time(session.time_left)
	var low := session.time_left < 20.0 and session.phase == "trash"
	_time_label.add_theme_color_override("font_color", UiKit.BAD if low else UiKit.TEXT)
	var total := session.total_trash()
	var done := total - session.remaining_trash()
	_progress.max_value = total
	_progress.value = done
	_progress_label.text = "Basura %d/%d" % [done, total]
	_stars[0].set_filled(true)
	_stars[1].set_filled(session.time_star())
	_stars[2].set_filled(session.challenge_met())
	_challenge_label.text = PropertyCatalog.CHALLENGE_TEXT.get(session.challenge, "")
	_coins_label.text = str(int(Game.profile.coins))
	_lives_label.text = str(Game.lives())
	for tool in _tool_buttons:
		var n := int(Game.profile.tools.get(tool, 0))
		_tool_buttons[tool].label.text = "%s\n%s" % [Balance.TOOL_NAMES[tool].split(" ")[0], ("x%d" % n) if n > 0 else "%d mon." % Balance.TOOL_PRICES[tool]]


func set_viewpoint(vi: int) -> void:
	for i in _vp_buttons.size():
		var b: Button = _vp_buttons[i]
		var c := Color(0.95, 0.7, 0.2) if i == vi else Color(0.2, 0.45, 0.6)
		b.add_theme_stylebox_override("normal", UiKit.box(c, 14))


func set_trash_mode(on: bool) -> void:
	_right.visible = on
	_bottom.visible = on
	_top.get_child(1).visible = on
	_top.get_child(2).visible = on
	_top.get_child(3).visible = on


func show_tutorial(text: String) -> void:
	_tutorial_panel.visible = text != ""
	_tutorial_label.text = text


func is_over_ui(pos: Vector2) -> bool:
	for c in interactive:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false
