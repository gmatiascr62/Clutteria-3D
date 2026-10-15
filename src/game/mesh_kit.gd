class_name MeshKit
extends RefCounted
## Construcción procedural de mallas (assets originales del proyecto).
## Combina primitivas transformadas con colores por vértice en un único
## ArrayMesh, para que cada objeto sea una sola llamada de dibujo.

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()

static var _trash_cache: Dictionary = {}
static var _trash_material: StandardMaterial3D


func add(mesh: PrimitiveMesh, xf: Transform3D, color: Color) -> void:
	var arr := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var base := _v.size()
	var nb := xf.basis.inverse().transposed()
	for k in verts.size():
		_v.append(xf * verts[k])
		_n.append((nb * norms[k]).normalized())
		_c.append(color)
	for k in idx:
		_i.append(base + k)


func commit(scale := 1.0) -> ArrayMesh:
	if not is_equal_approx(scale, 1.0):
		for i in _v.size():
			_v[i] *= scale
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_INDEX] = _i
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


# --- Primitivas ---------------------------------------------------------

func box(size: Vector3, center: Vector3, color: Color, basis := Basis()) -> void:
	var b := BoxMesh.new()
	b.size = size
	add(b, Transform3D(basis, center), color)


func cyl(r_top: float, r_bot: float, h: float, center: Vector3, color: Color, basis := Basis(), seg := 14) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	add(c, Transform3D(basis, center), color)


func sphere(r: float, center: Vector3, color: Color, scale := Vector3.ONE, seg := 12) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	add(s, Transform3D(Basis().scaled(scale), center), color)


func torus(inner: float, outer: float, center: Vector3, color: Color, basis := Basis()) -> void:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 12
	t.ring_segments = 8
	add(t, Transform3D(basis, center), color)


func prism(size: Vector3, center: Vector3, color: Color, basis := Basis()) -> void:
	var p := PrismMesh.new()
	p.size = size
	add(p, Transform3D(basis, center), color)


static func hex(s: String) -> Color:
	return Color.html(s)


static var ROT_Z90 := Basis(Vector3(0, 0, 1), PI / 2)
static var ROT_X90 := Basis(Vector3(1, 0, 0), PI / 2)


# --- Basura -------------------------------------------------------------

static func trash_material() -> StandardMaterial3D:
	if _trash_material == null:
		_trash_material = StandardMaterial3D.new()
		_trash_material.vertex_color_use_as_albedo = true
		_trash_material.roughness = 0.55
		_trash_material.metallic_specular = 0.4
	return _trash_material


static func trash_mesh(variant_id: String) -> ArrayMesh:
	if _trash_cache.has(variant_id):
		return _trash_cache[variant_id]
	var v := TrashCatalog.variant(variant_id)
	var k := MeshKit.new()
	var col := hex(v.color)
	var acc := hex(v.accent)
	k._build_shape(v.shape, col, acc)
	var mesh := k.commit(v.scale * TrashCatalog.WORLD_SCALE)
	_trash_cache[variant_id] = mesh
	return mesh


