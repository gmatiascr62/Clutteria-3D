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


func pulse(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var p: Control = _slots[index].panel
	p.pivot_offset = p.size * 0.5
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(p, "scale", Vector2.ONE, 0.12)
