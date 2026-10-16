class_name RoomView
extends Node3D
## Representación 3D de una habitación: cáscara, muebles, cajones, tapas,
## manchas, marcadores de puntos de observación y piezas de basura.

const LAYER_WORLD := 1
const LAYER_INTERACT := 2
const LAYER_STAIN := 4
## Frente de un cajón abierto: se puede tocar para cerrarlo, pero no tapa la
## línea de visión hacia lo que hay adentro (no está en las máscaras de LOS).
const LAYER_CLOSE := 8

const WORN_TINT := Color(0.62, 0.57, 0.5)
const MASK_RES := 48

var layout_id: String
var L: Dictionary
var geo: Dictionary
var level: Dictionary

var wall_material: ShaderMaterial
var floor_material: ShaderMaterial
var furniture_nodes: Array = [] # {node, mesh, material, body}
var drawer_nodes: Array = [] # por índice de LayoutGeometry.drawers
var cover_nodes: Array = [] # por índice de LayoutGeometry.covers
var container_of_drawer: Dictionary = {} # ref -> índice de contenedor
var container_of_cover: Dictionary = {}
var piece_nodes: Array = []
var stain_nodes: Array = [] # {node, image, texture, total, dirty_px}
var marker_nodes: Array = []
var _hint_markers: Dictionary = {} # contenedor -> nodo marcador
var _fixed: Dictionary = {} # arreglos de la restauración ya hechos
var _fixture_nodes: Dictionary = {} # nombre -> {body, ...}
var lamp_light: OmniLight3D
var bulb_material: StandardMaterial3D
var _flicker: Tween
var _debris: Array[MultiMeshInstance3D] = []
var _session: RoomSession
static var _covered_overlay: StandardMaterial3D
## Label3D genera errores espurios con el renderer "dummy" (modo headless).
var _labels_3d := DisplayServer.get_name() != "headless"


func build(p_level: Dictionary, restore: Dictionary) -> void:
	level = p_level
	layout_id = level.layout
	L = PropertyCatalog.LAYOUTS[layout_id]
	geo = LayoutGeometry.get_geometry(layout_id)
	_fixed = restore.get("fixtures", {}).duplicate()
	_build_environment()
	_build_shell(restore)
	_build_furniture(restore)
	_build_containers()
	_build_stains(restore)
	_build_markers()
	_build_pieces()
	_build_debris()
	_build_mounds()


# --- Ambiente y cáscara -----------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.8, 0.76)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.55
	sun.light_color = Color(1.0, 0.96, 0.9)
	add_child(sun)
	var lamp := OmniLight3D.new()
	var size: Vector3 = L.size
	lamp.position = Vector3(0, size.y - 0.35, 0)
	lamp.omni_range = maxf(size.x, size.z) * 1.1
	lamp.light_energy = 1.25
	lamp.light_color = Color(1.0, 0.92, 0.8)
	lamp.omni_attenuation = 0.8
	add_child(lamp)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.18
	bulb.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.9, 0.7)
	bm.emission_energy_multiplier = 2.0
	bm.albedo_color = Color(1, 0.95, 0.85)
	bulb.material_override = bm
	bulb.position = Vector3(0, size.y - 0.1, 0)
	add_child(bulb)
	lamp_light = lamp
	bulb_material = bm
	if "lamp" in L.get("fixtures", []):
		var body := _static_box(self, Vector3(0.4, 0.3, 0.4), bulb.position, LAYER_WORLD)
		body.set_meta("fixture", "lamp")
		_fixture_nodes["lamp"] = {"body": body}
		if not _fixed.get("lamp", false):
			_start_flicker()