func _build_shape(shape: String, col: Color, acc: Color) -> void:
	var dark := col.darkened(0.35)
	var metal := Color(0.75, 0.75, 0.78)
	match shape:
		"bottle":
			cyl(0.04, 0.04, 0.17, Vector3(-0.035, 0.04, 0), col, ROT_Z90)
			cyl(0.0415, 0.0415, 0.075, Vector3(-0.04, 0.04, 0), acc, ROT_Z90)
			cyl(0.016, 0.04, 0.04, Vector3(0.07, 0.04, 0), col, ROT_Z90)
			cyl(0.016, 0.016, 0.04, Vector3(0.105, 0.04, 0), col, ROT_Z90)
			cyl(0.018, 0.018, 0.016, Vector3(0.127, 0.04, 0), dark, ROT_Z90)
		"flask":
			var sq := Basis().scaled(Vector3(1, 1, 0.65))
			cyl(0.045, 0.05, 0.13, Vector3(0, 0.065, 0), col, sq)
			box(Vector3(0.06, 0.06, 0.004), Vector3(0, 0.065, 0.033), acc)
			cyl(0.018, 0.02, 0.04, Vector3(0, 0.15, 0), acc.darkened(0.1))
		"can":
			cyl(0.035, 0.035, 0.12, Vector3(0, 0.06, 0), col)
			cyl(0.0355, 0.0355, 0.035, Vector3(0, 0.06, 0), acc)
			cyl(0.03, 0.035, 0.006, Vector3(0, 0.122, 0), metal)
		"plate":
			cyl(0.11, 0.08, 0.018, Vector3(0, 0.009, 0), acc)
			cyl(0.088, 0.07, 0.02, Vector3(0, 0.012, 0), col)
		"mug":
			cyl(0.045, 0.042, 0.1, Vector3(-0.012, 0.05, 0), col)
			cyl(0.039, 0.039, 0.004, Vector3(-0.012, 0.099, 0), col.darkened(0.5))
			torus(0.018, 0.03, Vector3(0.04, 0.05, 0), acc, ROT_X90)
		"carton":
			box(Vector3(0.09, 0.15, 0.09), Vector3(0, 0.075, 0), col)
			box(Vector3(0.092, 0.045, 0.092), Vector3(0, 0.08, 0), acc)
			prism(Vector3(0.09, 0.04, 0.09), Vector3(0, 0.17, 0), col)
		"jar":
			cyl(0.045, 0.045, 0.1, Vector3(0, 0.05, 0), col)
			cyl(0.047, 0.047, 0.022, Vector3(0, 0.109, 0), acc)
		"bowl":
			cyl(0.075, 0.045, 0.07, Vector3(0, 0.035, 0), col)
			cyl(0.066, 0.06, 0.004, Vector3(0, 0.069, 0), acc)
		"soap":
			box(Vector3(0.1, 0.035, 0.06), Vector3(0, 0.0175, 0), col)
			box(Vector3(0.05, 0.006, 0.03), Vector3(0, 0.037, 0), acc)
		"tube":
			cyl(0.02, 0.022, 0.13, Vector3(-0.015, 0.02, 0), col, ROT_Z90.scaled(Vector3(1, 0.8, 1)))
			box(Vector3(0.012, 0.03, 0.044), Vector3(-0.083, 0.02, 0), col.darkened(0.08))
			cyl(0.014, 0.014, 0.035, Vector3(0.068, 0.02, 0), acc, ROT_Z90)
		"roll":
			cyl(0.055, 0.055, 0.105, Vector3(0, 0.0525, 0), col)
			cyl(0.02, 0.02, 0.107, Vector3(0, 0.0535, 0), acc)
		"brush":
			box(Vector3(0.15, 0.016, 0.02), Vector3(-0.02, 0.008, 0), col)
			box(Vector3(0.035, 0.024, 0.022), Vector3(0.07, 0.015, 0), acc)
		"cloth":
			box(Vector3(0.22, 0.035, 0.19), Vector3(0, 0.0175, 0), col)
			box(Vector3(0.18, 0.012, 0.16), Vector3(0.0, 0.041, 0), col.lightened(0.05))
			box(Vector3(0.221, 0.006, 0.03), Vector3(0, 0.0475, 0), acc)
		"sock":
			box(Vector3(0.13, 0.03, 0.06), Vector3(-0.02, 0.015, 0), col)
			sphere(0.035, Vector3(0.055, 0.02, 0), col, Vector3(1.2, 0.6, 0.9))
			box(Vector3(0.04, 0.034, 0.064), Vector3(-0.07, 0.017, 0), acc)
		"shoe":
			box(Vector3(0.26, 0.025, 0.1), Vector3(0, 0.0125, 0), acc)
			box(Vector3(0.17, 0.065, 0.09), Vector3(-0.035, 0.057, 0), col)
			sphere(0.05, Vector3(0.07, 0.045, 0), col, Vector3(1.3, 0.75, 0.9))
			box(Vector3(0.06, 0.004, 0.05), Vector3(-0.03, 0.091, 0), acc)
		"ball":
			sphere(0.065, Vector3(0, 0.065, 0), col)
			torus(0.062, 0.067, Vector3(0, 0.065, 0), acc, ROT_X90)
		"block":
			box(Vector3(0.08, 0.08, 0.08), Vector3(0, 0.04, 0), col)
			box(Vector3(0.04, 0.04, 0.004), Vector3(0, 0.04, 0.041), acc)
			box(Vector3(0.004, 0.04, 0.04), Vector3(0.041, 0.04, 0), acc)
			box(Vector3(0.04, 0.004, 0.04), Vector3(0, 0.081, 0), acc)
		"book":
			box(Vector3(0.18, 0.006, 0.13), Vector3(0, 0.003, 0), col)
			box(Vector3(0.17, 0.03, 0.122), Vector3(0.004, 0.021, 0), acc)
			box(Vector3(0.18, 0.006, 0.13), Vector3(0, 0.039, 0), col)
			box(Vector3(0.008, 0.042, 0.13), Vector3(-0.088, 0.021, 0), col.darkened(0.15))
		"teddy":
			sphere(0.05, Vector3(0, 0.05, 0), col, Vector3(1, 1, 0.9))
			sphere(0.04, Vector3(0, 0.125, 0), col)
			sphere(0.014, Vector3(-0.03, 0.158, 0), col)
			sphere(0.014, Vector3(0.03, 0.158, 0), col)
			sphere(0.016, Vector3(0, 0.12, 0.035), acc)
			sphere(0.02, Vector3(-0.045, 0.02, 0.03), col)
			sphere(0.02, Vector3(0.045, 0.02, 0.03), col)
		"magazine":
			box(Vector3(0.21, 0.012, 0.15), Vector3(0, 0.006, 0), col)
			box(Vector3(0.012, 0.0125, 0.15), Vector3(-0.099, 0.0064, 0), acc)
			box(Vector3(0.12, 0.002, 0.05), Vector3(0.02, 0.0125, 0.03), Color(0.95, 0.95, 0.95))
		"remote":
			box(Vector3(0.17, 0.02, 0.05), Vector3(0, 0.01, 0), col)
			box(Vector3(0.02, 0.006, 0.02), Vector3(0.06, 0.022, 0), acc)
			for i in 3:
				box(Vector3(0.012, 0.004, 0.012), Vector3(-0.01 - i * 0.025, 0.021, 0), Color(0.5, 0.5, 0.5))
		"pizza":
			box(Vector3(0.24, 0.04, 0.24), Vector3(0, 0.02, 0), col)
			cyl(0.05, 0.05, 0.003, Vector3(0, 0.041, 0), acc)
		"cup":
			cyl(0.04, 0.03, 0.11, Vector3(0, 0.055, 0), col)
			cyl(0.041, 0.041, 0.012, Vector3(0, 0.104, 0), acc)
		"bag":
			sphere(0.07, Vector3(0, 0.055, 0), col, Vector3(1.1, 0.8, 1.0), 8)
			sphere(0.03, Vector3(0.02, 0.1, 0.01), col.darkened(0.08), Vector3.ONE, 6)
			sphere(0.018, Vector3(0.0, 0.115, -0.01), acc, Vector3.ONE, 6)
		"box":
			box(Vector3(0.18, 0.12, 0.14), Vector3(0, 0.06, 0), col)
			box(Vector3(0.182, 0.004, 0.04), Vector3(0, 0.121, 0), acc)
		"paint":
			cyl(0.07, 0.07, 0.14, Vector3(0, 0.07, 0), col)
			cyl(0.071, 0.071, 0.06, Vector3(0, 0.07, 0), acc)
			cyl(0.066, 0.066, 0.01, Vector3(0, 0.145, 0), acc.darkened(0.2))
		"glove":
			box(Vector3(0.11, 0.025, 0.09), Vector3(-0.02, 0.0125, 0), col)
			for i in 4:
				box(Vector3(0.06, 0.018, 0.016), Vector3(0.06, 0.009, -0.03 + i * 0.02), col)
			box(Vector3(0.025, 0.018, 0.016), Vector3(0.0, 0.009, 0.05), col)
			box(Vector3(0.04, 0.03, 0.094), Vector3(-0.08, 0.015, 0), acc)
		_:
			box(Vector3(0.1, 0.1, 0.1), Vector3(0, 0.05, 0), col)


