extends "res://tests/test_base.gd"
## Integración con la escena 3D real: para cada objeto, en el orden de la
## solución, comprueba que desde algún punto de observación un toque en el
## centro de la pantalla (apuntando al objeto) lo selecciona con raycast y
## línea de visión. También recorre la restauración y el guardado.

const CASES := [
	["studio", 30, 0.0, 11],
	["bathroom", 30, 0.05, 5],
	["kitchen", 90, 0.35, 3],
	["bedroom", 150, 0.55, 8],
	["living", 240, 0.8, 2],
	["attic", 120, 0.55, 4],
]


func _frames(n: int) -> void:
	for i in n:
		await runner.physics_frame


func _open_scene(layout: String, items: int, diff: float, seed_value: int) -> Node:
	var game = runner.root.get_node("Game")
	game.run = {"room_key": "contract", "mode": "contract", "layout": layout, "items": items,
		"difficulty": diff, "seed": seed_value, "challenge": "find_mystery", "key_for": -1,
		"contract": {"id": "test", "reward": 10, "daily": false, "layout": layout, "items": items},
		"session": {}, "camera": {}, "restore": {}, "before_shot": true}
	var scene: Node = load("res://scenes/room.tscn").instantiate()
	runner.root.add_child(scene)
	await _frames(3)
	return scene


func test_every_item_pickable_in_solution_order() -> void:
	for c in CASES:
		var scene := await _open_scene(c[0], c[1], c[2], c[3])
		var s: RoomSession = scene.session
		for ci in s.level.containers.size():
			s.open_container(ci)
		# Esperar a que terminen las animaciones de cajones y tapas.
		await runner.create_timer(0.8).timeout
		await _frames(2)
		var steps: Array = Solver.solve(s.level, s.solver_state()).steps
		var fails := []
		for pid in steps:
			if not await _pickable(scene, pid):
				fails.append(pid)
				var sl: Dictionary = s.level.slots[s.piece_slot[pid]]
				print("      no tocable %d: %s cont=%d pos=%s" % [pid, sl.kind, sl.container, str(scene.view.piece_nodes[pid].node.global_position)])
			s.take(pid)
		# Especiales.
		for p in s.level.pieces:
			if p.kind != "trash" and s.present[p.id] and s.is_accessible(p.id):
				if not await _pickable(scene, p.id):
					fails.append(p.id)
		check(fails.is_empty(), "%s/%d: %d de %d objetos no se pudieron tocar: %s" % [c[0], c[1], fails.size(), steps.size(), str(fails.slice(0, 8))])
		scene.queue_free()
		await _frames(1)


func _pickable(scene: Node, pid: int) -> bool:
	var cam: Camera3D = scene.camera
	var view: RoomView = scene.view
	var layout: Dictionary = scene.layout
	var center := scene.get_viewport().get_visible_rect().size * 0.5
	for vi in layout.viewpoints.size():
		var vp: Vector2 = layout.viewpoints[vi]
		var eye := Vector3(vp.x, LayoutGeometry.EYE_HEIGHT, vp.y)
		for target in view.piece_targets(pid):
			if eye.distance_to(target) < 0.3:
				continue
			cam.global_position = eye
			cam.look_at(target, Vector3.UP)
			var body: Object = scene.pick_at(center)
			if body != null and body.get_meta("kind", "") == "piece" and int(body.get_meta("piece")) == pid:
				return true
	return false


func test_covered_item_not_taken_through_tap() -> void:
	var scene := await _open_scene("kitchen", 60, 0.3, 21)
	var s: RoomSession = scene.session
	var covered := -1
	for p in s.level.pieces:
		if p.kind == "trash" and not s.is_hidden(p.id) and not s.is_accessible(p.id):
			covered = p.id
			break
	check(covered >= 0, "hay un objeto tapado")
	var before := s.remaining_trash()
	scene._on_piece_tapped(covered)
	eq(s.remaining_trash(), before, "tocar un objeto tapado no lo toma")
	eq(s.tray.slots.size(), 0, "ni ocupa la bandeja")
	scene.queue_free()
	await _frames(1)


func test_restoration_scrub_paint_and_furniture() -> void:
	var game = runner.root.get_node("Game")
	game.reset_progress()
	var scene := await _open_scene("studio", 30, 0.0, 3)
	var s: RoomSession = scene.session
	for ci in s.level.containers.size():
		s.open_container(ci)
	for pid in Solver.solve(s.level, s.solver_state()).steps:
		s.take(pid)
	await _frames(1)
	eq(s.phase, "restore", "terminó la basura")
	scene._start_restoration()
	var view: RoomView = scene.view
	# Frotar todas las manchas por completo (UV de toda la grilla, varias pasadas).
	for pass_i in 3:
		for si in view.stain_nodes.size():
			for y in 12:
				for x in 12:
					view.scrub(si, Vector2((x + 0.5) / 12.0, (y + 0.5) / 12.0))
	check(view.clean_fraction() >= Balance.CLEAN_REQUIRED, "se puede limpiar por completo (%.2f)" % view.clean_fraction())
	# Frotar a través de la cámara (raycast real) también limpia.
	var coins_before := int(game.profile.coins)
	scene._on_paint("crema")
	eq(scene._restore.paint, "crema", "pintura elegida")
	eq(int(game.profile.coins), coins_before, "colores básicos gratis")
	scene._on_furniture(0, "repaired")
	eq(scene._restore.furniture["0"], "repaired", "mueble reparado")
	check(int(game.profile.coins) < coins_before, "reparar cuesta monedas")
	scene.queue_free()
	await _frames(1)


