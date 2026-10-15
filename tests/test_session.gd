extends "res://tests/test_base.gd"
## Reglas de partida: tríos, bandeja llena, ayudas, tiempo, pausa,
## pérdida de vida y reanudación.

var inv: Dictionary


func before_each() -> void:
	inv = {"papelera": 1, "iman": 1, "mezclador": 1, "reloj": 1}


func _session(items := 30, seed_value := 42, layout := "studio") -> RoomSession:
	var lvl := LevelGenerator.generate(layout, items, 0.2, seed_value)
	var s := RoomSession.new()
	s.setup(lvl, "story", "no_tools", inv)
	return s


func _first_accessible(s: RoomSession, variant := "", exclude := []) -> int:
	for p in s.level.pieces:
		if p.kind == "trash" and s.present[p.id] and s.is_accessible(p.id) and not exclude.has(p.id):
			if variant == "" or p.variant == variant:
				return p.id
	return -1


func test_follow_solution_completes() -> void:
	var s := _session()
	for c in s.level.containers.size():
		s.open_container(c)
	for pid in s.level.solution:
		var r := s.take(pid)
		if not check(r.ok, "toma %d ok (%s)" % [pid, r.get("reason", "")]):
			return
	check(s.is_cleared(), "habitación limpia")
	eq(s.phase, "restore", "pasa a restauración")
	check(s.stars() >= 2, "con tiempo de sobra y sin herramientas: >= 2 estrellas")


func test_covered_and_hidden_not_selectable() -> void:
	var s := _session(60, 7)
	var covered := -1
	var hidden := -1
	for p in s.level.pieces:
		var slot: Dictionary = s.level.slots[s.piece_slot[p.id]]
		if slot.container >= 0 and hidden < 0 and p.kind == "trash":
			hidden = p.id
		elif slot.container < 0 and slot.above >= 0 and covered < 0 and p.kind == "trash":
			covered = p.id
	check(covered >= 0, "hay piezas tapadas")
	eq(s.take(covered).reason, "covered", "una pieza tapada no se puede tomar")
	if hidden >= 0:
		eq(s.take(hidden).reason, "covered", "una pieza en cajón cerrado no se puede tomar")
		var cont: int = s.level.slots[s.piece_slot[hidden]].container
		var revealed := s.open_container(cont)
		check(revealed.size() > 0, "abrir revela piezas")
		eq(s.tray.slots.size(), 0, "explorar no ocupa la bandeja")


func test_tray_full_blocks_and_timer_freezes() -> void:
	var s := _session(90, 3, "living")
	for c in s.level.containers.size():
		s.open_container(c)
	# Tomar accesibles evitando completar tríos hasta llenar la bandeja.
	var guard := 0
	while not s.tray.is_full() and guard < 200:
		guard += 1
		var counts := s.tray.variants_count()
		var pick := -1
		for p in s.level.pieces:
			if p.kind == "trash" and s.present[p.id] and s.is_accessible(p.id) and counts.get(p.variant, 0) < 2:
				pick = p.id
				break
		if pick < 0:
			break
		s.take(pick)
	if not check(s.tray.is_full(), "se pudo llenar la bandeja"):
		return
	eq(s.blocked, "tray_full", "estado bandeja llena")
	var t := s.time_left
	s.tick(5.0)
	eq(s.time_left, t, "el cronómetro se congela con la bandeja llena")
	eq(s.take(_first_accessible(s)).reason, "not_running", "no se puede tocar más")
	# Papelera libera espacio.
	var r := s.use_tool("papelera", 0)
	check(r.ok, "papelera utilizable")
	eq(inv.papelera, 0, "consume la herramienta")
	eq(s.blocked, "", "se destraba")
	check(s.tray.free_slots() >= 1, "liberó espacio")
	check(Solver.solve(s.level, s.solver_state(), 30000).ok, "sigue siendo resoluble tras la papelera")


func test_trash_keeps_multiples_of_three() -> void:
	var s := _session(60, 11, "kitchen")
	var pid := _first_accessible(s)
	var v: String = s.level.pieces[pid].variant
	s.take(pid)
	s.use_tool("papelera", 0)
	var left := 0
	for p in s.level.pieces:
		if p.kind == "trash" and p.variant == v and s.present[p.id]:
			left += 1
	eq(left % 3, 0, "quedan múltiplos de 3 de esa variante")


func test_magnet_completes_valid_trio() -> void:
	var s := _session(45, 5, "kitchen")
	var pid := _first_accessible(s)
	s.take(pid)
	var before := s.remaining_trash()
	var r := s.use_tool("iman")
	check(r.ok, "imán ok")
	eq(s.tray.slots.size(), 0, "completa el trío de la bandeja")
	eq(before - s.remaining_trash(), 2, "trae exactamente los 2 que faltaban")