func _static_box(parent: Node3D, size: Vector3, center: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center
	body.add_child(cs)
	parent.add_child(body)
	return body


func _build_shell(restore: Dictionary) -> void:
	var size: Vector3 = L.size
	# Piso
	floor_material = ShaderMaterial.new()
	floor_material.shader = load("res://src/game/shaders/floor.gdshader")
	floor_material.set_shader_parameter("base_color", Color.html(L.floor_color))
	floor_material.set_shader_parameter("pattern", 0 if L.floor == "wood" else 1)
	floor_material.set_shader_parameter("dirt", 1.0 - float(restore.get("clean", 0.0)))
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	floor_mi.mesh = pm
	floor_mi.material_override = floor_material
	add_child(floor_mi)
	_static_box(self, Vector3(size.x, 0.1, size.z), Vector3(0, -0.05, 0), LAYER_WORLD)
	# Techo
	var ceil_mi := MeshInstance3D.new()
	var cm := PlaneMesh.new()
	cm.size = Vector2(size.x, size.z)
	cm.flip_faces = true
	ceil_mi.mesh = cm
	ceil_mi.position.y = size.y
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.93, 0.92, 0.9)
	ceil_mi.material_override = cmat
	add_child(ceil_mi)
	# Paredes
	wall_material = ShaderMaterial.new()
	wall_material.shader = load("res://src/game/shaders/wall.gdshader")
	var wall_col := Color.html(L.wall_color)
	if restore.has("paint"):
		wall_col = Color.html(Balance.paint_by_id(restore.paint).color)
		wall_material.set_shader_parameter("dirt", 0.0)
	else:
		wall_material.set_shader_parameter("dirt", 1.0 - float(restore.get("clean", 0.0)) * 0.3)
	wall_material.set_shader_parameter("old_color", wall_col)
	wall_material.set_shader_parameter("new_color", wall_col)
	wall_material.set_shader_parameter("progress", 0.0)
	wall_material.set_shader_parameter("height", size.y)
	var t := 0.1
	var walls := {
		"north": [Vector3(size.x + 2 * t, size.y, t), Vector3(0, size.y * 0.5, -size.z * 0.5 - t * 0.5)],
		"south": [Vector3(size.x + 2 * t, size.y, t), Vector3(0, size.y * 0.5, size.z * 0.5 + t * 0.5)],
		"west": [Vector3(t, size.y, size.z), Vector3(-size.x * 0.5 - t * 0.5, size.y * 0.5, 0)],
		"east": [Vector3(t, size.y, size.z), Vector3(size.x * 0.5 + t * 0.5, size.y * 0.5, 0)],
	}
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.42, 0.33, 0.25)
	for w in walls:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = walls[w][0]
		mi.mesh = bm
		mi.position = walls[w][1]
		mi.material_override = wall_material
		add_child(mi)
		_static_box(self, walls[w][0], walls[w][1], LAYER_WORLD)
		# Zócalo
		var base := MeshInstance3D.new()
		var bb := BoxMesh.new()
		var bs: Vector3 = walls[w][0]
		bb.size = Vector3(bs.x, 0.08, bs.z) + (Vector3(0.0, 0, 0.03) if w in ["north", "south"] else Vector3(0.03, 0, 0))
		base.mesh = bb
		base.position = Vector3(walls[w][1].x, 0.04, walls[w][1].z)
		base.material_override = trim
		add_child(base)
	_build_window()
	_build_door()


func _wall_frame(wall: String) -> Transform3D:
	# Transform cuyo +Z apunta hacia el interior, sobre la superficie de la pared.
	var size: Vector3 = L.size
	match wall:
		"north": return Transform3D(Basis(), Vector3(0, 0, -size.z * 0.5))
		"south": return Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, size.z * 0.5))
		"west": return Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-size.x * 0.5, 0, 0))
		"east": return Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(size.x * 0.5, 0, 0))
	return Transform3D()