static func mystery_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var s := LevelGenerator.MYSTERY_SIZE
	k.box(s, Vector3(0, s.y * 0.5, 0), Color(0.45, 0.2, 0.7))
	k.box(Vector3(s.x + 0.004, s.y + 0.004, 0.03), Vector3(0, s.y * 0.5, 0), Color(1.0, 0.8, 0.2))
	k.box(Vector3(0.03, s.y + 0.004, s.z + 0.004), Vector3(0, s.y * 0.5, 0), Color(1.0, 0.8, 0.2))
	k.torus(0.012, 0.03, Vector3(-0.025, s.y + 0.01, 0), Color(1.0, 0.8, 0.2), Basis(Vector3(0, 0, 1), 0.6))
	k.torus(0.012, 0.03, Vector3(0.025, s.y + 0.01, 0), Color(1.0, 0.8, 0.2), Basis(Vector3(0, 0, 1), -0.6))
	return k.commit()


static func key_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var gold := Color(1.0, 0.78, 0.15)
	k.torus(0.014, 0.03, Vector3(-0.045, 0.012, 0), gold)
	k.box(Vector3(0.08, 0.012, 0.014), Vector3(0.02, 0.012, 0), gold)
	k.box(Vector3(0.012, 0.012, 0.02), Vector3(0.05, 0.012, 0.012), gold)
	k.box(Vector3(0.012, 0.012, 0.016), Vector3(0.035, 0.012, 0.01), gold)
	return k.commit()


