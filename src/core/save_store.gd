class_name SaveStore
extends RefCounted
## Guardado atómico en JSON con versión de esquema.
## Escribe en un archivo temporal, conserva una copia .bak del anterior y
## luego renombra; al cargar, si el principal está dañado usa el .bak.

const SCHEMA_VERSION := 1


static func save_json(path: String, data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["schema"] = SCHEMA_VERSION
	var text := JSON.stringify(_encode(payload))
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir %s (%s)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.flush()
	f.close()
	# Verificar lo escrito antes de reemplazar.
	var check := FileAccess.get_file_as_string(tmp)
	if check != text:
		push_error("Verificación de guardado fallida")
		return false
	if FileAccess.file_exists(path):
		var bak := path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	var err := DirAccess.rename_absolute(tmp, path)
	return err == OK


static func load_json(path: String) -> Dictionary:
	for p in [path, path + ".bak"]:
		if not FileAccess.file_exists(p):
			continue
		var text := FileAccess.get_file_as_string(p)
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			return migrate(_decode(parsed))
		push_warning("Guardado dañado: %s" % p)
	return {}


## Migraciones de esquema. Hoy sólo existe la versión 1.
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("schema", 0))
	if v < 1:
		d["schema"] = 1
	return d


## JSON no soporta Vector2/Vector3: se codifican como diccionarios marcados.
static func _encode(v):
	if v is Dictionary:
		var o := {}
		for k in v:
			o[str(k)] = _encode(v[k])
		return o
	if v is Array:
		var a := []
		for x in v:
			a.append(_encode(x))
		return a
	if v is Vector3:
		return {"__v3": [v.x, v.y, v.z]}
	if v is Vector2:
		return {"__v2": [v.x, v.y]}
	return v


static func _decode(v):
	if v is Dictionary:
		if v.has("__v3"):
			return Vector3(v.__v3[0], v.__v3[1], v.__v3[2])
		if v.has("__v2"):
			return Vector2(v.__v2[0], v.__v2[1])
		var o := {}
		for k in v:
			o[k] = _decode(v[k])
		return o
	if v is Array:
		var a := []
		for x in v:
			a.append(_decode(x))
		return a
	return v
