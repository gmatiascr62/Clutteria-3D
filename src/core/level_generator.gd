class_name LevelGenerator
extends RefCounted
## Genera niveles reproducibles por semilla.
##
## Garantías por construcción:
## - Cada variante aparece en cantidad múltiplo de 3.
## - Construcción inversa: se arma una secuencia solución de tríos y se apilan
##   las piezas de abajo hacia arriba en orden inverso, de modo que todo lo que
##   tapa a una pieza pertenece a un trío anterior (o al mismo). Siguiendo la
##   solución la bandeja nunca supera 3 objetos.
## - Las pilas sólo ocupan celdas libres, visibles desde algún punto de
##   observación y sin intersecciones (cada objeto cabe en su celda).
## Además, Solver valida el resultado de forma independiente (ver tests).

const MYSTERY_SIZE := Vector3(0.16, 0.16, 0.16)
const KEY_SIZE := Vector3(0.15, 0.03, 0.07)


static func generate(layout_id: String, item_count: int, difficulty: float, seed_value: int, opts: Dictionary = {}) -> Dictionary:
	assert(item_count % 3 == 0, "item_count debe ser múltiplo de 3")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var L: Dictionary = PropertyCatalog.LAYOUTS[layout_id]
	var geo := LayoutGeometry.get_geometry(layout_id)
	difficulty = clampf(difficulty, 0.0, 1.0)

	# 1) Variantes y tríos.
	var trio_count := item_count / 3
	var variants := _pick_variants(L.theme, trio_count, difficulty, rng)
	var trios := []
	for v in variants:
		trios.append(v)
	while trios.size() < trio_count:
		trios.append(variants[rng.randi_range(0, variants.size() - 1)])
	_shuffle(trios, rng)

	# 2) Piezas en orden de solución.
	var pieces := []
	var solution := []
	for t in trios:
		for k in 3:
			var id := pieces.size()
			pieces.append({"id": id, "kind": "trash", "variant": t})
			solution.append(id)
	var mystery_n: int = opts.get("mystery", PropertyCatalog.mystery_count(item_count))
	var mysteries := []
	for m in mystery_n:
		var id := pieces.size()
		pieces.append({"id": id, "kind": "mystery", "prize": _roll_prize(rng)})
		mysteries.append(id)
	var key_piece := -1
	if opts.get("key", false):
		key_piece = pieces.size()
		pieces.append({"id": key_piece, "kind": "key"})

	# 3) Contenedores: cajones y tapas (cajas/almohadones que se levantan).
	var containers := []
	for di in geo.drawers.size():
		if geo.drawers[di].vps.is_empty():
			continue
		containers.append({"type": "drawer", "ref": di, "capacity": geo.drawers[di].capacity, "vps": geo.drawers[di].vps})
	for ci in geo.covers.size():
		if geo.covers[ci].vps.is_empty():
			continue
		containers.append({"type": "cover", "ref": ci, "capacity": 2, "vps": geo.covers[ci].vps})
	var cap_total := 0
	for c in containers:
		cap_total += c.capacity

	var hidden_target := int(round(item_count * lerpf(0.08, 0.2, difficulty)))
	var specials_hidden := []
	if key_piece >= 0:
		specials_hidden.append(key_piece)
	var pile_bottom_specials := []
	for m in mysteries:
		if rng.randf() < 0.5:
			specials_hidden.append(m)
		else:
			pile_bottom_specials.append(m)
	hidden_target = clampi(hidden_target, 0, maxi(0, cap_total - specials_hidden.size()))
	if specials_hidden.size() > cap_total:
		for i in range(specials_hidden.size() - 1, -1, -1):
			if pieces[specials_hidden[i]].kind == "mystery" and specials_hidden.size() > cap_total:
				pile_bottom_specials.append(specials_hidden[i])
				specials_hidden.remove_at(i)

	# Elegir qué basura va escondida.
	var hidden_trash := []
	var pool := solution.duplicate()
	_shuffle(pool, rng)
	for i in hidden_target:
		hidden_trash.append(pool[i])
	# Orden inverso de solución (las últimas van abajo).
	hidden_trash.sort()
	hidden_trash.reverse()

	var slots := []
	var slot_piece := []
	var piece_slot := []
	piece_slot.resize(pieces.size())
	piece_slot.fill(-1)

	# Llenado de contenedores: especiales primero (quedan abajo).
	var cont_fill := []
	cont_fill.resize(containers.size())
	cont_fill.fill(0)
	var cont_top := []
	cont_top.resize(containers.size())
	cont_top.fill(-1)
	var place_in_container := func(pid: int) -> bool:
		var options := []
		for ci in containers.size():
			if cont_fill[ci] < containers[ci].capacity:
				options.append(ci)
		if options.is_empty():
			return false
		# La llave prefiere cajones.
		if pieces[pid].kind == "key":
			var drawers_only := options.filter(func(ci): return containers[ci].type == "drawer")
			if not drawers_only.is_empty():
				options = drawers_only
		var ci: int = options[rng.randi_range(0, options.size() - 1)]
		var s := {"kind": containers[ci].type, "container": ci, "index": cont_fill[ci], "below": -1, "above": -1,
			"offset": Vector2.ZERO, "yaw": rng.randf_range(0, TAU), "vps": containers[ci].vps}
		if containers[ci].type == "cover":
			s.below = cont_top[ci]
			s.offset = Vector2(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03))
		var sid := slots.size()
		if s.below >= 0:
			slots[s.below].above = sid
		cont_top[ci] = sid
		slots.append(s)
		slot_piece.append(pid)
		piece_slot[pid] = sid
		cont_fill[ci] += 1
		return true
	for pid in specials_hidden:
		place_in_container.call(pid)
	for pid in hidden_trash:
		if not place_in_container.call(pid):
			break

	# 4) Pilas con el resto, en orden inverso de solución.
	var remaining := []
	for i in range(solution.size() - 1, -1, -1):
		if piece_slot[solution[i]] < 0:
			remaining.append(solution[i])
	var need := remaining.size() + pile_bottom_specials.size()
	var cells: Array = geo.cells.duplicate()
	_shuffle(cells, rng)
	var floor_max := 3 + int(round(difficulty * 3.0))
	# Si la habitación es chica para tantos objetos, se permiten pilas más altas.
	var n_floor := 0
	var n_surf := 0
	for c in cells:
		if c.surface:
			n_surf += 1
		else:
			n_floor += 1
	var floor_needed := int(ceil(float(need - n_surf * 2) / maxf(1.0, n_floor))) + 1
	floor_max = clampi(maxi(floor_max, floor_needed), 1, 8)
	var target_depth := lerpf(2.3, 3.8, difficulty)
	var pile_n := clampi(int(ceil(need / target_depth)), 1, cells.size())
	# Distribuir: preferir celdas no contiguas para que las pilas no se tapen.
	var chosen := _choose_spread(cells, pile_n)
	var piles := []
	for c in chosen:
		var mx := 2 if c.surface else floor_max
		piles.append({"cell": c, "cap": rng.randi_range(1, mx), "max": mx, "slots": []})
	var total_cap := func() -> int:
		var s := 0
		for p in piles:
			s += p.cap
		return s
	var guard := 0
	while total_cap.call() < need and guard < 10000:
		guard += 1
		var grown := false
		for p in piles:
			if p.cap < p.max and total_cap.call() < need:
				p.cap += 1
				grown = true
		if not grown:
			var unused := cells.filter(func(c): return not chosen.has(c))
			if unused.is_empty():
				push_error("Capacidad insuficiente en layout %s para %d objetos" % [layout_id, item_count])
				return {}
			var c2: Dictionary = unused[0]
			chosen.append(c2)
			var mx2 := 2 if c2.surface else floor_max
			piles.append({"cell": c2, "cap": 1, "max": mx2, "slots": []})

	var push_on_pile := func(pi: int, pid: int) -> void:
		var p: Dictionary = piles[pi]
		var r := _radius_of(pieces[pid])
		var room := maxf(0.0, LayoutGeometry.CELL * 0.5 - r - 0.005)
		var ang := rng.randf_range(0, TAU)
		var s := {"kind": "pile", "container": -1, "pile": pi, "below": -1, "above": -1,
			"offset": Vector2(cos(ang), sin(ang)) * rng.randf_range(0, room) * 0.85,
			"yaw": rng.randf_range(0, TAU), "vps": p.cell.vps}
		if not p.slots.is_empty():
			s.below = p.slots[-1]
		var sid := slots.size()
		if s.below >= 0:
			slots[s.below].above = sid
		slots.append(s)
		slot_piece.append(pid)
		piece_slot[pid] = sid
		p.slots.append(sid)

	for m in pile_bottom_specials:
		# Cada especial va en el fondo de una pila distinta (nunca apiladas).
		var floor_piles := []
		for pi in piles.size():
			if piles[pi].slots.is_empty():
				floor_piles.append(pi)
		if floor_piles.is_empty():
			var unused2 := cells.filter(func(c): return not chosen.has(c))
			if unused2.is_empty():
				push_error("Sin lugar para especiales en %s" % layout_id)
				return {}
			chosen.append(unused2[0])
			piles.append({"cell": unused2[0], "cap": 0, "max": 2 if unused2[0].surface else floor_max, "slots": []})
			floor_piles.append(piles.size() - 1)
		var pi_m: int = floor_piles[rng.randi_range(0, floor_piles.size() - 1)]
		piles[pi_m].cap += 1
		push_on_pile.call(pi_m, m)
	for pid in remaining:
		var total_free := 0
		for p in piles:
			total_free += p.cap - p.slots.size()
		var pick := rng.randi_range(0, total_free - 1)
		for pi in piles.size():
			var free: int = piles[pi].cap - piles[pi].slots.size()
			if pick < free:
				push_on_pile.call(pi, pid)
				break
			pick -= free

	var pile_out := []
	for p in piles:
		if p.slots.is_empty():
			continue
		pile_out.append({"base": p.cell.pos, "surface": p.cell.surface, "slots": p.slots, "vps": p.cell.vps})
	# Reindexar "pile" en slots tras descartar pilas vacías.
	var remap := {}
	var k := 0
	for pi in piles.size():
		if not piles[pi].slots.is_empty():
			remap[pi] = k
			k += 1
	for s in slots:
		if s.kind == "pile":
			s.pile = remap[s.pile]

	var level := {
		"layout": layout_id, "seed": seed_value, "items": item_count, "difficulty": difficulty,
		"pieces": pieces, "slots": slots, "slot_piece": slot_piece, "piece_slot": piece_slot,
		"piles": pile_out, "containers": containers, "solution": solution,
		"viewpoints": L.viewpoints.size(),
	}
	level["info"] = difficulty_info(level)
	return level


