class_name RoomSession
extends RefCounted
## Reglas de una partida en una habitación, sin dependencias de render.
## La escena 3D observa estas señales y llama a estos métodos.

signal piece_removed(pid: int)
signal pieces_returned(pids: Array)
signal tray_changed
signal trio_cleared(variant: String)
signal container_opened(ci: int)
signal container_closed(ci: int)
signal special_collected(pid: int, piece: Dictionary)
signal state_changed
signal layout_changed(pids: Array)

var level: Dictionary
var mode := "story" # story | replay | contract
var challenge := ""
var tray := Tray.new()
var present: Array = []
var opened: Array = []
## Contenedores abiertos alguna vez (para el desafío "abrir todos").
var ever_opened: Array = []
var slot_piece: Array = []
var piece_slot: Array = []
var time_total := 120.0
var time_left := 120.0
var phase := "trash" # trash | restore | done
var blocked := "" # "" | tray_full | lost
var loss_reason := "" # tray | time
var loss_life_taken := false
var stats := {}
var inventory: Dictionary = {} # referencia a herramientas del perfil


func setup(lvl: Dictionary, p_mode: String, p_challenge: String, p_inventory: Dictionary) -> void:
	level = lvl
	mode = p_mode
	challenge = p_challenge
	inventory = p_inventory
	time_total = Balance.level_time(level.info)
	reset()


func reset() -> void:
	present = []
	present.resize(level.pieces.size())
	present.fill(true)
	opened = []
	opened.resize(level.containers.size())
	opened.fill(false)
	ever_opened = opened.duplicate()
	slot_piece = level.slot_piece.duplicate()
	piece_slot = level.piece_slot.duplicate()
	tray.clear()
	time_left = time_total
	phase = "trash"
	blocked = ""
	loss_reason = ""
	loss_life_taken = false
	stats = {"max_tray": 0, "tools_used": 0, "mystery_opened": 0, "key_found": false,
		"continues": 0, "prizes": [], "treasure_value": 0}
	tray_changed.emit()
	state_changed.emit()


func is_running() -> bool:
	return phase == "trash" and blocked == ""


func is_accessible(pid: int) -> bool:
	return LevelState.is_accessible(level, slot_piece, piece_slot, present, opened, pid)


func is_hidden(pid: int) -> bool:
	var slot: Dictionary = level.slots[piece_slot[pid]]
	return slot.container >= 0 and not opened[slot.container]


func remaining_trash() -> int:
	var n := 0
	for p in level.pieces:
		if p.kind == "trash" and present[p.id]:
			n += 1
	return n


func total_trash() -> int:
	return level.items


func is_cleared() -> bool:
	return remaining_trash() == 0 and tray.slots.is_empty()


## Tocar una pieza. Devuelve {"ok", "reason", "cleared", "full"}.
func take(pid: int) -> Dictionary:
	if not is_running():
		return {"ok": false, "reason": "not_running"}
	if pid < 0 or pid >= level.pieces.size() or not present[pid]:
		return {"ok": false, "reason": "gone"}
	if not is_accessible(pid):
		return {"ok": false, "reason": "covered"}
	var piece: Dictionary = level.pieces[pid]
	if piece.kind != "trash":
		return _collect_special(pid)
	present[pid] = false
	piece_removed.emit(pid)
	var r := tray.add(piece.variant, pid)
	stats.max_tray = maxi(stats.max_tray, r.fill)
	tray_changed.emit()
	if r.cleared != "":
		trio_cleared.emit(r.cleared)
	if r.full:
		blocked = "tray_full"
		state_changed.emit()
	elif is_cleared():
		_finish_trash()
	return {"ok": true, "reason": "", "cleared": r.cleared, "full": r.full}


func _collect_special(pid: int) -> Dictionary:
	var piece: Dictionary = level.pieces[pid]
	present[pid] = false
	if piece.kind == "mystery":
		stats.mystery_opened += 1
		stats.prizes.append(piece.prize)
		if piece.prize.type == "treasure":
			stats.treasure_value += int(piece.prize.get("value", 0))
	elif piece.kind == "key":
		stats.key_found = true
	piece_removed.emit(pid)
	special_collected.emit(pid, piece)
	return {"ok": true, "reason": "", "special": piece.kind, "cleared": "", "full": false}


func open_container(ci: int) -> Array:
	if ci < 0 or ci >= opened.size() or opened[ci]:
		return []
	opened[ci] = true
	ever_opened[ci] = true
	var revealed := []
	for sid in level.slots.size():
		if level.slots[sid].container == ci and slot_piece[sid] >= 0 and present[slot_piece[sid]]:
			revealed.append(slot_piece[sid])
	container_opened.emit(ci)
	return revealed


## Cierra un cajón abierto (las tapas levantadas no se vuelven a poner).
## Lo que queda adentro vuelve a estar oculto hasta abrirlo otra vez.
func close_container(ci: int) -> bool:
	if ci < 0 or ci >= opened.size() or not opened[ci]:
		return false
	if level.containers[ci].type != "drawer":
		return false
	opened[ci] = false
	container_closed.emit(ci)
	return true


