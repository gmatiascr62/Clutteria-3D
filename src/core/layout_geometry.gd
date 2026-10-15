class_name LayoutGeometry
extends RefCounted
## Geometría derivada de un layout, sin depender del render: cajas de muebles,
## cajones, celdas libres para pilas de basura y visibilidad desde cada punto
## de observación (segmento ojo→celda sin atravesar muebles).

const EYE_HEIGHT := 1.55
const CELL := 0.40
const VIEWPOINT_CLEAR := 0.5
const DRAWER_ZONE := 0.45
const MAX_VIEW_DIST := 4.8

static var _cache: Dictionary = {}


static func get_geometry(layout_id: String) -> Dictionary:
	if _cache.has(layout_id):
		return _cache[layout_id]
	var g := _compute(layout_id)
	_cache[layout_id] = g
	return g


static func furniture_aabb(f: Dictionary) -> AABB:
	var s: Vector3 = f.size
	return AABB(Vector3(f.pos.x - s.x * 0.5, 0.0, f.pos.y - s.z * 0.5), s)


static func cover_aabb(c: Dictionary) -> AABB:
	var s: Vector3 = c.size
	return AABB(Vector3(c.pos.x - s.x * 0.5, 0.0, c.pos.y - s.z * 0.5), s)


static func face_normal(face: String) -> Vector3:
	match face:
		"+z": return Vector3(0, 0, 1)
		"-z": return Vector3(0, 0, -1)
		"+x": return Vector3(1, 0, 0)
		"-x": return Vector3(-1, 0, 0)
	return Vector3(0, 0, 1)


static func eye(vp: Vector2) -> Vector3:
	return Vector3(vp.x, EYE_HEIGHT, vp.y)


