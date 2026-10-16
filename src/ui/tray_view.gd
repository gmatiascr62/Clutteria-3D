class_name TrayView
extends PanelContainer
## Bandeja de 7 espacios. Cada espacio muestra el objeto real en 3D usando
## un SubViewport pequeño que sólo se vuelve a dibujar cuando cambia.

signal slot_pressed(index: int)

const SLOT := 88

var _slots: Array = [] # {panel, viewport, mesh, button}
var _select_mode := false


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.14, 0.18, 0.9), 18, 8))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	add_child(hb)
	for i in Balance.TRAY_SIZE:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(SLOT, SLOT)
		panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.85, 0.82, 0.75), 12, 2))
		hb.add_child(panel)
		var svc := SubViewportContainer.new()
		svc.stretch = true
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(svc)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.transparent_bg = true
		vp.size = Vector2i(SLOT, SLOT)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		svc.add_child(vp)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 0.34
		cam.position = Vector3(0, 0.28, 0.28)
		cam.rotation_degrees = Vector3(-42, 0, 0)
		vp.add_child(cam)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-50, 30, 0)
		vp.add_child(light)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
		vp.add_child(env)
		var mi := MeshInstance3D.new()
		mi.material_override = MeshKit.trash_material()
		vp.add_child(mi)
		var btn := Button.new()
		btn.flat = true
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var idx := i
		btn.pressed.connect(func(): slot_pressed.emit(idx))
		panel.add_child(btn)
		_slots.append({"panel": panel, "viewport": vp, "mesh": mi, "button": btn, "variant": ""})


func refresh(tray: Tray) -> void:
	for i in _slots.size():
		var s: Dictionary = _slots[i]
		var v: String = tray.slots[i].variant if i < tray.slots.size() else ""
		if v != s.variant:
			s.variant = v
			if v == "":
				s.mesh.mesh = null
			else:
				var mesh := MeshKit.trash_mesh(v)
				s.mesh.mesh = mesh
				# Centrar y escalar el objeto en el espacio.
				var aabb := mesh.get_aabb()
				var k := 0.2 / maxf(0.05, maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)))
				s.mesh.scale = Vector3(k, k, k)
				s.mesh.position = -aabb.get_center() * k
				s.mesh.rotation = Vector3.ZERO
			s.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var warn := tray.slots.size() >= Balance.TRAY_SIZE - 1
		var col := Color(0.85, 0.82, 0.75)
		if _select_mode and v != "":
			col = Color(1.0, 0.75, 0.3)
		elif warn and v != "":
			col = Color(0.95, 0.7, 0.65)
		s.panel.add_theme_stylebox_override("panel", UiKit.box(col, 12, 2))


func set_select_mode(on: bool, tray: Tray) -> void:
	_select_mode = on
	refresh(tray)


## El espacio donde cayó el objeto se agranda y brilla un instante,
## para que el ojo siga a dónde fue (no hay animación de vuelo).
func pulse(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var p: Control = _slots[index].panel
	p.pivot_offset = p.size * 0.5
	p.modulate = Color(1.6, 1.5, 1.1)
	var tw := p.create_tween().set_parallel(true)
	tw.tween_property(p, "scale", Vector2(1.22, 1.22), 0.07).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_property(p, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate", Color.WHITE, 0.3)


## Festejo de trío: destello sobre los tres espacios y estrellas que saltan.
func burst(start: int, count := 3) -> void:
	if start < 0 or _slots.is_empty():
		return
	var layer: Control = get_parent() if get_parent() is Control else self
	var first: Control = _slots[clampi(start, 0, _slots.size() - 1)].panel
	var last: Control = _slots[clampi(start + count - 1, 0, _slots.size() - 1)].panel
	var rect := Rect2(first.global_position, Vector2(last.global_position.x + last.size.x - first.global_position.x, first.size.y))
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.95, 0.6, 0.85)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.size = rect.size
	layer.add_child(flash)
	flash.global_position = rect.position
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)
	for k in count:
		for j in 2:
			var st := VectorIcon.make("star", UiKit.ACCENT if j == 0 else Color(1, 1, 1), 34.0 - j * 12.0)
			layer.add_child(st)
			var c := rect.position + Vector2(rect.size.x * (k + 0.5) / count, rect.size.y * 0.5)
			st.global_position = c - st.custom_minimum_size * 0.5
			st.pivot_offset = st.custom_minimum_size * 0.5
			var dest := st.position + Vector2(randf_range(-50, 50), randf_range(-120, -70))
			var ts := st.create_tween().set_parallel(true)
			ts.tween_property(st, "position", dest, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			ts.tween_property(st, "rotation", randf_range(-2.0, 2.0), 0.55)
			ts.tween_property(st, "scale", Vector2(1.5, 1.5), 0.55)
			ts.tween_property(st, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
			ts.chain().tween_callback(st.queue_free)


var _warn_tween: Tween

## Con la bandeja casi llena, el marco late en rojo.
func set_warning(on: bool) -> void:
	if on and _warn_tween == null:
		_warn_tween = create_tween().set_loops()
		_warn_tween.tween_property(self, "self_modulate", Color(1.0, 0.35, 0.3), 0.35)
		_warn_tween.tween_property(self, "self_modulate", Color.WHITE, 0.35)
	elif not on and _warn_tween != null:
		_warn_tween.kill()
		_warn_tween = null
		self_modulate = Color.WHITE
