extends Node3D
## Escena de juego de una habitación: cámara en primera persona desde puntos
## de observación fijos, selección asistida, bandeja, herramientas, pausa,
## derrota/continuar, resultados y restauración.

const DRAG_THRESHOLD := 14.0
const PICK_RADIUS := 44.0
const FOV_MIN := 28.0
const FOV_MAX := 75.0
const PITCH_MIN := -80.0
const PITCH_MAX := 55.0

const TRASH_TUTORIAL := [
	["look", "Arrastrá el dedo por la pantalla para mirar a tu alrededor."],
	["zoom", "Pellizcá con dos dedos (o usá la rueda del mouse) para acercar o alejar."],
	["pick", "Tocá un objeto de basura: desaparece y va a la bandeja de abajo."],
	["trio", "Juntá TRES objetos EXACTAMENTE iguales y se eliminan. Los parecidos no cuentan."],
	["container", "Los rombos amarillos marcan cajones y cajas: tocalos para abrirlos. Explorar no ocupa la bandeja."],
	["viewpoint", "Cambiá de punto de observación con los botones 1-2-3 o tocando los círculos del piso."],
	["warn", "Si llenás los 7 espacios sin trío, perdés. ¡A limpiar!"],
]
const RESTORE_TUTORIAL := [
	["scrub", "Deslizá el dedo sobre las manchas para limpiarlas."],
	["paint", "Elegí un color: las paredes se pintan solas."],
	["furniture", "Repará los muebles (barato) o reemplazalos (más caro, suma más valor)."],
	["finish", "Al terminar todas las habitaciones de la casa, se vende automáticamente."],
]

var session: RoomSession
var view: RoomView
var camera: Camera3D
var hud: Hud
var ui_layer: CanvasLayer
var restore_panel: RestorePanel
var level: Dictionary
var layout: Dictionary

var vp_index := 0
var yaw := 0.0
var pitch := -22.0
var fov := 70.0

var _touches := {}
var _pinch_dist := 0.0
var _mode := "trash" # trash | restore | results
var _dialog: Control
var _paused := false
var _select_trash := false
var _scrub_active := false
var _scrub_last := Vector2.ZERO
var _scrub_sound_t := 0.0
var _save_accum := 0.0
var _hud_accum := 0.0
var _restore := {}
var _restore_dirty := false
var _tut_steps: Array = []
var _tut_index := -1
var _tut_prefix := ""


func _ready() -> void:
	if Game.run.is_empty():
		get_tree().change_scene_to_file.call_deferred("res://scenes/map.tscn")
		return
	level = Game.run_level()
	if level.is_empty():
		push_error("No se pudo generar el nivel")
		Game.clear_run()
		get_tree().change_scene_to_file.call_deferred("res://scenes/map.tscn")
		return
	layout = PropertyCatalog.LAYOUTS[level.layout]
	session = RoomSession.new()
	session.setup(level, Game.run.mode, Game.run.challenge, Game.profile.tools)
	if not Game.run.session.is_empty():
		session.from_dict(Game.run.session)
	if Game.run.get("restore_only", false):
		for i in session.present.size():
			session.present[i] = false
		session.tray.clear()
		session.phase = "restore"

	view = RoomView.new()
	add_child(view)
	var vis_restore: Dictionary = Game.profile.restored.get(Game.run.room_key, {})
	if not Game.run.restore.is_empty():
		vis_restore = Game.run.restore
	view.build(level, vis_restore)
	for ci in session.opened.size():
		if session.opened[ci]:
			view.open_container(ci, false)
	view.place_all(session)

	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 30.0
	add_child(camera)
	var cam: Dictionary = Game.run.get("camera", {})
	if cam.is_empty():
		_face_center(0)
	else:
		vp_index = int(cam.get("vp", 0))
		yaw = float(cam.get("yaw", 0.0))
		pitch = float(cam.get("pitch", -22.0))
		fov = float(cam.get("fov", 70.0))
	_apply_camera()
	view.set_current_viewpoint(vp_index)

	ui_layer = CanvasLayer.new()
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)
	hud = Hud.new()
	ui_layer.add_child(hud)
	hud.build(layout.viewpoints.size())
	hud.set_viewpoint(vp_index)
	hud.tray_view.refresh(session.tray)
	hud.update_state(session)
	hud.pause_pressed.connect(_pause)
	hud.tool_pressed.connect(_on_tool)
	hud.viewpoint_pressed.connect(go_to_viewpoint)
	hud.tray_slot_pressed.connect(_on_tray_slot)
	hud.tutorial_skip.connect(_skip_tutorial)

	session.piece_removed.connect(_on_piece_removed)
	session.pieces_returned.connect(func(_p): view.place_all(session))
	session.layout_changed.connect(_on_layout_changed)
	session.tray_changed.connect(func(): hud.tray_view.refresh(session.tray))
	session.trio_cleared.connect(_on_trio)
	session.container_opened.connect(func(ci):
		view.open_container(ci, true)
		view.place_all(session)
		Sfx.play("drawer" if level.containers[ci].type == "drawer" else "lift")
		_tut_event("container"))
	session.special_collected.connect(_on_special)
	session.state_changed.connect(_on_state_changed)

	if session.phase == "restore":
		_enter_after_trash()
	else:
		if Game.run.get("tutorial", false) and not Game.tutorial_done("trash"):
			_start_tutorial(TRASH_TUTORIAL, "trash")
		if session.remaining_trash() == session.total_trash() and not Game.run.has("before_shot"):
			_capture_before.call_deferred()
		_on_state_changed()