static func marker_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	k.prism(Vector3(0.09, 0.09, 0.04), Vector3(0, 0.0, 0), Color(1.0, 0.85, 0.2), Basis(Vector3(1, 0, 0), PI))
	return k.commit()


# --- Muebles ------------------------------------------------------------

## Malla de un mueble en coordenadas locales (base centrada en el origen).
## `style` 0 = original, 1 = nuevo (reemplazo).
static func furniture_mesh(f: Dictionary, style: int) -> ArrayMesh:
	var k := MeshKit.new()
	var s: Vector3 = f.size
	var col := hex(f.color)
	var acc := hex(f.get("accent", "#dddddd"))
	if style == 1:
		col = _modern_color(f.type)
		acc = col.lightened(0.35)
	var leg := col.darkened(0.25)
	match f.type:
		"bed":
			k.box(Vector3(s.x, 0.25, s.z), Vector3(0, 0.125, 0), col)
			k.box(Vector3(s.x - 0.06, 0.2, s.z - 0.08), Vector3(0, 0.35, 0.02), Color(0.93, 0.92, 0.88))
			k.box(Vector3(s.x - 0.04, 0.05, s.z * 0.6), Vector3(0, 0.47, s.z * 0.18), acc)
			k.box(Vector3(s.x * 0.7, 0.07, 0.3), Vector3(0, 0.485, -s.z * 0.5 + 0.22), Color(0.97, 0.97, 0.95))
			k.box(Vector3(s.x, 0.85, 0.06), Vector3(0, 0.425, -s.z * 0.5 + 0.03), col.darkened(0.1))
		"table":
			k.box(Vector3(s.x, 0.04, s.z), Vector3(0, s.y - 0.02, 0), col)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					k.box(Vector3(0.05, s.y - 0.04, 0.05), Vector3(sx * (s.x * 0.5 - 0.05), (s.y - 0.04) * 0.5, sz * (s.z * 0.5 - 0.05)), leg)
		"counter":
			k.box(Vector3(s.x, s.y - 0.04, s.z - 0.02), Vector3(0, (s.y - 0.04) * 0.5, -0.01), col)
			k.box(Vector3(s.x + 0.02, 0.04, s.z + 0.02), Vector3(0, s.y - 0.02, 0), acc)
		"dresser", "chest":
			k.box(Vector3(s.x, s.y, s.z), Vector3(0, s.y * 0.5, 0), col)
			k.box(Vector3(s.x + 0.02, 0.03, s.z + 0.02), Vector3(0, s.y - 0.015, 0), col.darkened(0.15))
			if f.type == "chest":
				k.box(Vector3(s.x + 0.01, 0.04, s.z + 0.01), Vector3(0, s.y * 0.75, 0), acc)
		"armchair":
			k.box(Vector3(s.x, 0.4, s.z), Vector3(0, 0.2, 0), col)
			k.box(Vector3(s.x, s.y - 0.4, 0.18), Vector3(0, 0.4 + (s.y - 0.4) * 0.5, -s.z * 0.5 + 0.09), col.darkened(0.08))
			for sx in [-1, 1]:
				k.box(Vector3(0.14, 0.22, s.z), Vector3(sx * (s.x * 0.5 - 0.07), 0.51, 0), col.darkened(0.12))
			k.box(Vector3(s.x - 0.3, 0.08, s.z - 0.25), Vector3(0, 0.44, 0.06), col.lightened(0.1))
		"sofa":
			k.box(Vector3(s.x, 0.42, s.z), Vector3(0, 0.21, 0), col)
			k.box(Vector3(s.x, s.y - 0.42, 0.2), Vector3(0, 0.42 + (s.y - 0.42) * 0.5, -s.z * 0.5 + 0.1), col.darkened(0.08))
			for sx in [-1, 1]:
				k.box(Vector3(0.16, 0.2, s.z), Vector3(sx * (s.x * 0.5 - 0.08), 0.52, 0), col.darkened(0.12))
			for i in 3:
				k.box(Vector3((s.x - 0.36) / 3.0 - 0.02, 0.09, s.z - 0.25), Vector3(-s.x * 0.5 + 0.18 + (s.x - 0.36) / 3.0 * (i + 0.5), 0.465, 0.07), col.lightened(0.08))
		"shelf":
			k.box(Vector3(s.x, s.y, 0.03), Vector3(0, s.y * 0.5, 0), col)
			k.box(Vector3(s.x, s.y, s.z), Vector3(0, s.y * 0.5, 0), col.darkened(0.25))
			var n := 4
			for i in n:
				var y := 0.05 + i * (s.y - 0.1) / (n - 1)
				for j in 6:
					var bw := 0.04 + fmod(j * 0.37, 0.03)
					var bcol := Color.from_hsv(fmod(j * 0.17 + i * 0.31, 1.0), 0.45, 0.6)
					k.box(Vector3(s.x * 0.7, 0.22, bw), Vector3(0.0, y + 0.13, -s.z * 0.5 + 0.1 + j * (s.z - 0.2) / 6.0), bcol)
				k.box(Vector3(s.x + 0.01, 0.025, s.z + 0.01), Vector3(0, y, 0), col)
		"bathtub":
			k.box(Vector3(s.x, s.y, s.z), Vector3(0, s.y * 0.5, 0), col)
			k.box(Vector3(s.x - 0.12, 0.02, s.z - 0.12), Vector3(0, s.y + 0.001, 0), acc)
			k.cyl(0.015, 0.015, 0.15, Vector3(-s.x * 0.5 + 0.08, s.y + 0.07, 0), Color(0.8, 0.8, 0.82))
		"toilet":
			k.box(Vector3(s.x, 0.4, s.z * 0.6), Vector3(0, 0.2, 0.08), col)
			k.cyl(0.2, 0.18, 0.06, Vector3(0, 0.42, 0.1), col)
			k.box(Vector3(s.x, s.y - 0.35, 0.18), Vector3(0, 0.35 + (s.y - 0.35) * 0.5, -s.z * 0.5 + 0.09), col)
		"fridge":
			k.box(Vector3(s.x, s.y, s.z), Vector3(0, s.y * 0.5, 0), col)
			k.box(Vector3(s.x + 0.005, 0.01, s.z + 0.005), Vector3(0, s.y * 0.62, 0), col.darkened(0.25))
			k.box(Vector3(0.03, 0.4, 0.03), Vector3(s.x * 0.35, s.y * 0.8, s.z * 0.5 + 0.02), Color(0.6, 0.6, 0.62))
			k.box(Vector3(0.03, 0.5, 0.03), Vector3(s.x * 0.35, s.y * 0.35, s.z * 0.5 + 0.02), Color(0.6, 0.6, 0.62))
		"wardrobe":
			k.box(Vector3(s.x, s.y, s.z), Vector3(0, s.y * 0.5, 0), col)
			k.box(Vector3(0.01, s.y - 0.1, 0.01), Vector3(0, s.y * 0.5, s.z * 0.5 + 0.004), col.darkened(0.4))
			for sx in [-1, 1]:
				k.box(Vector3(0.025, 0.25, 0.03), Vector3(sx * 0.06, s.y * 0.5, s.z * 0.5 + 0.02), Color(0.75, 0.65, 0.4))
		_:
			k.box(s, Vector3(0, s.y * 0.5, 0), col)
	return k.commit()


