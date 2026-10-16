extends "res://tests/test_base.gd"
## Generación y solvencia para muchas semillas, incluyendo ocultos.

const SEEDS_PER_ROOM := 6


func _all_room_configs() -> Array:
	var out := []
	for pid in PropertyCatalog.PROPERTIES:
		var P: Dictionary = PropertyCatalog.PROPERTIES[pid]
		for i in P.rooms.size():
			var r: Dictionary = P.rooms[i]
			check(r.items <= PropertyCatalog.LAYOUTS[r.layout].max_items, "%s/%d supera el máximo del layout" % [pid, i])
			out.append({"key": "%s/%d" % [pid, i], "layout": r.layout, "items": r.items, "difficulty": r.difficulty, "key_piece": r.has("key_for")})
	return out


func test_every_layout_has_cells_and_viewpoints() -> void:
	for lid in PropertyCatalog.LAYOUTS:
		var g := LayoutGeometry.get_geometry(lid)
		check(g.cells.size() >= 12, "%s tiene celdas visibles suficientes (%d)" % [lid, g.cells.size()])
		check(PropertyCatalog.LAYOUTS[lid].viewpoints.size() >= 2, "%s tiene varios puntos de observación" % lid)
		for d in g.drawers:
			check(not d.vps.is_empty(), "%s: cada cajón es visible desde algún punto" % lid)


func test_catalog_variants_distinct() -> void:
	var seen := {}
	for id in TrashCatalog.all_variant_ids():
		var v := TrashCatalog.variant(id)
		var sig := "%s|%s|%s|%.2f" % [v.shape, v.color, v.accent, v.scale]
		check(not seen.has(sig), "variantes %s y %s son visualmente idénticas" % [id, seen.get(sig, "")])
		seen[sig] = id
		check(TrashCatalog.footprint_radius(id) <= LayoutGeometry.CELL * 0.5 - 0.01, "%s cabe en una celda" % id)


func test_same_seed_is_deterministic() -> void:
	var a := LevelGenerator.generate("kitchen", 60, 0.3, 12345)
	var b := LevelGenerator.generate("kitchen", 60, 0.3, 12345)
	eq(JSON.stringify(a), JSON.stringify(b), "misma semilla => mismo nivel")
	var c := LevelGenerator.generate("kitchen", 60, 0.3, 12346)
	check(JSON.stringify(a) != JSON.stringify(c), "otra semilla => otro nivel")


func test_all_rooms_many_seeds_valid_and_solvable() -> void:
	var total := 0
	for cfg in _all_room_configs():
		for s in SEEDS_PER_ROOM:
			var seed_value := 1000 + s * 7919 + total
			var lvl := LevelGenerator.generate(cfg.layout, cfg.items, cfg.difficulty, seed_value, {"key": cfg.key_piece})
			total += 1
			if not check(not lvl.is_empty(), "%s semilla %d genera" % [cfg.key, seed_value]):
				continue
			_validate(lvl, "%s/%d" % [cfg.key, seed_value])
	check(total > 100, "se probaron muchas semillas (%d)" % total)


func test_contract_layouts_many_seeds() -> void:
	for lid in PropertyCatalog.LAYOUTS:
		for items in [30, 90, PropertyCatalog.LAYOUTS[lid].max_items]:
			for s in 3:
				var lvl := LevelGenerator.generate(lid, items, 0.5, s * 31 + items)
				_validate(lvl, "%s/%d/%d" % [lid, items, s])


func test_unsolvable_detected() -> void:
	# Construcción manual: dos pilas que se tapan cruzadas con 7 variantes
	# distintas arriba => imposible sin llenar la bandeja.
	var lvl := LevelGenerator.generate("studio", 30, 0.0, 99)
	# Forzar estado: bandeja con 6 objetos distintos y sin pares accesibles.
	var st := {"tray": ["x1", "x2", "x3", "x4", "x5", "x6"]}
	var r := Solver.solve(lvl, st, 2000)
	check(not r.ok, "el solver detecta estados sin salida")


func _validate(lvl: Dictionary, tag: String) -> void:
	# Múltiplos de 3 por variante.
	var counts := {}
	var trash := 0
	for p in lvl.pieces:
		if p.kind == "trash":
			counts[p.variant] = counts.get(p.variant, 0) + 1
			trash += 1
	eq(trash, lvl.items, "%s: cantidad de basura" % tag)
	for v in counts:
		check(counts[v] % 3 == 0, "%s: %s tiene %d (no múltiplo de 3)" % [tag, v, counts[v]])
	# Cada pieza tiene lugar y ese lugar es visible desde algún punto.
	for p in lvl.pieces:
		var sid: int = lvl.piece_slot[p.id]
		if not check(sid >= 0, "%s: pieza %d sin lugar" % [tag, p.id]):
			return
		check(not lvl.slots[sid].vps.is_empty(), "%s: lugar %d invisible" % [tag, sid])
	# Sin intersecciones entre objetos de pilas distintas ni con muebles.
	_check_overlaps(lvl, tag)
	# Solvencia independiente.
	var r := Solver.solve(lvl)
	check(r.ok, "%s: el solver encontró solución (nodos %d)" % [tag, r.nodes])
	# Las especiales quedan accesibles al final.
	if r.ok:
		var present := []
		present.resize(lvl.pieces.size())
		present.fill(true)
		for pid in r.steps:
			present[pid] = false
		var opened := []
		opened.resize(lvl.containers.size())
		opened.fill(true)
		# Recoger especiales accesibles (una puede tapar a otra en una caja).
		var changed := true
		while changed:
			changed = false
			for p in lvl.pieces:
				if p.kind != "trash" and present[p.id] and LevelState.is_accessible(lvl, lvl.slot_piece, lvl.piece_slot, present, opened, p.id):
					present[p.id] = false
					changed = true
		for p in lvl.pieces:
			check(not present[p.id], "%s: pieza %d alcanzable al final" % [tag, p.id])


