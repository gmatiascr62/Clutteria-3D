class_name LevelState
extends RefCounted
## Reglas de accesibilidad y posiciones de reposo, compartidas por la sesión,
## el solver y la escena 3D. Una pieza es accesible si está en la habitación,
## su contenedor (si tiene) está abierto y no hay ninguna pieza presente
## encima en su pila. Al faltar piezas debajo, las de arriba se reacomodan
## hacia abajo (sin físicas).


static func pieces_above(level: Dictionary, slot_piece: Array, present: Array, slot: int) -> int:
	var n := 0
	var s: int = level.slots[slot].above
	while s >= 0:
		var pid: int = slot_piece[s]
		if pid >= 0 and present[pid]:
			n += 1
		s = level.slots[s].above
	return n


static func is_accessible(level: Dictionary, slot_piece: Array, piece_slot: Array, present: Array, opened: Array, pid: int) -> bool:
	if not present[pid]:
		return false
	var sid: int = piece_slot[pid]
	var slot: Dictionary = level.slots[sid]
	if slot.container >= 0 and not opened[slot.container]:
		return false
	return pieces_above(level, slot_piece, present, sid) == 0


## Piezas presentes que esta pieza tapa directamente (para priorizar).
static func covers_count(level: Dictionary, slot_piece: Array, present: Array, slot: int) -> int:
	var n := 0
	var s: int = level.slots[slot].below
	while s >= 0:
		var pid: int = slot_piece[s]
		if pid >= 0 and present[pid]:
			n += 1
		s = level.slots[s].below
	return n


## Posición de reposo: {"space": "room"|"drawer", "pos": Vector3 (base del
## objeto), "yaw": float, "drawer": índice de cajón en LayoutGeometry}.
static func rest_pose(level: Dictionary, slot_piece: Array, present: Array, pid: int, piece_slot: Array) -> Dictionary:
	var sid: int = piece_slot[pid]
	var slot: Dictionary = level.slots[sid]
	var y := 0.0
	var s: int = slot.below
	while s >= 0:
		var other: int = slot_piece[s]
		if other >= 0 and present[other]:
			y += LevelGenerator.piece_size(level.pieces[other]).y
		s = level.slots[s].below
	match slot.kind:
		"pile":
			var pile: Dictionary = level.piles[slot.pile]
			var base: Vector3 = pile.base
			# El mezclador puede traer una pieza más ancha a este lugar: limitar
			# el desplazamiento para que siga dentro de su celda.
			var sz := LevelGenerator.piece_size(level.pieces[pid])
			var r := Vector2(sz.x, sz.z).length() * 0.5
			var off: Vector2 = slot.offset.limit_length(maxf(0.0, LayoutGeometry.CELL * 0.5 - r - 0.005))
			return {"space": "room", "pos": Vector3(base.x + off.x, base.y + y, base.z + off.y), "yaw": slot.yaw}
		"cover":
			var cont: Dictionary = level.containers[slot.container]
			var cov: Dictionary = LayoutGeometry.get_geometry(level.layout).covers[cont.ref]
			var cp: Vector3 = cov.pos
			return {"space": "room", "pos": Vector3(cp.x + slot.offset.x, y, cp.z + slot.offset.y), "yaw": slot.yaw}
		"drawer":
			var cont2: Dictionary = level.containers[slot.container]
			var d: Dictionary = LayoutGeometry.get_geometry(level.layout).drawers[cont2.ref]
			var cap: int = cont2.capacity
			var w: float = d.width - 0.06
			var x: float = -w * 0.5 + w / cap * (float(slot.index) + 0.5)
			return {"space": "drawer", "drawer": cont2.ref, "pos": Vector3(x, 0.02, 0.0), "yaw": slot.yaw}
	return {"space": "room", "pos": Vector3.ZERO, "yaw": 0.0}