func _build_window() -> void:
	var w: Dictionary = L.window
	var fr := _wall_frame(w.wall)
	var holder := Node3D.new()
	holder.transform = fr
	add_child(holder)
	var glass := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = w.size
	glass.mesh = qm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.7, 0.85, 1.0)
	gm.emission_enabled = true
	gm.emission = Color(0.65, 0.82, 1.0)
	gm.emission_energy_multiplier = 1.2
	glass.material_override = gm
	glass.position = Vector3(w.pos.x, w.pos.y, 0.006)
	holder.add_child(glass)
	if "window" in L.get("fixtures", []):
		var crack := MeshInstance3D.new()
		var cq := QuadMesh.new()
		cq.size = w.size
		crack.mesh = cq
		var cm := ShaderMaterial.new()
		cm.shader = load("res://src/game/shaders/crack.gdshader")
		crack.material_override = cm
		crack.position = Vector3(w.pos.x, w.pos.y, 0.012)
		crack.visible = not _fixed.get("window", false)
		holder.add_child(crack)
		var body := _static_box(holder, Vector3(w.size.x, w.size.y, 0.04), Vector3(w.pos.x, w.pos.y, 0.03), LAYER_WORLD)
		body.set_meta("fixture", "window")
		_fixture_nodes["window"] = {"body": body, "crack": crack, "glass": glass}
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.95, 0.94, 0.9)
	for spec in [[Vector3(w.size.x + 0.1, 0.06, 0.05), Vector3(0, w.size.y * 0.5, 0)], [Vector3(w.size.x + 0.1, 0.06, 0.05), Vector3(0, -w.size.y * 0.5, 0)],
			[Vector3(0.06, w.size.y, 0.05), Vector3(w.size.x * 0.5, 0, 0)], [Vector3(0.06, w.size.y, 0.05), Vector3(-w.size.x * 0.5, 0, 0)],
			[Vector3(0.03, w.size.y, 0.03), Vector3(0, 0, 0)], [Vector3(w.size.x + 0.2, 0.04, 0.12), Vector3(0, -w.size.y * 0.5 - 0.04, 0.04)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[0]
		mi.mesh = bm
		mi.material_override = fm
		mi.position = Vector3(w.pos.x, w.pos.y, 0.02) + spec[1]
		holder.add_child(mi)
	var light := OmniLight3D.new()
	light.position = Vector3(w.pos.x, w.pos.y, 0.8)
	light.light_color = Color(0.75, 0.85, 1.0)
	light.light_energy = 0.6
	light.omni_range = 3.0
	holder.add_child(light)


func _build_door() -> void:
	var d: Dictionary = L.door
	var holder := Node3D.new()
	holder.transform = _wall_frame(d.wall)
	add_child(holder)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.55, 0.38, 0.25)
	var door := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.85, 2.05, 0.05)
	door.mesh = bm
	door.material_override = dm
	door.position = Vector3(d.pos, 1.025, 0.025)
	holder.add_child(door)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	knob.mesh = sm
	var km := StandardMaterial3D.new()
	km.albedo_color = Color(0.85, 0.7, 0.3)
	km.metallic = 0.8
	knob.material_override = km
	knob.position = Vector3(d.pos + 0.32, 1.0, 0.07)
	holder.add_child(knob)


# --- Muebles ------------------------------------------------------------------

func _build_furniture(restore: Dictionary) -> void:
	var states: Dictionary = restore.get("furniture", {})
	for fi in L.furniture.size():
		var f: Dictionary = L.furniture[fi]
		var node := Node3D.new()
		node.position = Vector3(f.pos.x, 0, f.pos.y)
		add_child(node)
		var mi := MeshInstance3D.new()
		var state: String = states.get(str(fi), "")
		mi.mesh = MeshKit.furniture_mesh(f, 1 if state == "replaced" else 0)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color.WHITE if state != "" else WORN_TINT
		mat.roughness = 0.6 if state != "" else 0.9
		mi.material_override = mat
		node.add_child(mi)
		var s: Vector3 = f.size
		var body := _static_box(node, s, Vector3(0, s.y * 0.5, 0), LAYER_WORLD)
		body.set_meta("furniture", fi)
		furniture_nodes.append({"node": node, "mesh": mi, "material": mat, "body": body, "def": f})