func tick(dt: float) -> void:
	if not is_running():
		return
	time_left = maxf(0.0, time_left - dt)
	if time_left <= 0.0:
		declare_loss("time")


## Confirma la derrota (tiempo agotado o rendirse con la bandeja llena).
func declare_loss(reason: String) -> void:
	blocked = "lost"
	loss_reason = reason
	state_changed.emit()


## ¿Esta derrota consume vida? Sólo en niveles nuevos del modo historia.
func loss_costs_life(room_already_completed: bool) -> bool:
	return mode == "story" and not room_already_completed


## Continuar desde el estado anterior (el costo en monedas lo cobra Game).
func continue_after_loss() -> Dictionary:
	var returned := []
	if loss_reason == "tray" or tray.is_full():
		returned = tray.pop_latest(Balance.CONTINUE_RETURN_ITEMS)
		for pid in returned:
			present[pid] = true
		time_left += Balance.CONTINUE_TIME_TRAYFULL
		pieces_returned.emit(returned)
		tray_changed.emit()
	else:
		time_left += Balance.CONTINUE_TIME_TIMEOUT
	stats.continues += 1
	blocked = ""
	loss_reason = ""
	loss_life_taken = false
	state_changed.emit()
	return {"returned": returned}


func has_tool(tool: String) -> bool:
	return int(inventory.get(tool, 0)) > 0


## Herramientas. Devuelve {"ok", "reason", "removed": [...], "moved": [...]}.
func use_tool(tool: String, arg = null) -> Dictionary:
	if phase != "trash" or blocked == "lost":
		return {"ok": false, "reason": "not_running"}
	if not has_tool(tool):
		return {"ok": false, "reason": "no_tool"}
	var res := {}
	match tool:
		"papelera":
			res = _tool_trash(int(arg) if arg != null else -1)
		"iman":
			res = _tool_magnet()
		"mezclador":
			res = _tool_shuffle(int(arg) if arg != null else int(Time.get_ticks_usec()))
		"reloj":
			if blocked != "":
				return {"ok": false, "reason": "blocked"}
			time_left += Balance.CLOCK_BONUS
			res = {"ok": true}
		_:
			return {"ok": false, "reason": "unknown"}
	if res.get("ok", false):
		inventory[tool] = int(inventory[tool]) - 1
		stats.tools_used += 1
		if blocked == "tray_full" and not tray.is_full():
			blocked = ""
		state_changed.emit()
		if is_cleared():
			_finish_trash()
	return res


## Papelera: descarta el objeto elegido de la bandeja junto con los demás de
## su variante hasta completar su trío (así los conteos siguen siendo
## múltiplos de 3 y el nivel sigue siendo resoluble).
func _tool_trash(slot_index: int) -> Dictionary:
	if tray.slots.is_empty():
		return {"ok": false, "reason": "empty"}
	if slot_index < 0 or slot_index >= tray.slots.size():
		slot_index = tray.slots.size() - 1
	var v: String = tray.slots[slot_index].variant
	return _complete_trio(v)


## Imán: completa un trío válido con objetos existentes de la habitación.
func _tool_magnet() -> Dictionary:
	var counts := tray.variants_count()
	var best := ""
	var best_n := 0
	for v in counts:
		if counts[v] > best_n:
			best = v
			best_n = counts[v]
	if best == "":
		# Sin nada en bandeja: elegir la variante con más objetos accesibles.
		var acc := {}
		for p in level.pieces:
			if p.kind == "trash" and present[p.id] and is_accessible(p.id):
				acc[p.variant] = acc.get(p.variant, 0) + 1
		for v in acc:
			if acc[v] > best_n:
				best = v
				best_n = acc[v]
	if best == "":
		return {"ok": false, "reason": "nothing"}
	return _complete_trio(best)


func _complete_trio(v: String) -> Dictionary:
	var from_tray := tray.remove_variant(v, 3)
	var need := 3 - from_tray.size()
	var candidates := []
	for p in level.pieces:
		if p.kind == "trash" and present[p.id] and p.variant == v:
			candidates.append(p.id)
	# Preferir accesibles, luego las menos tapadas.
	candidates.sort_custom(func(a, b):
		var aa := 0 if is_accessible(a) else 1
		var bb := 0 if is_accessible(b) else 1
		if aa != bb:
			return aa < bb
		return LevelState.pieces_above(level, slot_piece, present, piece_slot[a]) < LevelState.pieces_above(level, slot_piece, present, piece_slot[b]))
	if candidates.size() < need:
		# No debería pasar: los conteos son múltiplos de 3.
		for pid in from_tray:
			tray.add(v, pid)
		return {"ok": false, "reason": "inconsistent"}
	var removed := []
	for i in need:
		present[candidates[i]] = false
		removed.append(candidates[i])
		piece_removed.emit(candidates[i])
	tray_changed.emit()
	trio_cleared.emit(v)
	return {"ok": true, "removed": removed, "variant": v}