# --- Cámara ----------------------------------------------------------------

func _face_center(vi: int) -> void:
	vp_index = vi
	var vp: Vector2 = layout.viewpoints[vi]
	yaw = rad_to_deg(atan2(vp.x, vp.y))
	pitch = -24.0


func _apply_camera() -> void:
	var vp: Vector2 = layout.viewpoints[vp_index]
	camera.position = Vector3(vp.x, LayoutGeometry.EYE_HEIGHT, vp.y)
	camera.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)
	camera.fov = fov


func go_to_viewpoint(vi: int) -> void:
	if vi == vp_index or _paused:
		return
	Sfx.play("click")
	_face_center(vi)
	var vp: Vector2 = layout.viewpoints[vi]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(camera, "position", Vector3(vp.x, LayoutGeometry.EYE_HEIGHT, vp.y), 0.35).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(camera, "rotation", Vector3(deg_to_rad(pitch), _closest_angle(camera.rotation.y, deg_to_rad(yaw)), 0), 0.35)
	tw.chain().tween_callback(_apply_camera)
	view.set_current_viewpoint(vi)
	hud.set_viewpoint(vi)
	_tut_event("viewpoint")
	_save_soon()


static func _closest_angle(from: float, to: float) -> float:
	return from + wrapf(to - from, -PI, PI)


func camera_state() -> Dictionary:
	return {"vp": vp_index, "yaw": yaw, "pitch": pitch, "fov": fov}


func _ui_scale() -> float:
	return get_viewport().get_visible_rect().size.y / 720.0


# --- Entrada táctil -------------------------------------------------------------

func _unhandled_input(e: InputEvent) -> void:
	if _paused or is_instance_valid(_dialog) or _mode == "results":
		_touches.clear()
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			if hud.is_over_ui(e.position) or (restore_panel and restore_panel.visible and restore_panel.get_global_rect().has_point(e.position)):
				return
			_touches[e.index] = {"start": e.position, "pos": e.position, "moved": false}
			if _touches.size() == 2:
				var ps := _touches.values()
				_pinch_dist = ps[0].pos.distance_to(ps[1].pos)
				for t in _touches.values():
					t.moved = true
				_scrub_active = false
			elif _mode == "restore" and _touches.size() == 1:
				_scrub_active = _scrub_at(e.position)
				_scrub_last = e.position
		else:
			if not _touches.has(e.index):
				return
			var t: Dictionary = _touches[e.index]
			_touches.erase(e.index)
			if not t.moved and _touches.is_empty() and not _scrub_active:
				_tap(e.position)
			if _touches.is_empty():
				_scrub_active = false
	elif e is InputEventScreenDrag:
		if not _touches.has(e.index):
			return
		var t: Dictionary = _touches[e.index]
		t.pos = e.position
		if _touches.size() >= 2:
			var ps := _touches.values()
			var d: float = ps[0].pos.distance_to(ps[1].pos)
			if _pinch_dist > 10.0 and d > 10.0:
				_zoom(_pinch_dist / d)
			_pinch_dist = d
			return
		if not t.moved and t.start.distance_to(e.position) > DRAG_THRESHOLD * _ui_scale():
			t.moved = true
		if _scrub_active:
			var steps := maxi(1, int(_scrub_last.distance_to(e.position) / (8.0 * _ui_scale())))
			for k in steps:
				_scrub_at(_scrub_last.lerp(e.position, float(k + 1) / steps))
			_scrub_last = e.position
		elif t.moved:
			_rotate(e.relative)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.92)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.08)