func set_furniture_state(fi: int, state: String, animate: bool) -> void:
	var fn: Dictionary = furniture_nodes[fi]
	var mat: StandardMaterial3D = fn.material
	if state == "replaced":
		fn.mesh.mesh = MeshKit.furniture_mesh(fn.def, 1)
	var target := Color.WHITE if state != "" else WORN_TINT
	if animate:
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(mat, "albedo_color", target, 0.8)
		tw.tween_property(mat, "roughness", 0.6, 0.8)
		var node: Node3D = fn.node
		node.scale = Vector3(0.94, 0.94, 0.94)
		tw.tween_property(node, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		mat.albedo_color = target


# --- Contenedores -------------------------------------------------------------

func _build_containers() -> void:
	for ci in level.containers.size():
		var c: Dictionary = level.containers[ci]
		if c.type == "drawer":
			container_of_drawer[int(c.ref)] = ci
		else:
			container_of_cover[int(c.ref)] = ci
	for di in geo.drawers.size():
		var d: Dictionary = geo.drawers[di]
		var node := Node3D.new()
		var normal: Vector3 = d.normal
		node.position = d.front
		node.basis = Basis.looking_at(-normal, Vector3.UP)
		add_child(node)
		var f: Dictionary = L.furniture[d.furniture]
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.drawer_mesh(d.width, d.height, d.depth, Color.html(f.color).lightened(0.05))
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = WORN_TINT.lightened(0.15)
		mi.material_override = mat
		node.add_child(mi)
		var ci: int = container_of_drawer.get(di, -1)
		var body := _static_box(node, Vector3(d.width, d.height, 0.04), Vector3(0, 0, 0.02), LAYER_INTERACT)
		body.set_meta("kind", "drawer")
		body.set_meta("drawer", di)
		body.set_meta("container", ci)
		var content := Node3D.new()
		# Cajón "desbordado": el contenido asoma por encima del frente para que
		# se vea al abrirlo, aun en muebles altos.
		content.position = Vector3(0, d.height * 0.5 - 0.05, -d.depth * 0.5)
		node.add_child(content)
		drawer_nodes.append({"node": node, "content": content, "body": body, "closed_pos": d.front, "def": d, "open": false})
		if ci >= 0:
			_add_hint_marker(ci, node, Vector3(0, d.height * 0.5 + 0.12, 0.05))
	for i in geo.covers.size():
		var cv: Dictionary = geo.covers[i]
		var node := Node3D.new()
		node.position = cv.pos
		add_child(node)
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.cover_mesh(cv.type, cv.size)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.85
		mi.material_override = mat
		node.add_child(mi)
		var ci: int = container_of_cover.get(i, -1)
		var body := _static_box(node, cv.size, Vector3(0, cv.size.y * 0.5, 0), LAYER_INTERACT if ci >= 0 else LAYER_WORLD)
		body.set_meta("kind", "cover")
		body.set_meta("cover", i)
		body.set_meta("container", ci)
		cover_nodes.append({"node": node, "body": body, "def": cv, "open": false})
		if ci >= 0:
			_add_hint_marker(ci, node, Vector3(0, cv.size.y + 0.15, 0))


## Rombo amarillo flotante: distingue lo explorable de la basura.
func _add_hint_marker(ci: int, parent: Node3D, offset: Vector3) -> void:
	var m := MeshInstance3D.new()
	m.mesh = MeshKit.marker_mesh()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.position = offset
	parent.add_child(m)
	var tw := m.create_tween().set_loops()
	tw.tween_property(m, "position:y", offset.y + 0.05, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(m, "position:y", offset.y, 0.6).set_trans(Tween.TRANS_SINE)
	_hint_markers[ci] = m


func open_container(ci: int, animate: bool) -> void:
	var c: Dictionary = level.containers[ci]
	if _hint_markers.has(ci):
		_hint_markers[ci].queue_free()
		_hint_markers.erase(ci)
	if c.type == "drawer":
		var dn: Dictionary = drawer_nodes[c.ref]
		if dn.open:
			return
		dn.open = true
		var target: Vector3 = dn.closed_pos + dn.def.normal * dn.def.depth * 0.85
		if animate:
			var tw := create_tween()
			tw.tween_property(dn.node, "position", target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			dn.node.position = target
		# El frente pasa a una capa propia: sirve para cerrar, pero no tapa el contenido.
		dn.body.collision_layer = LAYER_CLOSE
	else:
		var cn: Dictionary = cover_nodes[c.ref]
		if cn.open:
			return
		cn.open = true
		cn.body.collision_layer = 0
		if animate:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(cn.node, "position:y", 0.9, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(cn.node, "rotation:z", 0.6, 0.35)
			tw.chain().tween_property(cn.node, "scale", Vector3(0.01, 0.01, 0.01), 0.2)
			tw.chain().tween_callback(func(): cn.node.visible = false)
		else:
			cn.node.visible = false


## Cierra un cajón. `on_done` se llama al terminar la animación (para ocultar
## el contenido recién cuando el cajón quedó cerrado).
func close_container(ci: int, animate: bool, show_marker: bool, on_done := Callable()) -> void:
	var c: Dictionary = level.containers[ci]
	if c.type != "drawer":
		return
	var dn: Dictionary = drawer_nodes[c.ref]
	if not dn.open:
		return
	dn.open = false
	dn.body.collision_layer = LAYER_INTERACT
	if show_marker and not _hint_markers.has(ci):
		_add_hint_marker(ci, dn.node, Vector3(0, dn.def.height * 0.5 + 0.12, 0.05))
	if animate:
		var tw := create_tween()
		tw.tween_property(dn.node, "position", dn.closed_pos, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if on_done.is_valid():
			tw.tween_callback(on_done)
	else:
		dn.node.position = dn.closed_pos
		if on_done.is_valid():
			on_done.call()


# --- Arreglos de la restauración ---------------------------------------------

func _start_flicker() -> void:
	_flicker = create_tween().set_loops()
	var set_level := func(v: float):
		lamp_light.light_energy = 1.25 * v
		bulb_material.emission_energy_multiplier = 2.0 * v
	_flicker.tween_method(set_level, 1.0, 0.15, 0.05)
	_flicker.tween_method(set_level, 0.15, 0.9, 0.08)
	_flicker.tween_method(set_level, 0.9, 0.25, 0.05)
	_flicker.tween_method(set_level, 0.25, 0.85, 0.06)
	_flicker.tween_interval(1.6)
	_flicker.tween_method(set_level, 0.85, 0.3, 0.07)
	_flicker.tween_method(set_level, 0.3, 0.85, 0.1)
	_flicker.tween_interval(2.3)


func is_fixed(name: String) -> bool:
	return _fixed.get(name, false)


func fix_fixture(name: String, animate: bool) -> void:
	_fixed[name] = true
	match name:
		"lamp":
			if _flicker:
				_flicker.kill()
				_flicker = null
			lamp_light.light_energy = 1.35
			bulb_material.emission_energy_multiplier = 2.2
			if animate:
				var tw := create_tween()
				tw.tween_property(bulb_material, "emission_energy_multiplier", 5.0, 0.15)
				tw.tween_property(bulb_material, "emission_energy_multiplier", 2.2, 0.4)
		"window":
			var fn: Dictionary = _fixture_nodes.get("window", {})
			if fn.is_empty():
				return
			var crack: MeshInstance3D = fn.crack
			if animate:
				var tw := create_tween()
				tw.tween_property(crack, "scale", Vector3(1.05, 1.05, 1), 0.1)
				tw.tween_property(crack, "scale", Vector3(0.01, 0.01, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				tw.tween_callback(func(): crack.visible = false)
			else:
				crack.visible = false


## Brillo breve sobre un mueble (al elegirlo para restaurar).
func highlight_furniture(fi: int) -> void:
	var mi: MeshInstance3D = furniture_nodes[fi].mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.85, 0.3, 0.45)
	mi.material_overlay = m
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.9)
	tw.tween_callback(func(): mi.material_overlay = null)


# --- Basura decorativa -------------------------------------------------------

## Papeles, bolsas y manchas que no se recogen: hacen que la habitación se vea
## abarrotada. Son planos (no tapan objetos) y van desapareciendo a medida que
## se limpia. Se dibujan con MultiMesh (instancing).
func _build_debris() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level.seed) * 31 + 7
	var floor_cells := []
	for c in geo.cells:
		if not c.surface:
			floor_cells.append(c)
	if floor_cells.is_empty():
		return
	var kinds := [_debris_mesh("paper"), _debris_mesh("sheet"), _debris_mesh("bag"), _debris_mesh("dirt"), _debris_mesh("cardboard")]
	var total := clampi(60 + int(level.items), 60, 260)
	var per := []
	for k in kinds.size():
		per.append([])
	# La mayoría alrededor de las pilas del piso (montones), el resto disperso.
	var floor_piles := []
	for p in level.piles:
		if not p.surface:
			floor_piles.append(p.base)
	for i in total:
		var pos: Vector3
		if not floor_piles.is_empty() and rng.randf() < 0.7:
			var b: Vector3 = floor_piles[rng.randi_range(0, floor_piles.size() - 1)]
			var ang := rng.randf_range(0, TAU)
			pos = b + Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.12, 0.38)
		else:
			var c: Dictionary = floor_cells[rng.randi_range(0, floor_cells.size() - 1)]
			pos = c.pos + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		var room: Vector3 = L.size
		pos.x = clampf(pos.x, -room.x * 0.5 + 0.1, room.x * 0.5 - 0.1)
		pos.z = clampf(pos.z, -room.z * 0.5 + 0.1, room.z * 0.5 - 0.1)
		pos.y = 0.002 + rng.randf() * 0.002
		var xf := Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)), pos)
		per[rng.randi_range(0, kinds.size() - 1)].append(xf)
	for k in kinds.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = kinds[k]
		mm.instance_count = per[k].size()
		for i in per[k].size():
			mm.set_instance_transform(i, per[k][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = MeshKit.trash_material()
		add_child(mmi)
		_debris.append(mmi)


static func _debris_mesh(kind: String) -> ArrayMesh:
	var k := MeshKit.new()
	match kind:
		"paper":
			k.sphere(0.035, Vector3(0, 0.012, 0), Color(0.86, 0.85, 0.8), Vector3(1.2, 0.4, 1.0), 6)
		"sheet":
			k.box(Vector3(0.15, 0.003, 0.11), Vector3(0, 0.0015, 0), Color(0.93, 0.92, 0.86), Basis(Vector3.RIGHT, 0.04))
		"bag":
			k.sphere(0.07, Vector3(0, 0.014, 0), Color(0.1, 0.1, 0.11), Vector3(1.3, 0.3, 1.0), 10)
			k.sphere(0.035, Vector3(0.05, 0.02, 0.02), Color(0.2, 0.2, 0.22), Vector3(1.0, 0.5, 1.0), 8)
		"dirt":
			k.cyl(0.1, 0.12, 0.004, Vector3(0, 0.002, 0), Color(0.33, 0.27, 0.19), Basis(), 9)
		"cardboard":
			k.box(Vector3(0.3, 0.008, 0.22), Vector3(0, 0.004, 0), Color(0.62, 0.47, 0.32), Basis(Vector3.RIGHT, 0.03))
			k.box(Vector3(0.3, 0.009, 0.03), Vector3(0, 0.005, 0.05), Color(0.78, 0.7, 0.52))
	return k.commit()


## Montón bajo cada pila del piso: desaparece cuando se vacía la pila.
var _mounds: MultiMeshInstance3D
var _mound_pile: Array = []


func _build_mounds() -> void:
	var k := MeshKit.new()
	k.sphere(0.27, Vector3(0, 0, 0), Color(0.3, 0.26, 0.2), Vector3(1.0, 0.09, 1.0), 10)
	k.sphere(0.14, Vector3(0.1, 0.0, -0.06), Color(0.36, 0.31, 0.24), Vector3(1.0, 0.12, 1.0), 8)
	var mesh := k.commit()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(level.seed) + 99
	var xfs := []
	for pi in level.piles.size():
		var p: Dictionary = level.piles[pi]
		if p.surface:
			continue
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.9, 1.15)), p.base + Vector3(0, 0.003, 0)))
		_mound_pile.append(pi)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	_mounds = MultiMeshInstance3D.new()
	_mounds.multimesh = mm
	_mounds.material_override = MeshKit.trash_material()
	add_child(_mounds)