func test_shuffle_keeps_solvable() -> void:
	var s := _session(90, 21, "bedroom")
	var before := s.piece_slot.duplicate()
	var r := s.use_tool("mezclador", 777)
	check(r.ok, "mezclador ok (%s)" % r.get("reason", ""))
	check(before != s.piece_slot, "cambió posiciones")
	check(Solver.solve(s.level, s.solver_state(), 30000).ok, "sigue siendo resoluble")
	for pid in r.get("moved", []):
		check(s.is_accessible(pid), "lo movido sigue accesible")


func test_clock_adds_time() -> void:
	var s := _session()
	s.tick(10.0)
	var t := s.time_left
	s.use_tool("reloj")
	eq(s.time_left, t + Balance.CLOCK_BONUS, "+30 s")


func test_no_tool_cannot_use() -> void:
	var s := _session()
	inv.reloj = 0
	eq(s.use_tool("reloj").reason, "no_tool", "sin herramienta no se usa")


func test_time_up_and_continue() -> void:
	var s := _session()
	s.tick(s.time_total + 1.0)
	eq(s.blocked, "lost", "pierde por tiempo")
	eq(s.loss_reason, "time", "motivo tiempo")
	check(s.loss_costs_life(false), "nivel nuevo: cuesta vida")
	check(not s.loss_costs_life(true), "nivel repetido: no cuesta vida")
	s.continue_after_loss()
	eq(s.blocked, "", "continúa")
	eq(s.time_left, Balance.CONTINUE_TIME_TIMEOUT, "con tiempo extra")
	check(not s.time_star(), "continuar quita la estrella de tiempo")


func test_contract_and_replay_never_cost_life() -> void:
	var s := _session()
	s.mode = "contract"
	check(not s.loss_costs_life(false), "encargo no cuesta vida")
	s.mode = "replay"
	check(not s.loss_costs_life(false), "repetir no cuesta vida")


func test_restart_resets_everything() -> void:
	var s := _session()
	s.take(_first_accessible(s))
	s.tick(20)
	s.reset()
	eq(s.tray.slots.size(), 0, "bandeja vacía")
	eq(s.remaining_trash(), 30, "toda la basura vuelve")
	eq(s.time_left, s.time_total, "tiempo completo")


func test_serialize_resume_exact() -> void:
	var s := _session(60, 8, "bedroom")
	for c in [0]:
		s.open_container(c)
	for i in 4:
		s.take(_first_accessible(s))
	s.use_tool("mezclador", 5)
	s.tick(12.5)
	var data: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var s2 := RoomSession.new()
	s2.setup(s.level, "story", "no_tools", inv)
	s2.from_dict(data)
	eq(s2.present, s.present, "mismas piezas presentes")
	eq(s2.piece_slot, s.piece_slot, "mismas posiciones tras mezclar")
	eq(s2.opened, s.opened, "mismos contenedores abiertos")
	eq(s2.tray.to_dict().slots.size(), s.tray.to_dict().slots.size(), "misma bandeja")
	check(absf(s2.time_left - s.time_left) < 0.001, "mismo tiempo")
	eq(s2.stats.tools_used, s.stats.tools_used, "mismas estadísticas")


func test_leftover_specials_delivered_on_finish() -> void:
	var lvl := LevelGenerator.generate("kitchen", 45, 0.2, 77, {"key": true})
	var s := RoomSession.new()
	s.setup(lvl, "story", "find_mystery", inv)
	var got := []
	s.special_collected.connect(func(pid, _p): got.append(pid))
	for c in lvl.containers.size():
		s.open_container(c)
	for pid in Solver.solve(lvl).steps:
		s.take(pid)
	var specials := 0
	for p in lvl.pieces:
		if p.kind != "trash":
			specials += 1
			check(not s.present[p.id], "especial %d entregada" % p.id)
	eq(got.size(), specials, "se notifican todas las especiales")
	check(s.stats.key_found, "la llave no se pierde")
	check(not s.challenge_met(), "entregadas automáticamente no cumplen el desafío")


func test_mystery_and_challenges() -> void:
	var s := RoomSession.new()
	var lvl := LevelGenerator.generate("studio", 30, 0.0, 4)
	s.setup(lvl, "story", "find_mystery", inv)
	check(not s.challenge_met(), "sin abrir caja no se cumple")
	for c in lvl.containers.size():
		s.open_container(c)
	var res := Solver.solve(lvl)
	for pid in res.steps:
		s.take(pid)
		for p in lvl.pieces:
			if p.kind == "mystery" and s.present[p.id] and s.is_accessible(p.id):
				var r := s.take(p.id)
				eq(r.get("special", ""), "mystery", "se abre al tocarla")
	check(s.stats.mystery_opened >= 1, "abrió caja")
	check(s.challenge_met(), "desafío cumplido")
	eq(s.stars(), 3, "3 estrellas")
