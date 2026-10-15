class_name Solver
extends RefCounted
## Simulador de solvencia independiente del generador. Busca una secuencia
## de toques que vacíe la habitación respetando: accesibilidad (capas y
## contenedores, que se pueden abrir gratis), bandeja de 7 y tríos exactos.
## Usa búsqueda en profundidad con heurística y presupuesto de nodos.

var level: Dictionary
var slot_piece: Array
var piece_slot: Array
var present: Array
var opened: Array
var tray_size := Balance.TRAY_SIZE
var budget := 30000
var nodes := 0


static func solve(lvl: Dictionary, state: Dictionary = {}, node_budget: int = 30000) -> Dictionary:
	var s := Solver.new()
	s.level = lvl
	s.budget = node_budget
	s.slot_piece = state.get("slot_piece", lvl.slot_piece).duplicate()
	s.piece_slot = state.get("piece_slot", lvl.piece_slot).duplicate()
	if state.has("present"):
		s.present = state.present.duplicate()
	else:
		s.present = []
		s.present.resize(lvl.pieces.size())
		s.present.fill(true)
	s.opened = []
	s.opened.resize(lvl.containers.size())
	s.opened.fill(true) # abrir es gratis: el solver asume que se abre lo necesario
	var tray: Dictionary = {}
	for v in state.get("tray", []):
		tray[v] = tray.get(v, 0) + 1
	var steps := []
	var ok := s._dfs(tray, _sum(tray), steps)
	return {"ok": ok, "steps": steps, "nodes": s.nodes}


static func _sum(tray: Dictionary) -> int:
	var n := 0
	for v in tray:
		n += tray[v]
	return n


func _remaining_trash() -> int:
	var n := 0
	for p in level.pieces:
		if p.kind == "trash" and present[p.id]:
			n += 1
	return n


func _dfs(tray: Dictionary, fill: int, steps: Array) -> bool:
	nodes += 1
	if nodes > budget:
		return false
	if _remaining_trash() == 0:
		return fill == 0
	# Accesibles agrupadas por variante.
	var by_var := {}
	var acc := []
	for p in level.pieces:
		if p.kind != "trash" or not present[p.id]:
			continue
		if LevelState.is_accessible(level, slot_piece, piece_slot, present, opened, p.id):
			acc.append(p.id)
			if not by_var.has(p.variant):
				by_var[p.variant] = []
			by_var[p.variant].append(p.id)
	if acc.is_empty():
		return false
	var cands := []
	for pid in acc:
		var v: String = level.pieces[pid].variant
		var in_tray: int = tray.get(v, 0)
		var avail: int = by_var[v].size()
		var score := 0.0
		if in_tray == 2:
			score = 1000.0
		elif in_tray == 1 and avail >= 2:
			score = 800.0
		elif in_tray == 0 and avail >= 3:
			score = 600.0
		elif in_tray + avail >= 3:
			score = 300.0
		else:
			score = 100.0 + in_tray * 50.0
		score += LevelState.covers_count(level, slot_piece, present, piece_slot[pid]) * 5.0
		cands.append([score, pid])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var tried_variants := {}
	for c in cands:
		var pid: int = c[1]
		var v: String = level.pieces[pid].variant
		var key := "%s|%d" % [v, int(c[0])]
		# Misma variante y misma clase de jugada: probar sólo variando cuál tapa.
		if tried_variants.get(key, 0) >= 2:
			continue
		tried_variants[key] = tried_variants.get(key, 0) + 1
		var count: int = tray.get(v, 0) + 1
		var new_fill := fill + 1
		if count < 3 and new_fill >= tray_size:
			continue # llenaría la bandeja sin trío
		present[pid] = false
		var t2 := tray.duplicate()
		if count >= 3:
			t2.erase(v)
			new_fill -= 3
		else:
			t2[v] = count
		steps.append(pid)
		if _dfs(t2, new_fill, steps):
			return true
		steps.pop_back()
		present[pid] = true
		if nodes > budget:
			return false
	return false