func _update_mounds(session: RoomSession) -> void:
	if _mounds == null:
		return
	for i in _mound_pile.size():
		var pile: Dictionary = level.piles[_mound_pile[i]]
		var any := false
		for sid in pile.slots:
			var pid: int = session.slot_piece[sid]
			if pid >= 0 and session.present[pid]:
				any = true
				break
		var xf := _mounds.multimesh.get_instance_transform(i)
		if not any and xf.basis.get_scale().x > 0.01:
			_mounds.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), xf.origin))


## fraction: parte de la basura decorativa que sigue visible (0..1).
func set_debris_fraction(fraction: float) -> void:
	for mmi in _debris:
		var n := mmi.multimesh.instance_count
		mmi.multimesh.visible_instance_count = int(ceil(n * clampf(fraction, 0.0, 1.0)))


# --- Manchas ------------------------------------------------------------------

func _build_stains(restore: Dictionary) -> void:
	var masks: Array = restore.get("masks", [])
	var size: Vector3 = L.size
	for si in L.stains.size():
		var st: Dictionary = L.stains[si]
		var node := Node3D.new()
		if st.surface == "floor":
			node.position = Vector3(st.pos.x, 0.004 + si * 0.001, st.pos.y)
		else:
			var fr := _wall_frame(st.surface)
			node.transform = fr * Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(st.pos.x, st.pos.y, 0.006))
		add_child(node)
		var img := Image.create(MASK_RES, MASK_RES, false, Image.FORMAT_L8)
		img.fill(Color(1, 1, 1))
		if si < masks.size() and masks[si] is String and masks[si] != "":
			var raw := Marshalls.base64_to_raw(masks[si])
			if raw.size() == MASK_RES * MASK_RES:
				img = Image.create_from_data(MASK_RES, MASK_RES, false, Image.FORMAT_L8, raw)
		var tex := ImageTexture.create_from_image(img)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://src/game/shaders/stain.gdshader")
		mat.set_shader_parameter("mask", tex)
		mat.set_shader_parameter("seed", float(si) * 3.7 + 1.3)
		mat.set_shader_parameter("color", Color(0.32, 0.25, 0.15) if st.surface == "floor" else Color(0.38, 0.36, 0.25))
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = st.size
		mi.mesh = pm
		mi.material_override = mat
		node.add_child(mi)
		var body := _static_box(node, Vector3(st.size.x, 0.01, st.size.y), Vector3.ZERO, LAYER_STAIN)
		body.set_meta("kind", "stain")
		body.set_meta("stain", si)
		var total := 0
		var dirty := 0
		for y in MASK_RES:
			for x in MASK_RES:
				if _in_stain(x, y):
					total += 1
					if img.get_pixel(x, y).r > 0.15:
						dirty += 1
		stain_nodes.append({"node": node, "image": img, "texture": tex, "total": total, "dirty": dirty, "def": st})