func test_scrub_via_camera_ray() -> void:
	var scene := await _open_scene("living", 30, 0.0, 9)
	var s: RoomSession = scene.session
	for i in s.present.size():
		s.present[i] = false
	scene.view.place_all(s)
	scene._mode = "trash"
	scene._start_restoration()
	await _frames(2)
	var view: RoomView = scene.view
	var sn: Dictionary = view.stain_nodes[0]
	var cam: Camera3D = scene.camera
	var vp: Vector2 = scene.layout.viewpoints[0]
	cam.global_position = Vector3(vp.x, LayoutGeometry.EYE_HEIGHT, vp.y)
	cam.look_at(sn.node.global_position, Vector3.UP)
	var before: int = sn.dirty
	var center := scene.get_viewport().get_visible_rect().size * 0.5
	check(scene._scrub_at(center), "el rayo encuentra la mancha")
	check(sn.dirty <= before, "la máscara se actualiza")
	scene.queue_free()
	await _frames(1)


func test_save_and_resume_scene_state() -> void:
	var scene := await _open_scene("bedroom", 60, 0.2, 13)
	var s: RoomSession = scene.session
	s.open_container(0)
	var steps: Array = Solver.solve(s.level, s.solver_state()).steps
	for k in 5:
		s.take(steps[k])
	scene.go_to_viewpoint(2)
	scene.yaw = 33.0
	var game = runner.root.get_node("Game")
	game.save_session(s, scene.camera_state())
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.run.session))
	var cam: Dictionary = game.run.camera.duplicate()
	scene.queue_free()
	await _frames(1)
	game.run.session = saved
	var scene2: Node = load("res://scenes/room.tscn").instantiate()
	runner.root.add_child(scene2)
	await _frames(2)
	var s2: RoomSession = scene2.session
	eq(s2.present, s.present, "mismas piezas al reanudar")
	eq(s2.opened, s.opened, "mismos cajones abiertos")
	eq(scene2.vp_index, int(cam.vp), "mismo punto de observación")
	check(absf(scene2.yaw - 33.0) < 0.01, "misma orientación de cámara")
	check(absf(s2.time_left - s.time_left) < 0.5, "mismo tiempo")
	scene2.queue_free()
	await _frames(1)


func test_pause_hides_room_and_freezes_timer() -> void:
	var scene := await _open_scene("studio", 30, 0.0, 5)
	var s: RoomSession = scene.session
	await runner.create_timer(0.3).timeout
	scene._pause()
	var t := s.time_left
	check(not scene.view.visible, "la habitación queda oculta en pausa")
	check(runner.paused, "el árbol queda en pausa")
	await runner.create_timer(0.5, true).timeout
	eq(s.time_left, t, "el cronómetro no avanza en pausa")
	scene._resume()
	check(scene.view.visible, "vuelve a mostrarse")
	await runner.create_timer(0.3).timeout
	check(s.time_left < t, "el cronómetro sigue al reanudar")
	scene.queue_free()
	await _frames(1)


func test_tray_full_then_defeat_costs_one_life_once() -> void:
	var game = runner.root.get_node("Game")
	game.reset_progress()
	game.profile.tools = {"papelera": 0, "iman": 0, "mezclador": 0, "reloj": 0}
	var scene := await _open_scene("living", 90, 0.3, 3)
	game.run.mode = "story"
	game.run.room_key = "depto_sol/2"
	var s: RoomSession = scene.session
	s.mode = "story"
	for c in s.level.containers.size():
		s.open_container(c)
	var lives_before: int = game.lives()
	var guard := 0
	while s.blocked == "" and guard < 300:
		guard += 1
		var counts := s.tray.variants_count()
		var pick := -1
		for p in s.level.pieces:
			if p.kind == "trash" and s.present[p.id] and s.is_accessible(p.id) and counts.get(p.variant, 0) < 2:
				pick = p.id
				break
		if pick < 0:
			break
		scene._on_piece_tapped(pick)
	eq(s.blocked, "lost", "sin herramientas, bandeja llena => derrota")
	eq(game.lives(), lives_before - 1, "se descuenta una vida")
	scene._show_defeat()
	eq(game.lives(), lives_before - 1, "mostrar de nuevo la derrota no descuenta otra vida")
	game.profile.coins = 500
	scene._continue_paid()
	eq(s.blocked, "", "continuar con monedas destraba")
	eq(s.tray.slots.size(), Balance.TRAY_SIZE - Balance.CONTINUE_RETURN_ITEMS, "devuelve 3 objetos a la habitación")
	eq(game.lives(), lives_before - 1, "continuar no descuenta vidas")
	for c in scene.ui_layer.get_children():
		if c is Control and c.process_mode == Node.PROCESS_MODE_ALWAYS:
			c.queue_free()
	scene.queue_free()
	await _frames(1)