## Mezclador: permuta los objetos visibles y accesibles entre sus lugares,
## y sólo acepta la permutación si el estado sigue siendo resoluble.
func _tool_shuffle(seed_value: int) -> Dictionary:
	if blocked != "":
		return {"ok": false, "reason": "blocked"}
	var acc := []
	for p in level.pieces:
		if p.kind == "trash" and present[p.id] and is_accessible(p.id) and level.slots[piece_slot[p.id]].kind == "pile":
			acc.append(p.id)
	if acc.size() < 2:
		return {"ok": false, "reason": "nothing"}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var orig_slots := []
	for pid in acc:
		orig_slots.append(piece_slot[pid])
	for attempt in 8:
		var perm := orig_slots.duplicate()
		LevelGenerator._shuffle(perm, rng)
		for i in acc.size():
			piece_slot[acc[i]] = perm[i]
			slot_piece[perm[i]] = acc[i]
		var check := Solver.solve(level, solver_state(), 4000)
		if check.ok:
			layout_changed.emit(acc)
			return {"ok": true, "moved": acc}
	for i in acc.size():
		piece_slot[acc[i]] = orig_slots[i]
		slot_piece[orig_slots[i]] = acc[i]
	return {"ok": false, "reason": "unsafe"}


func solver_state() -> Dictionary:
	var t := []
	for s in tray.slots:
		t.append(s.variant)
	return {"present": present, "slot_piece": slot_piece, "piece_slot": piece_slot, "tray": t}


func _finish_trash() -> void:
	# Cajas o llaves que quedaron (p. ej. al fondo de la última pila) se
	# entregan al terminar; no cuentan para el desafío de "abrir una caja".
	for p in level.pieces:
		if p.kind != "trash" and present[p.id]:
			present[p.id] = false
			if p.kind == "mystery":
				stats.prizes.append(p.prize)
				stats["auto_found"] = int(stats.get("auto_found", 0)) + 1
				if p.prize.type == "treasure":
					stats.treasure_value += int(p.prize.get("value", 0))
			elif p.kind == "key":
				stats.key_found = true
			piece_removed.emit(p.id)
			special_collected.emit(p.id, p)
	phase = "restore"
	blocked = ""
	state_changed.emit()


func challenge_met() -> bool:
	match challenge:
		"find_mystery":
			return stats.mystery_opened > 0
		"tray_max5":
			return stats.max_tray <= 5
		"no_tools":
			return stats.tools_used == 0
		"all_containers":
			for o in ever_opened:
				if not o:
					return false
			return true
	return false


func time_star() -> bool:
	return stats.continues == 0 and time_left >= time_total * Balance.STAR2_TIME_FRACTION


func stars() -> int:
	return 1 + (1 if time_star() else 0) + (1 if challenge_met() else 0)


func to_dict() -> Dictionary:
	var removed := []
	for i in present.size():
		if not present[i]:
			removed.append(i)
	return {
		"removed": removed, "opened": opened.duplicate(), "ever_opened": ever_opened.duplicate(), "tray": tray.to_dict(),
		"piece_slot": piece_slot.duplicate(), "time_total": time_total, "time_left": time_left,
		"phase": phase, "blocked": blocked, "loss_reason": loss_reason,
		"loss_life_taken": loss_life_taken, "stats": stats.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	reset()
	for i in d.get("removed", []):
		present[int(i)] = false
	var op: Array = d.get("opened", [])
	for i in mini(op.size(), opened.size()):
		opened[i] = bool(op[i])
	# Guardados anteriores no tenían "ever_opened": usar los abiertos.
	var ev: Array = d.get("ever_opened", op)
	for i in mini(ev.size(), ever_opened.size()):
		ever_opened[i] = bool(ev[i]) or opened[i]
	tray.from_dict(d.get("tray", {}))
	var ps: Array = d.get("piece_slot", [])
	if ps.size() == piece_slot.size():
		for pid in ps.size():
			piece_slot[pid] = int(ps[pid])
			slot_piece[int(ps[pid])] = pid
	time_total = float(d.get("time_total", time_total))
	time_left = float(d.get("time_left", time_total))
	phase = String(d.get("phase", "trash"))
	blocked = String(d.get("blocked", ""))
	loss_reason = String(d.get("loss_reason", ""))
	loss_life_taken = bool(d.get("loss_life_taken", false))
	var st: Dictionary = d.get("stats", {})
	for k in st:
		stats[k] = st[k]
	stats.max_tray = int(stats.max_tray)
	stats.tools_used = int(stats.tools_used)
	stats.mystery_opened = int(stats.mystery_opened)
	stats.continues = int(stats.continues)
	stats.treasure_value = int(stats.treasure_value)
	tray_changed.emit()
	state_changed.emit()