func _rotate(rel: Vector2) -> void:
	var sens: float = float(Game.setting("sensitivity")) * 0.16 * (fov / 70.0) / _ui_scale()
	yaw = wrapf(yaw - rel.x * sens, -180.0, 180.0)
	pitch = clampf(pitch - rel.y * sens, PITCH_MIN, PITCH_MAX)
	_apply_camera()
	_tut_event("look")
	_save_soon()


func _zoom(factor: float) -> void:
	fov = clampf(fov * factor, FOV_MIN, FOV_MAX)
	_apply_camera()
	_tut_event("zoom")


# --- Selección asistida ---------------------------------------------------------

func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return get_world_3d().direct_space_state.intersect_ray(q)


func _candidates() -> Array:
	var out := []
	for i in view.piece_nodes.size():
		var pn: Dictionary = view.piece_nodes[i]
		if pn.body.collision_layer != 0:
			out.append([pn.body, view.piece_targets(i)])
	for dn in view.drawer_nodes:
		if dn.body.collision_layer != 0:
			out.append([dn.body, [dn.body.global_position + Vector3(0, 0, 0)]])
	for cn in view.cover_nodes:
		if cn.body.collision_layer & RoomView.LAYER_INTERACT:
			out.append([cn.body, [cn.node.global_position + Vector3(0, cn.def.size.y * 0.7, 0)]])
	for m in view.marker_nodes:
		if m.visible:
			for ch in m.get_children():
				if ch is StaticBody3D:
					out.append([ch, [m.global_position]])
	return out


## Devuelve el cuerpo interactivo visible más próximo al punto tocado.
func pick_at(screen: Vector2) -> Object:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var mask := RoomView.LAYER_WORLD | RoomView.LAYER_INTERACT
	var hit := _ray(from, from + dir * 15.0, mask)
	if not hit.is_empty() and hit.collider.has_meta("kind"):
		return hit.collider
	var best: Object = null
	var best_d := PICK_RADIUS * _ui_scale()
	for c in _candidates():
		var body: Object = c[0]
		for target in c[1]:
			if camera.is_position_behind(target):
				continue
			var d := camera.unproject_position(target).distance_to(screen)
			if d >= best_d:
				continue
			var los := _ray(from, target + (target - from).normalized() * 0.06, mask)
			if not los.is_empty() and los.collider == body:
				best = body
				best_d = d
	return best


func _tap(pos: Vector2) -> void:
	var body := pick_at(pos)
	if body == null:
		return
	var kind: String = body.get_meta("kind")
	match kind:
		"viewpoint":
			go_to_viewpoint(int(body.get_meta("viewpoint")))
		"piece":
			if _mode == "trash":
				_on_piece_tapped(int(body.get_meta("piece")))
		"drawer", "cover":
			if _mode == "trash" and int(body.get_meta("container")) >= 0:
				session.open_container(int(body.get_meta("container")))
				_save_soon()


func _on_piece_tapped(pid: int) -> void:
	if _select_trash:
		return
	var r := session.take(pid)
	if r.ok:
		if r.get("special", "") == "":
			Sfx.play("pick", randf_range(0.92, 1.08))
			_tut_event("pick")
		_save_soon()
	elif r.reason == "covered":
		view.shake(pid)
		Sfx.play("deny")
		UiKit.toast(ui_layer, "Está tapado: sacá primero lo de arriba", UiKit.MUTED, 1.0)


