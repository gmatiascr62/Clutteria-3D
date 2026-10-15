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