func _check_overlaps(lvl: Dictionary, tag: String) -> void:
	var present := []
	present.resize(lvl.pieces.size())
	present.fill(true)
	var geo := LayoutGeometry.get_geometry(lvl.layout)
	var boxes := []
	for p in lvl.pieces:
		var pose := LevelState.rest_pose(lvl, lvl.slot_piece, present, p.id, lvl.piece_slot)
		if pose.space != "room":
			continue
		var size := LevelGenerator.piece_size(p)
		var r := Vector2(size.x, size.z).length() * 0.5
		var c: Vector3 = pose.pos
		boxes.append({"id": p.id, "c": c, "r": r, "h": size.y, "slot": lvl.slots[lvl.piece_slot[p.id]]})
	var room: Vector3 = PropertyCatalog.LAYOUTS[lvl.layout].size
	for b in boxes:
		check(absf(b.c.x) + b.r <= room.x * 0.5 and absf(b.c.z) + b.r <= room.z * 0.5, "%s: pieza %d fuera de la habitación" % [tag, b.id])
		if b.slot.kind == "pile":
			var foot := AABB(Vector3(b.c.x - b.r * 0.7, b.c.y + 0.005, b.c.z - b.r * 0.7), Vector3(b.r * 1.4, b.h - 0.01, b.r * 1.4))
			for fb in geo.blockers:
				check(not fb.intersects(foot), "%s: pieza %d atraviesa un mueble" % [tag, b.id])
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var a: Dictionary = boxes[i]
			var b: Dictionary = boxes[j]
			var dxz := Vector2(a.c.x - b.c.x, a.c.z - b.c.z).length()
			if dxz >= a.r + b.r:
				continue
			# Se solapan en planta: deben estar apilados sin cruzarse en altura.
			var overlap_y := minf(a.c.y + a.h, b.c.y + b.h) - maxf(a.c.y, b.c.y)
			check(overlap_y <= 0.001, "%s: piezas %d y %d se intersectan" % [tag, a.id, b.id])


func test_solution_respects_tray_bound() -> void:
	for diff in [0.0, 0.3, 0.6, 0.9]:
		for seed_value in 8:
			var lvl := LevelGenerator.generate("living", 90, diff, 500 + seed_value)
			var t := Tray.new()
			var worst := 0
			for pid in lvl.solution:
				var r := t.add(lvl.pieces[pid].variant, pid)
				worst = maxi(worst, r.fill)
				if not check(not r.full, "dif %.1f: la solución nunca llena la bandeja" % diff):
					return
			check(worst <= 2 * lvl.max_open + 1, "dif %.1f: ocupación %d dentro del límite de %d tríos a medias" % [diff, worst, lvl.max_open])


func test_tray_max5_rooms_stay_achievable() -> void:
	var lvl := LevelGenerator.generate("kitchen", 120, 0.8, 3, {"max_open": 2})
	var t := Tray.new()
	var worst := 0
	for pid in lvl.solution:
		worst = maxi(worst, t.add(lvl.pieces[pid].variant, pid).fill)
	check(worst <= 5, "con max_open 2 la solución usa como mucho 5 espacios (%d)" % worst)


func test_harder_levels_have_fewer_ready_trios_on_top() -> void:
	# Proporción de basura visible al inicio que ya forma tríos completos.
	var ratio := func(diff: float) -> float:
		var total := 0.0
		for seed_value in 10:
			var lvl := LevelGenerator.generate("living", 90, diff, 900 + seed_value)
			var present := []
			present.resize(lvl.pieces.size())
			present.fill(true)
			var opened := []
			opened.resize(lvl.containers.size())
			opened.fill(true)
			var acc := {}
			var n := 0
			for p in lvl.pieces:
				if p.kind == "trash" and LevelState.is_accessible(lvl, lvl.slot_piece, lvl.piece_slot, present, opened, p.id):
					acc[p.variant] = acc.get(p.variant, 0) + 1
					n += 1
			var ready := 0
			for v in acc:
				ready += (acc[v] / 3) * 3
			total += float(ready) / maxf(1.0, n)
		return total / 10.0
	var easy: float = ratio.call(0.0)
	var hard: float = ratio.call(0.8)
	check(hard < easy, "más dificultad, menos tríos servidos arriba (fácil %.2f, difícil %.2f)" % [easy, hard])