static func _modern_color(t: String) -> Color:
	match t:
		"bed": return Color(0.85, 0.85, 0.82)
		"sofa", "armchair": return Color(0.35, 0.55, 0.62)
		"table": return Color(0.78, 0.66, 0.5)
		"counter": return Color(0.9, 0.9, 0.88)
		"fridge": return Color(0.8, 0.82, 0.85)
		"bathtub", "toilet": return Color(0.98, 0.98, 0.98)
		"shelf": return Color(0.72, 0.6, 0.45)
	return Color(0.82, 0.72, 0.58)


## Frente de cajón con caja interior (abierta arriba). Origen en el frente.
static func drawer_mesh(w: float, h: float, depth: float, color: Color) -> ArrayMesh:
	var k := MeshKit.new()
	var inner := color.darkened(0.35)
	k.box(Vector3(w, h, 0.02), Vector3(0, 0, 0.01), color)
	k.box(Vector3(w - 0.04, 0.012, depth), Vector3(0, -h * 0.5 + 0.01, -depth * 0.5), inner)
	k.box(Vector3(0.012, h * 0.8, depth), Vector3(-w * 0.5 + 0.026, -h * 0.1, -depth * 0.5), inner)
	k.box(Vector3(0.012, h * 0.8, depth), Vector3(w * 0.5 - 0.026, -h * 0.1, -depth * 0.5), inner)
	k.box(Vector3(w - 0.04, h * 0.8, 0.012), Vector3(0, -h * 0.1, -depth), inner)
	k.box(Vector3(minf(0.12, w * 0.4), 0.02, 0.025), Vector3(0, 0, 0.032), Color(0.85, 0.7, 0.3))
	return k.commit()


