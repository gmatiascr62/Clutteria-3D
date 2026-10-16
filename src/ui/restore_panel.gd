class_name RestorePanel
extends PanelContainer
## Panel lateral de restauración: limpieza (manual), pintura automática y
## muebles (reparar o reemplazar). Sin cronómetro.

signal paint_chosen(paint_id: String)
signal furniture_action(index: int, action: String)
signal finish_pressed
signal fixture_pressed(name: String)

var _clean_bar: ProgressBar
var _clean_label: Label
var _finish: Button
var _paint_box: GridContainer
var _furn_box: VBoxContainer
var _summary: Label
var _layout: Dictionary
var _layout_id: String
var _restore: Dictionary


var _scroll: ScrollContainer
var _fix_box: VBoxContainer
var _selected := -1
var _last_clean := 0.0


func build(layout_id: String) -> void:
	_layout_id = layout_id
	_layout = PropertyCatalog.LAYOUTS[layout_id]
	add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.14, 0.19, 0.93), 18, 12))
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -420
	offset_right = -10
	offset_top = 90
	offset_bottom = -10
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_scroll = scroll
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	scroll.add_child(vb)

	vb.add_child(UiKit.label("1. Limpiar", 24, UiKit.ACCENT))
	vb.add_child(UiKit.label("Deslizá el dedo sobre las manchas del piso y las paredes.", 17, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 370))
	_clean_bar = ProgressBar.new()
	_clean_bar.custom_minimum_size = Vector2(0, 22)
	_clean_bar.max_value = 100
	_clean_bar.show_percentage = false
	_clean_bar.add_theme_stylebox_override("background", UiKit.box(Color(0.25, 0.27, 0.32), 8, 0))
	_clean_bar.add_theme_stylebox_override("fill", UiKit.box(UiKit.GOOD, 8, 0))
	vb.add_child(_clean_bar)
	_clean_label = UiKit.label("0 %", 20)
	vb.add_child(_clean_label)

	vb.add_child(UiKit.label("2. Pintar paredes", 24, UiKit.ACCENT))
	_paint_box = GridContainer.new()
	_paint_box.columns = 2
	_paint_box.add_theme_constant_override("h_separation", 8)
	_paint_box.add_theme_constant_override("v_separation", 8)
	vb.add_child(_paint_box)

	vb.add_child(UiKit.label("3. Muebles", 24, UiKit.ACCENT))
	vb.add_child(UiKit.label("Tocá un mueble en la habitación para elegirlo.", 17, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 370))
	_furn_box = VBoxContainer.new()
	vb.add_child(_furn_box)

	if not _layout.get("fixtures", []).is_empty():
		vb.add_child(UiKit.label("4. Arreglos", 24, UiKit.ACCENT))
		vb.add_child(UiKit.label("También podés tocarlos en la habitación.", 17, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 370))
		_fix_box = VBoxContainer.new()
		vb.add_child(_fix_box)

	_summary = UiKit.label("", 18, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 370)
	vb.add_child(_summary)
	_finish = UiKit.button("Terminar restauración", func(): finish_pressed.emit(), Color(0.2, 0.55, 0.3), Vector2(0, 70))
	vb.add_child(_finish)


## Elige un mueble tocado en la habitación: queda primero y resaltado.
func select_furniture(fi: int) -> void:
	_selected = fi
	refresh(_restore, _last_clean, int(Game.profile.coins))
	await get_tree().process_frame
	if _furn_box.get_child_count() > 0:
		_scroll.ensure_control_visible(_furn_box.get_child(0))


func refresh_clean(clean: float) -> void:
	_last_clean = clean
	_clean_bar.value = clean * 100.0
	var need := int(Balance.CLEAN_REQUIRED * 100)
	_clean_label.text = "%d %%  (mínimo %d %%)" % [int(clean * 100.0), need]
	_finish.disabled = clean < Balance.CLEAN_REQUIRED
	_finish.text = "Terminar restauración" if not _finish.disabled else "Limpiá al menos %d %%" % need


