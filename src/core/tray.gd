class_name Tray
extends RefCounted
## Bandeja de 7 espacios. Agrupa por ID exacto de variante y elimina tríos.

var size: int = Balance.TRAY_SIZE
## Cada entrada: {"variant": String, "piece": int, "seq": int}
var slots: Array = []
var _seq := 0


## Agrega un objeto. Devuelve {"cleared": variant o "", "cleared_pieces": [...],
## "full": bool, "fill": cantidad ocupada justo al entrar (antes del trío)}.
func add(variant: String, piece: int) -> Dictionary:
	var insert_at := slots.size()
	for i in range(slots.size() - 1, -1, -1):
		if slots[i].variant == variant:
			insert_at = i + 1
			break
	_seq += 1
	slots.insert(insert_at, {"variant": variant, "piece": piece, "seq": _seq})
	var fill := slots.size()
	# index: dónde cayó el objeto; cleared_at: primer espacio del trío eliminado.
	var result := {"cleared": "", "cleared_pieces": [], "full": false, "fill": fill,
		"index": insert_at, "cleared_at": -1}
	if count(variant) >= 3:
		result.cleared = variant
		for i in slots.size():
			if slots[i].variant == variant:
				result.cleared_at = i
				break
		result.cleared_pieces = remove_variant(variant, 3)
	result.full = slots.size() >= size
	return result


func count(variant: String) -> int:
	var n := 0
	for s in slots:
		if s.variant == variant:
			n += 1
	return n


func is_full() -> bool:
	return slots.size() >= size


func free_slots() -> int:
	return size - slots.size()


## Quita hasta `limit` copias de la variante. Devuelve las piezas quitadas.
func remove_variant(variant: String, limit: int = 99) -> Array:
	var removed := []
	var i := 0
	while i < slots.size() and removed.size() < limit:
		if slots[i].variant == variant:
			removed.append(slots[i].piece)
			slots.remove_at(i)
		else:
			i += 1
	return removed


## Quita las `n` piezas agregadas más recientemente.
func pop_latest(n: int) -> Array:
	var order := slots.duplicate()
	order.sort_custom(func(a, b): return a.seq > b.seq)
	var out := []
	for k in mini(n, order.size()):
		out.append(order[k].piece)
		slots.erase(order[k])
	return out


func variants_count() -> Dictionary:
	var d := {}
	for s in slots:
		d[s.variant] = d.get(s.variant, 0) + 1
	return d


func clear() -> void:
	slots.clear()


func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true), "seq": _seq}


func from_dict(d: Dictionary) -> void:
	slots = []
	for s in d.get("slots", []):
		slots.append({"variant": String(s.variant), "piece": int(s.piece), "seq": int(s.seq)})
	_seq = int(d.get("seq", slots.size()))