# --- Reacciones a la sesión -----------------------------------------------------

func _on_piece_removed(pid: int) -> void:
	var pn: Dictionary = view.piece_nodes[pid]
	if pn.node.visible:
		view.poof(pn.node.global_position + Vector3(0, pn.size.y * 0.5, 0))
	view.place_all(session)
	_refresh_hud()


func _on_trio(_variant: String) -> void:
	Sfx.play("trio")
	_tut_event("trio")
	_refresh_hud()


func _on_layout_changed(pids: Array) -> void:
	for pid in pids:
		var node: Node3D = view.piece_nodes[pid].node
		var from := node.global_position
		view.place_piece(pid, session)
		var to := node.position
		node.global_position = from
		var tw := node.create_tween()
		tw.tween_property(node, "position", to + Vector3(0, 0.25, 0), 0.18)
		tw.tween_property(node, "position", to, 0.18)


func _on_special(pid: int, piece: Dictionary) -> void:
	var pn: Dictionary = view.piece_nodes[pid]
	view.poof(pn.node.global_position + Vector3(0, 0.1, 0), Color(0.9, 0.6, 1.0))
	if piece.kind == "mystery":
		Sfx.play("mystery")
		var text := Game.apply_prize(piece.prize)
		UiKit.toast(ui_layer, "Caja misteriosa: " + text, UiKit.ACCENT, 2.2)
	elif piece.kind == "key":
		Sfx.play("coin")
		Game.on_key_found()
		UiKit.toast(ui_layer, "¡Encontraste una llave! Abre una habitación secreta.", UiKit.ACCENT, 2.4)
	_save_soon()
	_refresh_hud()


func _on_state_changed() -> void:
	_refresh_hud()
	if _mode != "trash":
		return
	if session.phase == "restore":
		_enter_after_trash()
		return
	if session.blocked == "tray_full" and not is_instance_valid(_dialog) and not _select_trash:
		_show_tray_full()
	elif session.blocked == "lost" and not is_instance_valid(_dialog):
		_show_defeat()


func _refresh_hud() -> void:
	if hud:
		hud.update_state(session)


# --- Bandeja llena y derrota ------------------------------------------------------

func _show_tray_full() -> void:
	Sfx.play("fail")
	var trash := int(Game.profile.tools.get("papelera", 0))
	var magnet := int(Game.profile.tools.get("iman", 0))
	if trash <= 0 and magnet <= 0:
		session.declare_loss("tray")
		return
	_dialog = UiKit.dialog(ui_layer, "Bandeja llena", "No queda espacio y no hay trío. Usá una herramienta para liberar lugar.", [
		["Papelera (x%d)" % trash, func(): _use_tool("papelera"), Color(0.25, 0.45, 0.6), trash > 0],
		["Imán (x%d)" % magnet, func(): _use_tool("iman"), Color(0.25, 0.45, 0.6), magnet > 0],
		["Rendirse", func(): session.declare_loss("tray"), UiKit.BAD],
	])


func _show_defeat() -> void:
	Sfx.play("fail")
	var already := session.loss_life_taken
	var lost := Game.record_loss(session)
	if lost:
		Game.run["loss_cost_life"] = true
	var body := ""
	if Game.run.get("loss_cost_life", false):
		body = "Perdiste una vida (te quedan %d)." % Game.lives()
	elif already:
		body = ""
	else:
		body = "Esta partida no arriesga vidas."
	body += "\nPodés reiniciar gratis o continuar desde donde estabas."
	var title := "¡Se acabó el tiempo!" if session.loss_reason == "time" else "Bandeja bloqueada"
	var extra := "+%d s" % int(Balance.CONTINUE_TIME_TIMEOUT if session.loss_reason == "time" else Balance.CONTINUE_TIME_TRAYFULL)
	if session.loss_reason == "tray":
		extra += ", devuelve %d objetos" % Balance.CONTINUE_RETURN_ITEMS
	var can_pay := int(Game.profile.coins) >= Balance.CONTINUE_COST
	_dialog = UiKit.dialog(ui_layer, title, body, [
		["Reiniciar gratis", _restart, Color(0.25, 0.45, 0.6)],
		["Continuar (%d mon.)\n%s" % [Balance.CONTINUE_COST, extra], _continue_paid, UiKit.GOOD.darkened(0.3), can_pay],
		["Salir al mapa", func():
			Game.clear_run()
			_go_map(), Color(0.35, 0.3, 0.3)],
	])
	Game.save_session(session, camera_state())