static func _in_stain(x: int, y: int) -> bool:
	var u := (x + 0.5) / MASK_RES - 0.5
	var v := (y + 0.5) / MASK_RES - 0.5
	return Vector2(u, v).length() < 0.36


## Frota en coordenadas UV de la mancha. Devuelve true si cambió algo.
func scrub(si: int, uv: Vector2, radius := 0.18, strength := 0.6) -> bool:
	var sn: Dictionary = stain_nodes[si]
	var img: Image = sn.image
	var cx := uv.x * MASK_RES
	var cy := uv.y * MASK_RES
	var r := radius * MASK_RES
	var changed := false
	for y in range(maxi(0, int(cy - r)), mini(MASK_RES, int(cy + r) + 1)):
		for x in range(maxi(0, int(cx - r)), mini(MASK_RES, int(cx + r) + 1)):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d > r:
				continue
			var v := img.get_pixel(x, y).r
			if v <= 0.0:
				continue
			var nv := maxf(0.0, v - strength * (1.0 - d / r * 0.5))
			img.set_pixel(x, y, Color(nv, nv, nv))
			changed = true
			if _in_stain(x, y) and v > 0.15 and nv <= 0.15:
				sn.dirty -= 1
	if changed:
		sn.texture.update(img)
	return changed


func clean_fraction() -> float:
	var total := 0
	var dirty := 0
	for sn in stain_nodes:
		total += sn.total
		dirty += sn.dirty
	if total == 0:
		return 1.0
	return clampf(1.0 - float(dirty) / total, 0.0, 1.0)