func refresh(restore: Dictionary, clean: float, coins: int) -> void:
	_restore = restore
	refresh_clean(clean)
	for c in _paint_box.get_children():
		c.queue_free()
	for p in Balance.PAINT_COLORS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(185, 56)
		var chosen: bool = restore.get("paint", "") == p.id
		var col := Color.html(p.color)
		b.add_theme_stylebox_override("normal", UiKit.box(col.darkened(0.1) if not chosen else col, 12, 6))
		b.add_theme_stylebox_override("hover", UiKit.box(col, 12, 6))
		b.add_theme_stylebox_override("pressed", UiKit.box(col.darkened(0.2), 12, 6))
		b.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
		b.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.12))
		b.add_theme_font_size_override("font_size", 17)
		b.text = ("» " if chosen else "") + p.name + ("" if p.price == 0 else "  (%d)" % p.price)
		b.disabled = chosen or (p.price > coins)
		var pid: String = p.id
		b.pressed.connect(func():
			Sfx.play("click")
			paint_chosen.emit(pid))
		_paint_box.add_child(b)
	for c in _furn_box.get_children():
		c.queue_free()
	var states: Dictionary = restore.get("furniture", {})
	var order := range(_layout.furniture.size())
	if _selected >= 0:
		order.erase(_selected)
		order.push_front(_selected)
	for fi in order:
		var f: Dictionary = _layout.furniture[fi]
		var row := VBoxContainer.new()
		if fi == _selected:
			var sel := PanelContainer.new()
			sel.add_theme_stylebox_override("panel", UiKit.box(Color(0.45, 0.36, 0.12, 0.6), 10, 6))
			sel.add_child(row)
		row.add_theme_constant_override("separation", 4)
		var st: String = states.get(str(fi), "")
		var status: String = {"": "desgastado", "repaired": "reparado", "replaced": "nuevo"}[st]
		row.add_child(UiKit.label("%s — %s" % [f.name, status], 19, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 370))
		if st == "":
			var hb := HBoxContainer.new()
			var rc := Economy.repair_cost(f)
			var nc := Economy.replace_cost(f)
			var i: int = fi
			var rb := UiKit.button("Reparar %d\n(+%d valor)" % [rc, Economy.repair_value(f)], func(): furniture_action.emit(i, "repaired"), Color(0.25, 0.4, 0.55), Vector2(185, 64))
			rb.add_theme_font_size_override("font_size", 16)
			rb.disabled = rc > coins
			var nb := UiKit.button("Reemplazar %d\n(+%d valor)" % [nc, Economy.replace_value(f)], func(): furniture_action.emit(i, "replaced"), Color(0.45, 0.33, 0.55), Vector2(185, 64))
			nb.add_theme_font_size_override("font_size", 16)
			nb.disabled = nc > coins
			hb.add_child(rb)
			hb.add_child(nb)
			row.add_child(hb)
		_furn_box.add_child(row.get_parent() if fi == _selected else row)
	if _fix_box:
		for c in _fix_box.get_children():
			c.queue_free()
		var fixed: Dictionary = restore.get("fixtures", {})
		for name in _layout.fixtures:
			var fx: Dictionary = Balance.FIXTURES[name]
			if fixed.get(name, false):
				_fix_box.add_child(UiKit.label("%s — arreglado" % fx.name, 19, UiKit.GOOD, HORIZONTAL_ALIGNMENT_LEFT, 370))
			else:
				var n: String = name
				var b := UiKit.button("%s\nArreglar %d (+%d valor)" % [fx.name, int(fx.cost), int(fx.value)], func(): fixture_pressed.emit(n), Color(0.3, 0.42, 0.35), Vector2(0, 64))
				b.add_theme_font_size_override("font_size", 17)
				b.disabled = int(fx.cost) > coins
				_fix_box.add_child(b)
	_summary.text = "Invertido: %d monedas · Valor agregado: %d" % [int(restore.get("spent", 0)), Economy.room_restoration_value(_layout_id, restore)]