func _continue_paid() -> void:
	if not Game.spend(Balance.CONTINUE_COST):
		return
	session.continue_after_loss()
	Game.run.erase("loss_cost_life")
	view.place_all(session)
	Sfx.play("tool")
	Game.save_session(session, camera_state())


func _restart() -> void:
	get_tree().paused = false
	Game.run.session = {}
	Game.run.camera = {}
	Game.run.erase("result")
	Game.run.erase("loss_cost_life")
	Game.mark_dirty(true)
	get_tree().reload_current_scene()


func _go_map() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/map.tscn")


# --- Herramientas --------------------------------------------------------------------

func _on_tool(tool: String) -> void:
	if _mode != "trash" or session.blocked == "lost":
		return
	if int(Game.profile.tools.get(tool, 0)) <= 0:
		var price: int = Balance.TOOL_PRICES[tool]
		_dialog = UiKit.dialog(ui_layer, Balance.TOOL_NAMES[tool], "No te quedan. ¿Comprar una por %d monedas?" % price, [
			["Comprar y usar", func():
				if Game.buy_tool(tool):
					_use_tool(tool)
				else:
					UiKit.toast(ui_layer, "No alcanzan las monedas", UiKit.BAD), UiKit.GOOD.darkened(0.3), int(Game.profile.coins) >= price],
			["Cancelar", func(): _on_state_changed()],
		])
		return
	_use_tool(tool)


func _use_tool(tool: String) -> void:
	match tool:
		"papelera":
			if session.tray.slots.is_empty():
				UiKit.toast(ui_layer, "La bandeja está vacía")
				return
			_select_trash = true
			hud.tray_view.set_select_mode(true, session.tray)
			UiKit.toast(ui_layer, "Tocá un objeto de la bandeja para descartar su trío", UiKit.ACCENT, 2.0)
		"mezclador":
			var r := session.use_tool("mezclador", randi())
			_tool_feedback(r, "Objetos mezclados")
		"iman":
			var r := session.use_tool("iman")
			_tool_feedback(r, "¡El imán completó un trío!")
		"reloj":
			var r := session.use_tool("reloj")
			_tool_feedback(r, "+%d segundos" % int(Balance.CLOCK_BONUS))


func _tool_feedback(r: Dictionary, ok_text: String) -> void:
	if r.get("ok", false):
		Sfx.play("tool")
		UiKit.toast(ui_layer, ok_text, UiKit.GOOD, 1.2)
		view.place_all(session)
	else:
		var why := {"nothing": "No hay nada para hacer", "unsafe": "No se encontró una mezcla segura", "blocked": "No disponible ahora"}
		UiKit.toast(ui_layer, why.get(r.get("reason", ""), "No se pudo usar"), UiKit.BAD, 1.2)
	_refresh_hud()
	Game.save_session(session, camera_state())
	_on_state_changed()


func _on_tray_slot(i: int) -> void:
	if not _select_trash:
		return
	if i >= session.tray.slots.size():
		return
	_select_trash = false
	hud.tray_view.set_select_mode(false, session.tray)
	var r := session.use_tool("papelera", i)
	_tool_feedback(r, "Trío descartado")


# --- Proceso -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if session == null:
		return
	if _mode == "trash" and not is_instance_valid(_dialog) and not _paused:
		session.tick(delta)
	_hud_accum += delta
	if _hud_accum > 0.1:
		_hud_accum = 0.0
		_refresh_hud()
	_save_accum += delta
	if _save_accum > 3.0:
		_save_accum = 0.0
		if _mode == "trash":
			Game.save_session(session, camera_state())
		elif _mode == "restore" and _restore_dirty:
			_restore_dirty = false
			_restore.masks = view.masks_data()
			Game.run.restore = _restore
			Game.mark_dirty()
	_scrub_sound_t -= delta