func masks_data() -> Array:
	var out := []
	for sn in stain_nodes:
		out.append(Marshalls.raw_to_base64(sn.image.get_data()))
	return out


func set_dirt_visual(clean: float) -> void:
	floor_material.set_shader_parameter("dirt", 1.0 - clean)


func set_stains_interactive(on: bool) -> void:
	for sn in stain_nodes:
		for ch in sn.node.get_children():
			if ch is StaticBody3D:
				ch.collision_layer = LAYER_STAIN if on else 0


func animate_paint(color: Color) -> void:
	wall_material.set_shader_parameter("new_color", color)
	wall_material.set_shader_parameter("progress", 0.0)
	var tw := create_tween()
	tw.tween_method(func(v): wall_material.set_shader_parameter("progress", v), 0.0, 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		wall_material.set_shader_parameter("old_color", color)
		wall_material.set_shader_parameter("dirt", 0.0)
		wall_material.set_shader_parameter("progress", 0.0))


# --- Puntos de observación ----------------------------------------------------

func _build_markers() -> void:
	for vi in L.viewpoints.size():
		var vp: Vector2 = L.viewpoints[vi]
		var node := Node3D.new()
		node.position = Vector3(vp.x, 0.01, vp.y)
		add_child(node)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.2
		tm.outer_radius = 0.26
		tm.rings = 24
		tm.ring_segments = 6
		ring.mesh = tm
		ring.scale = Vector3(1, 0.2, 1)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.8, 1.0, 0.85)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.7, 1.0)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = mat
		node.add_child(ring)
		if _labels_3d:
			var lbl := Label3D.new()
			lbl.text = str(vi + 1)
			lbl.font_size = 96
			lbl.pixel_size = 0.0025
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.position = Vector3(0, 0.25, 0)
			lbl.modulate = Color(0.6, 0.9, 1.0)
			lbl.outline_size = 12
			node.add_child(lbl)
		var body := _static_box(node, Vector3(0.55, 0.05, 0.55), Vector3(0, 0.02, 0), LAYER_INTERACT)
		body.set_meta("kind", "viewpoint")
		body.set_meta("viewpoint", vi)
		marker_nodes.append(node)


func set_current_viewpoint(vi: int) -> void:
	for i in marker_nodes.size():
		marker_nodes[i].visible = i != vi


# --- Piezas -------------------------------------------------------------------