func test_tap_open_drawer_front_closes_it() -> void:
	var scene := await _open_scene("kitchen", 60, 0.2, 31)
	var s: RoomSession = scene.session
	var ci := -1
	for i in s.level.containers.size():
		if s.level.containers[i].type == "drawer":
			ci = i
			break
	if not check(ci >= 0, "hay un cajón"):
		return
	var view: RoomView = scene.view
	var dn: Dictionary = view.drawer_nodes[s.level.containers[ci].ref]
	var cam: Camera3D = scene.camera
	var center := scene.get_viewport().get_visible_rect().size * 0.5
	var aim := func():
		var vp: Vector2 = scene.layout.viewpoints[dn.def.vps[0]]
		cam.global_position = Vector3(vp.x, LayoutGeometry.EYE_HEIGHT, vp.y)
		cam.look_at(dn.body.global_position + dn.def.normal * 0.02, Vector3.UP)
	aim.call()
	scene._tap(center)
	check(s.opened[ci], "tocar el cajón lo abre")
	await runner.create_timer(0.5).timeout
	aim.call()
	scene._tap(center)
	check(not s.opened[ci], "tocar el frente del cajón abierto lo cierra")
	await runner.create_timer(0.5).timeout
	check(dn.node.position.is_equal_approx(dn.closed_pos), "vuelve a su lugar")
	for sid in s.level.slots.size():
		var pid: int = s.slot_piece[sid]
		if s.level.slots[sid].container == ci and pid >= 0:
			check(not view.piece_nodes[pid].node.visible, "el contenido queda oculto")
	scene.queue_free()
	await _frames(1)


func test_covered_tap_highlights_piece_on_top() -> void:
	var scene := await _open_scene("living", 90, 0.3, 17)
	var s: RoomSession = scene.session
	var covered := -1
	for p in s.level.pieces:
		if p.kind == "trash" and not s.is_hidden(p.id) and not s.is_accessible(p.id):
			covered = p.id
			break
	if not check(covered >= 0, "hay un objeto tapado"):
		return
	check(scene.view.piece_nodes[covered].mesh.material_overlay != null, "lo tapado se ve oscurecido")
	scene._on_piece_tapped(covered)
	var flashing := false
	for pn in scene.view.piece_nodes:
		if pn.get("flashing", false):
			flashing = true
	check(flashing, "se resalta lo que hay que sacar primero")
	scene.queue_free()
	await _frames(1)


func test_debris_thins_out_while_cleaning() -> void:
	var scene := await _open_scene("kitchen", 60, 0.2, 5)
	var s: RoomSession = scene.session
	var count := func() -> int:
		var n := 0
		for mmi in scene.view._debris:
			n += mmi.multimesh.visible_instance_count if mmi.multimesh.visible_instance_count >= 0 else mmi.multimesh.instance_count
		return n
	var before: int = count.call()
	check(before > 30, "hay basura decorativa (%d)" % before)
	for c in s.level.containers.size():
		s.open_container(c)
	var steps: Array = Solver.solve(s.level, s.solver_state()).steps
	for k in 30:
		s.take(steps[k])
	check(count.call() < before, "disminuye al limpiar")
	scene.queue_free()
	await _frames(1)


func test_restoration_fixtures_and_furniture_tap() -> void:
	var game = runner.root.get_node("Game")
	game.reset_progress()
	game.profile.coins = 500
	var scene := await _open_scene("studio", 30, 0.0, 3)
	var s: RoomSession = scene.session
	for i in s.present.size():
		s.present[i] = false
	scene.view.place_all(s)
	scene._start_restoration()
	await _frames(2)
	var coins := int(game.profile.coins)
	scene._on_fixture("window")
	check(scene.view.is_fixed("window"), "el vidrio queda arreglado")
	check(scene._restore.fixtures.window, "se guarda en la restauración")
	eq(int(game.profile.coins), coins - int(Balance.FIXTURES.window.cost), "cuesta monedas")
	# Tocar un mueble en la habitación lo elige en el panel.
	var cam: Camera3D = scene.camera
	var fn: Dictionary = scene.view.furniture_nodes[0]
	var vp: Vector2 = scene.layout.viewpoints[0]
	cam.global_position = Vector3(vp.x, LayoutGeometry.EYE_HEIGHT, vp.y)
	cam.look_at(fn.node.global_position + Vector3(0, fn.def.size.y * 0.6, 0), Vector3.UP)
	var center := scene.get_viewport().get_visible_rect().size * 0.5
	check(scene._tap_restore(center), "tocar el mueble se registra")
	eq(scene.restore_panel._selected, 0, "queda elegido en el panel")
	scene.queue_free()
	await _frames(1)