## Datos para calcular el tiempo (ver Balance.level_time).
static func difficulty_info(level: Dictionary) -> Dictionary:
	var fam_variants := {}
	for p in level.pieces:
		if p.kind != "trash":
			continue
		var fam: String = TrashCatalog.variant(p.variant).family
		if not fam_variants.has(fam):
			fam_variants[fam] = {}
		fam_variants[fam][p.variant] = true
	var similar := 0
	var trash := 0
	for p in level.pieces:
		if p.kind != "trash":
			continue
		trash += 1
		if fam_variants[TrashCatalog.variant(p.variant).family].size() >= 2:
			similar += 1
	var depth_sum := 0
	for p in level.piles:
		depth_sum += p.slots.size()
	var hidden := 0
	for s in level.slots:
		if s.container >= 0:
			hidden += 1
	return {
		"items": trash,
		"similar_ratio": float(similar) / maxf(1.0, trash),
		"avg_depth": float(depth_sum) / maxf(1.0, level.piles.size()),
		"hidden": hidden,
		"containers": level.containers.size(),
		"viewpoints": level.viewpoints,
		"difficulty": level.difficulty,
	}


static func piece_size(piece: Dictionary) -> Vector3:
	match piece.kind:
		"mystery": return MYSTERY_SIZE
		"key": return KEY_SIZE
	return TrashCatalog.size_of(piece.variant)