func _build_pieces() -> void:
	var tmat := MeshKit.trash_material()
	for p in level.pieces:
		var node := Node3D.new()
		var mi := MeshInstance3D.new()
		match p.kind:
			"trash":
				mi.mesh = MeshKit.trash_mesh(p.variant)
				mi.material_override = tmat
			"mystery":
				mi.mesh = MeshKit.mystery_mesh()
				mi.material_override = tmat
				if _labels_3d:
					var q := Label3D.new()
					q.text = "?"
					q.font_size = 64
					q.pixel_size = 0.002
					q.position = Vector3(0, 0.08, 0.082)
					q.modulate = Color(1, 0.9, 0.4)
					q.outline_size = 8
					node.add_child(q)
			"key":
				mi.mesh = MeshKit.key_mesh()
				var km := StandardMaterial3D.new()
				km.vertex_color_use_as_albedo = true
				km.metallic = 0.7
				km.roughness = 0.3
				km.emission_enabled = true
				km.emission = Color(0.6, 0.45, 0.1)
				mi.material_override = km
		node.add_child(mi)
		var size := LevelGenerator.piece_size(p)
		var body := _static_box(node, size, Vector3(0, size.y * 0.5, 0), LAYER_INTERACT)
		body.set_meta("kind", "piece")
		body.set_meta("piece", p.id)
		piece_nodes.append({"node": node, "body": body, "mesh": mi, "size": size})
		add_child(node)


func place_piece(pid: int, session: RoomSession) -> void:
	var pn: Dictionary = piece_nodes[pid]
	var node: Node3D = pn.node
	if not session.present[pid]:
		node.visible = false
		pn.body.collision_layer = 0
		return
	var pose := LevelState.rest_pose(level, session.slot_piece, session.present, pid, session.piece_slot)
	var parent: Node3D = self
	var pos: Vector3 = pose.pos
	if pose.space == "drawer":
		parent = drawer_nodes[pose.drawer].content
	if node.get_parent() != parent:
		node.get_parent().remove_child(node)
		parent.add_child(node)
	node.position = pos
	node.rotation = Vector3(0, pose.yaw, 0)
	var hidden := session.is_hidden(pid)
	node.visible = not hidden
	pn.body.collision_layer = 0 if hidden else LAYER_INTERACT
	# Lo que todavía está tapado se ve más oscuro.
	if not pn.get("flashing", false):
		pn.mesh.material_overlay = covered_overlay() if (not hidden and not session.is_accessible(pid)) else null


static func covered_overlay() -> StandardMaterial3D:
	if _covered_overlay == null:
		_covered_overlay = StandardMaterial3D.new()
		_covered_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_covered_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_covered_overlay.albedo_color = Color(0.0, 0.0, 0.02, 0.42)
	return _covered_overlay


## Resalta una pieza (la que hay que sacar primero) con un brillo que late.
func flash_piece(pid: int) -> void:
	var pn: Dictionary = piece_nodes[pid]
	var mi: MeshInstance3D = pn.mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.9, 0.3, 0.0)
	mi.material_overlay = m
	pn["flashing"] = true
	var tw := mi.create_tween()
	for i in 3:
		tw.tween_property(m, "albedo_color:a", 0.75, 0.18)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(func():
		pn["flashing"] = false
		if _session:
			place_piece(pid, _session))


func place_all(session: RoomSession) -> void:
	_session = session
	_update_mounds(session)
	for p in level.pieces:
		place_piece(p.id, session)


## Puntos para comprobar línea de visión de una pieza (centro y arriba).
func piece_targets(pid: int) -> Array:
	var pn: Dictionary = piece_nodes[pid]
	var node: Node3D = pn.node
	var h: float = pn.size.y
	return [node.global_transform * Vector3(0, h * 0.5, 0), node.global_transform * Vector3(0, h * 0.9, 0)]


## Efecto breve de selección: anillo que se expande y desvanece.
func poof(at: Vector3, color := Color(1, 0.95, 0.6)) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.06
	tm.outer_radius = 0.09
	tm.rings = 16
	tm.ring_segments = 4
	mi.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.position = at
	add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(2.4, 2.4, 2.4), 0.25)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(mi.queue_free)


func shake(pid: int) -> void:
	var node: Node3D = piece_nodes[pid].node
	var base := node.position
	var tw := node.create_tween()
	for i in 3:
		tw.tween_property(node, "position", base + Vector3(0.01, 0, 0), 0.04)
		tw.tween_property(node, "position", base - Vector3(0.01, 0, 0), 0.04)
	tw.tween_property(node, "position", base, 0.04)