func _save_soon() -> void:
	_save_accum = maxf(_save_accum, 2.0)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if session and _mode == "trash" and session.is_running() and not _paused:
				_pause()
			if session:
				Game.save_session(session, camera_state())
				Game.save_now()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if _paused:
				_resume()
			elif not is_instance_valid(_dialog):
				_pause()


# --- Pausa -------------------------------------------------------------------------------

func _pause() -> void:
	if _paused or _mode == "results":
		return
	_paused = true
	get_tree().paused = true
	view.visible = false
	hud.visible = false
	if restore_panel:
		restore_panel.visible = false
	Game.save_session(session, camera_state())
	Game.save_now()
	_show_pause_menu()


func _show_pause_menu() -> void:
	var info := UiKit.label("%s · Semilla %d" % [layout.name, int(Game.run.seed)], 18, UiKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_dialog = UiKit.dialog(ui_layer, "Pausa", "La habitación queda oculta y el tiempo detenido.", [
		["Continuar", _resume, UiKit.GOOD.darkened(0.3)],
		["Opciones", func(): _show_options(), Color(0.25, 0.45, 0.6)],
		["Reiniciar habitación", func(): _confirm_restart(), Color(0.45, 0.35, 0.25)],
		["Salir al mapa", func():
			Game.save_session(session, camera_state())
			_go_map(), Color(0.35, 0.3, 0.3)],
	], info, true)


func _confirm_restart() -> void:
	_dialog = UiKit.dialog(ui_layer, "¿Reiniciar?", "Se pierde el progreso de esta habitación (no cuesta vidas).", [
		["Reiniciar", _restart, UiKit.BAD],
		["Volver", func(): _show_pause_menu()],
	], null, true)


func _show_options() -> void:
	_dialog = UiKit.dialog(ui_layer, "Opciones", "", [["Volver", func(): _show_pause_menu()]], OptionsPanel.make(), true)


func _resume() -> void:
	_paused = false
	get_tree().paused = false
	view.visible = true
	hud.visible = true
	if restore_panel:
		restore_panel.visible = true
	_on_state_changed()


# --- Fin de la fase de basura --------------------------------------------------------

func _enter_after_trash() -> void:
	if _mode != "trash":
		return
	_mode = "results"
	_select_trash = false
	_end_tutorial()
	hud.set_trash_mode(false)
	if Game.run.get("restore_only", false):
		_start_restoration()
		return
	var result: Dictionary = Game.run.get("result", {})
	if result.is_empty():
		result = Game.finish_trash(session)
		Sfx.play("win")
	_show_results(result)


func _show_results(result: Dictionary) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		stars.add_child(VectorIcon.make("star", UiKit.ACCENT, 64, i < int(result.stars)))
	box.add_child(stars)
	var lines := []
	lines.append("Tiempo restante: %s  %s" % [Game.format_time(result.time_left), "(estrella)" if result.time_star else ""])
	lines.append("Desafío: %s — %s" % [PropertyCatalog.CHALLENGE_TEXT.get(session.challenge, ""), "cumplido" if result.challenge else "no cumplido"])
	lines.append("Recompensa: +%d monedas" % int(result.coins))
	for e in result.get("extra", []):
		lines.append(e)
	for l in lines:
		box.add_child(UiKit.label(l, 21, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var buttons := []
	if Game.needs_restoration():
		buttons.append(["Restaurar habitación", _start_restoration, UiKit.GOOD.darkened(0.3)])
	else:
		buttons.append(["Continuar", func():
			Game.clear_run()
			_go_map(), UiKit.GOOD.darkened(0.3)])
	_dialog = UiKit.dialog(ui_layer, "¡Habitación limpia!", "", buttons, box)


# --- Restauración -----------------------------------------------------------------------

func _start_restoration() -> void:
	_mode = "restore"
	hud.set_trash_mode(false)
	view.set_stains_interactive(true)
	_restore = Game.run.restore.duplicate(true)
	if _restore.is_empty():
		_restore = {"furniture": {}, "spent": 0, "clean": 0.0, "treasure_value": int(session.stats.get("treasure_value", 0))}
	_restore.clean = view.clean_fraction()
	view.set_dirt_visual(_restore.clean)
	Game.run.restore = _restore
	Game.mark_dirty(true)
	restore_panel = RestorePanel.new()
	ui_layer.add_child(restore_panel)
	restore_panel.build(level.layout)
	restore_panel.paint_chosen.connect(_on_paint)
	restore_panel.furniture_action.connect(_on_furniture)
	restore_panel.finish_pressed.connect(_finish_restoration)
	restore_panel.refresh(_restore, _restore.clean, int(Game.profile.coins))
	hud.interactive.append(restore_panel)
	if Game.run.get("tutorial", false) and not Game.tutorial_done("restore"):
		_start_tutorial(RESTORE_TUTORIAL, "restore")


func _scrub_at(pos: Vector2) -> bool:
	var from := camera.project_ray_origin(pos)
	var dir := camera.project_ray_normal(pos)
	var hit := _ray(from, from + dir * 15.0, RoomView.LAYER_WORLD | RoomView.LAYER_STAIN)
	if hit.is_empty() or not hit.collider.has_meta("kind") or hit.collider.get_meta("kind") != "stain":
		return false
	var si := int(hit.collider.get_meta("stain"))
	var sn: Dictionary = view.stain_nodes[si]
	var local: Vector3 = sn.node.to_local(hit.position)
	var size: Vector2 = sn.def.size
	var uv := Vector2(local.x / size.x + 0.5, local.z / size.y + 0.5)
	if view.scrub(si, uv):
		if _scrub_sound_t <= 0.0:
			Sfx.play("scrub", randf_range(0.9, 1.15))
			_scrub_sound_t = 0.12
		_restore.clean = view.clean_fraction()
		view.set_dirt_visual(_restore.clean)
		restore_panel.refresh_clean(_restore.clean)
		_restore_dirty = true
		if _restore.clean >= Balance.CLEAN_REQUIRED:
			_tut_event("scrub")
	return true


func _on_paint(id: String) -> void:
	var p := Balance.paint_by_id(id)
	var prev: String = _restore.get("paint", "")
	if prev == id:
		return
	if int(p.price) > 0 and not Game.spend(int(p.price)):
		UiKit.toast(ui_layer, "No alcanzan las monedas", UiKit.BAD)
		return
	_restore.paint = id
	_restore.spent = int(_restore.get("spent", 0)) + int(p.price)
	view.animate_paint(Color.html(p.color))
	Sfx.play("paint")
	_tut_event("paint")
	_after_restore_change()


func _on_furniture(i: int, action: String) -> void:
	var f: Dictionary = layout.furniture[i]
	var cost := Economy.repair_cost(f) if action == "repaired" else Economy.replace_cost(f)
	if not Game.spend(cost):
		UiKit.toast(ui_layer, "No alcanzan las monedas", UiKit.BAD)
		return
	_restore.furniture[str(i)] = action
	_restore.spent = int(_restore.get("spent", 0)) + cost
	view.set_furniture_state(i, action, true)
	Sfx.play("tool")
	_tut_event("furniture")
	_after_restore_change()


func _after_restore_change() -> void:
	_restore.masks = view.masks_data()
	Game.run.restore = _restore
	Game.mark_dirty(true)
	restore_panel.refresh(_restore, _restore.clean, int(Game.profile.coins))
	_refresh_hud()


func _finish_restoration() -> void:
	if _restore.clean < Balance.CLEAN_REQUIRED:
		return
	_tut_event("finish")
	_end_tutorial()
	_mode = "results"
	restore_panel.visible = false
	var after := await _capture_view()
	var final := _restore.duplicate(true)
	final.erase("masks")
	var value := Economy.room_restoration_value(level.layout, final)
	var sale := Game.finish_restoration(final)
	Sfx.play("win")
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_shot_box("Antes", _load_before()))
	box.add_child(_shot_box("Después", after))
	var vb := VBoxContainer.new()
	vb.add_child(box)
	vb.add_child(UiKit.label("Costo de restauración: %d monedas\nValor agregado a la propiedad: %d" % [int(final.get("spent", 0)), value], 21, UiKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	_dialog = UiKit.dialog(ui_layer, "¡Restauración completa!", "", [["Continuar", func(): _after_restoration_dialog(sale), UiKit.GOOD.darkened(0.3)]], vb)


func _after_restoration_dialog(sale: Dictionary) -> void:
	if sale.is_empty():
		Game.clear_run()
		_go_map()
		return
	Sfx.play("coin")
	var text := "Compra: %d\nInversión en restauración: %d\nInversión total: %d\n\nPrecio de venta: %d\n(base %d + mejoras %d)\n\nGanancia neta: %d monedas" % [
		sale.purchase, sale.spent, sale.invest, sale.sale, sale.base, sale.added, sale.profit]
	_dialog = UiKit.dialog(ui_layer, "¡%s vendida!" % sale.name, text, [["Ir al mapa", func():
		Game.clear_run()
		_go_map(), UiKit.GOOD.darkened(0.3)]])


func _shot_box(title: String, tex: Texture2D) -> Control:
	var vb := VBoxContainer.new()
	vb.add_child(UiKit.label(title, 20, UiKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(320, 180)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture = tex
	if tex == null:
		var ph := ColorRect.new()
		ph.color = Color(0.2, 0.2, 0.25)
		ph.custom_minimum_size = Vector2(320, 180)
		vb.add_child(ph)
	else:
		vb.add_child(tr)
	return vb


func _shot_path() -> String:
	return "user://before_%s.png" % String(Game.run.room_key).replace("/", "_")


func _capture_before() -> void:
	var tex := await _capture_view()
	if tex:
		tex.get_image().save_png(_shot_path())
		Game.run["before_shot"] = true
		Game.mark_dirty()


func _load_before() -> Texture2D:
	if FileAccess.file_exists(_shot_path()):
		var img := Image.load_from_file(ProjectSettings.globalize_path(_shot_path()))
		if img:
			return ImageTexture.create_from_image(img)
	return null


## Captura la vista desde el punto 1 sin la interfaz.
func _capture_view() -> Texture2D:
	var saved := camera_state()
	_face_center(0)
	fov = 70.0
	_apply_camera()
	for m in view.marker_nodes:
		m.visible = false
	ui_layer.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	ui_layer.visible = true
	vp_index = saved.vp
	yaw = saved.yaw
	pitch = saved.pitch
	fov = saved.fov
	_apply_camera()
	view.set_current_viewpoint(vp_index)
	if img == null or img.is_empty():
		return null
	img.resize(480, int(480.0 * img.get_height() / maxf(1.0, img.get_width())), Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)


# --- Tutorial -------------------------------------------------------------------------------

func _start_tutorial(steps: Array, prefix: String) -> void:
	_tut_steps = steps
	_tut_prefix = prefix
	_tut_index = -1
	_tut_advance()


func _tut_advance() -> void:
	_tut_index += 1
	while _tut_index < _tut_steps.size() and Game.tutorial_done("%s_%s" % [_tut_prefix, _tut_steps[_tut_index][0]]):
		_tut_index += 1
	if _tut_index >= _tut_steps.size():
		Game.set_tutorial_done(_tut_prefix)
		hud.show_tutorial("")
		return
	hud.show_tutorial(_tut_steps[_tut_index][1])
	if _tut_steps[_tut_index][0] == "warn":
		get_tree().create_timer(5.0).timeout.connect(func(): _tut_event("warn"))


func _tut_event(id: String) -> void:
	if _tut_steps.is_empty():
		return
	Game.set_tutorial_done("%s_%s" % [_tut_prefix, id])
	if _tut_index >= 0 and _tut_index < _tut_steps.size() and _tut_steps[_tut_index][0] == id:
		_tut_advance()


func _skip_tutorial() -> void:
	Game.set_tutorial_done(_tut_prefix)
	for s in _tut_steps:
		Game.set_tutorial_done("%s_%s" % [_tut_prefix, s[0]])
	_end_tutorial()


func _end_tutorial() -> void:
	_tut_steps = []
	_tut_index = -1
	if hud:
		hud.show_tutorial("")