static func cover_mesh(type: String, size: Vector3) -> ArrayMesh:
	var k := MeshKit.new()
	match type:
		"box":
			var c := Color(0.69, 0.52, 0.36)
			k.box(size, Vector3(0, size.y * 0.5, 0), c)
			k.box(Vector3(size.x + 0.004, 0.01, 0.07), Vector3(0, size.y, 0), Color(0.85, 0.8, 0.6))
			k.box(Vector3(size.x * 0.5, 0.012, size.z * 0.5), Vector3(-size.x * 0.25, size.y + 0.005, -size.z * 0.25), c.lightened(0.08), Basis(Vector3(0, 0, 1), 0.08))
		"basket":
			k.cyl(size.x * 0.5, size.x * 0.42, size.y, Vector3(0, size.y * 0.5, 0), Color(0.78, 0.65, 0.42), Basis(), 10)
			k.cyl(size.x * 0.52, size.x * 0.52, 0.04, Vector3(0, size.y - 0.02, 0), Color(0.68, 0.55, 0.34), Basis(), 10)
		"cushion":
			k.box(size, Vector3(0, size.y * 0.5, 0), Color(0.75, 0.35, 0.35))
			k.box(Vector3(size.x * 0.95, size.y * 0.3, size.z * 0.95), Vector3(0, size.y * 0.9, 0), Color(0.82, 0.42, 0.42))
		_:
			k.box(size, Vector3(0, size.y * 0.5, 0), Color(0.6, 0.6, 0.6))
	return k.commit()