static func _radius_of(piece: Dictionary) -> float:
	var s := piece_size(piece)
	return Vector2(s.x, s.z).length() * 0.5


static func _pick_variants(theme: String, trio_count: int, difficulty: float, rng: RandomNumberGenerator) -> Array:
	var fams := TrashCatalog.families_for_theme(theme).duplicate()
	_shuffle(fams, rng)
	# Cantidad de variantes distintas: más tríos y más dificultad => más variedad.
	var want := clampi(int(round(trio_count * lerpf(0.75, 0.55, difficulty))), 3, 40)
	want = mini(want, trio_count)
	var per_family_max := 1 + int(round(difficulty * 2.0))
	var out := []
	var round_i := 0
	while out.size() < want and round_i < 4:
		for fam in fams:
			if out.size() >= want:
				break
			var vs: Array = fam.variants
			var take := mini(vs.size(), per_family_max + round_i)
			for vi in take:
				if out.size() >= want:
					break
				if not out.has(vs[vi].id):
					out.append(vs[vi].id)
		round_i += 1
	return out


static func _choose_spread(cells: Array, n: int) -> Array:
	# Primero celdas sin vecinas elegidas (en grilla), luego el resto.
	var chosen := []
	var used := {}
	for c in cells:
		if chosen.size() >= n:
			break
		var g: Vector2i = c.grid
		var near := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if used.has(g + d):
				near = true
		if not near:
			chosen.append(c)
			used[g] = true
	for c in cells:
		if chosen.size() >= n:
			break
		if not chosen.has(c):
			chosen.append(c)
	return chosen


static func _roll_prize(rng: RandomNumberGenerator) -> Dictionary:
	# Tabla publicada en el juego: monedas 50 %, herramienta 30 %, tesoro 20 %.
	var r := rng.randf()
	if r < 0.5:
		return {"type": "coins", "amount": rng.randi_range(3, 8) * 10}
	elif r < 0.8:
		var tools := Balance.TOOL_PRICES.keys()
		return {"type": "tool", "tool": tools[rng.randi_range(0, tools.size() - 1)]}
	return {"type": "treasure", "amount": 120, "value": 40}


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