static func _compute(layout_id: String) -> Dictionary:
	var L: Dictionary = PropertyCatalog.LAYOUTS[layout_id]
	var size: Vector3 = L.size
	var blockers: Array[AABB] = []
	for f in L.furniture:
		blockers.append(furniture_aabb(f))
	for c in L.covers:
		blockers.append(cover_aabb(c))

	# Cajones: frente sobre la cara indicada del mueble.
	var drawers := []
	for fi in L.furniture.size():
		var f: Dictionary = L.furniture[fi]
		var n: int = f.get("drawers", 0)
		if n <= 0:
			continue
		var normal := face_normal(f.face)
		var fs: Vector3 = f.size
		var along := Vector3(1, 0, 0) if absf(normal.z) > 0.5 else Vector3(0, 0, 1)
		var span: float = fs.x if absf(normal.z) > 0.5 else fs.z
		var depth_f: float = fs.z if absf(normal.z) > 0.5 else fs.x
		var w := span / n - 0.05
		var h := clampf(fs.y * 0.28, 0.14, 0.24)
		var y := fs.y - 0.06 - h * 0.5
		if f.type == "chest":
			y = fs.y * 0.45
		for i in n:
			var off := -span * 0.5 + span / n * (i + 0.5)
			var front := Vector3(f.pos.x, y, f.pos.y) + along * off + normal * (depth_f * 0.5)
			drawers.append({
				"furniture": fi, "front": front, "normal": normal, "along": along,
				"width": w, "height": h, "depth": minf(0.4, depth_f - 0.05),
				"capacity": clampi(int(w / 0.22), 1, 3),
			})

	# Zonas donde se abre un cajón: no se apila basura ahí.
	var drawer_zones: Array[AABB] = []
	for fi in L.furniture.size():
		var f: Dictionary = L.furniture[fi]
		if f.get("drawers", 0) <= 0:
			continue
		var a := furniture_aabb(f)
		var nrm := face_normal(f.face)
		var z := a
		if nrm.z > 0.5:
			z = AABB(Vector3(a.position.x, 0, a.end.z), Vector3(a.size.x, 1, DRAWER_ZONE))
		elif nrm.z < -0.5:
			z = AABB(Vector3(a.position.x, 0, a.position.z - DRAWER_ZONE), Vector3(a.size.x, 1, DRAWER_ZONE))
		elif nrm.x > 0.5:
			z = AABB(Vector3(a.end.x, 0, a.position.z), Vector3(DRAWER_ZONE, 1, a.size.z))
		else:
			z = AABB(Vector3(a.position.x - DRAWER_ZONE, 0, a.position.z), Vector3(DRAWER_ZONE, 1, a.size.z))
		drawer_zones.append(z)

	var cells := []
	# Celdas de piso.
	var nx := int(floor((size.x - 0.3) / CELL))
	var nz := int(floor((size.z - 0.3) / CELL))
	var ox := -nx * CELL * 0.5 + CELL * 0.5
	var oz := -nz * CELL * 0.5 + CELL * 0.5
	for ix in nx:
		for iz in nz:
			var c := Vector3(ox + ix * CELL, 0.0, oz + iz * CELL)
			var cell_box := AABB(Vector3(c.x - CELL * 0.5 + 0.01, 0, c.z - CELL * 0.5 + 0.01), Vector3(CELL - 0.02, 0.5, CELL - 0.02))
			var bad := false
			for b in blockers:
				if b.grow(0.02).intersects(cell_box):
					bad = true
					break
			if not bad:
				for z in drawer_zones:
					if z.intersects(cell_box):
						bad = true
						break
			if not bad:
				for vp in L.viewpoints:
					if Vector2(c.x, c.z).distance_to(vp) < VIEWPOINT_CLEAR:
						bad = true
						break
			if bad:
				continue
			cells.append({"pos": c, "surface": false, "grid": Vector2i(ix, iz)})
	# Celdas sobre superficies de muebles.
	for fi in L.furniture.size():
		var f: Dictionary = L.furniture[fi]
		if not f.get("surface", false):
			continue
		var fs: Vector3 = f.size
		var sx := int(floor((fs.x - 0.04) / CELL))
		var sz := int(floor((fs.z - 0.04) / CELL))
		for ix in sx:
			for iz in sz:
				var c := Vector3(f.pos.x - sx * CELL * 0.5 + CELL * (ix + 0.5), fs.y, f.pos.y - sz * CELL * 0.5 + CELL * (iz + 0.5))
				cells.append({"pos": c, "surface": true, "furniture": fi, "grid": Vector2i(-1000 - fi * 10 - ix, iz)})

	# Visibilidad de cada celda desde los puntos de observación.
	var visible_cells := []
	for c in cells:
		var vps := []
		for vi in L.viewpoints.size():
			var target: Vector3 = c.pos + Vector3(0, 0.04, 0)
			if segment_clear(eye(L.viewpoints[vi]), target, blockers, c.get("furniture", -1), L.furniture):
				vps.append(vi)
		if not vps.is_empty():
			c["vps"] = vps
			visible_cells.append(c)

	for d in drawers:
		var vps := []
		for vi in L.viewpoints.size():
			var target: Vector3 = d.front + d.normal * 0.05
			if segment_clear(eye(L.viewpoints[vi]), target, blockers, -1, L.furniture):
				vps.append(vi)
		d["vps"] = vps

	var covers := []
	for c in L.covers:
		var vps := []
		for vi in L.viewpoints.size():
			var top := Vector3(c.pos.x, c.size.y + 0.02, c.pos.y)
			var others: Array[AABB] = []
			for b in blockers:
				if not b.is_equal_approx(cover_aabb(c)):
					others.append(b)
			if segment_clear(eye(L.viewpoints[vi]), top, others, -1, L.furniture):
				vps.append(vi)
		covers.append({"pos": Vector3(c.pos.x, 0, c.pos.y), "size": c.size, "type": c.type, "vps": vps})

	return {"cells": visible_cells, "drawers": drawers, "covers": covers, "blockers": blockers}


## true si el segmento a→b no atraviesa ningún bloqueador (salvo el mueble
## de soporte `support`, sobre cuya tapa está el objetivo).
static func segment_clear(a: Vector3, b: Vector3, blockers: Array[AABB], support: int, furniture: Array) -> bool:
	if a.distance_to(b) > MAX_VIEW_DIST:
		return false
	var support_box := AABB()
	if support >= 0:
		support_box = furniture_aabb(furniture[support])
	for box in blockers:
		if support >= 0 and box.is_equal_approx(support_box):
			continue
		var shrunk := box.grow(-0.01)
		if shrunk.intersects_segment(a, b) != null:
			return false
	return true
