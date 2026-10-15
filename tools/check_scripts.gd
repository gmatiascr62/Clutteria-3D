extends SceneTree
## Carga y compila todos los scripts del proyecto (para CI).

func _initialize() -> void:
	var bad := 0
	var files := []
	_collect("res://src", files)
	_collect("res://tests", files)
	for f in files:
		var s = load(f)
		if s == null or (s is GDScript and not s.can_instantiate() and not f.ends_with("run_tests.gd")):
			printerr("ERROR al compilar: ", f)
			bad += 1
	print("Scripts revisados: %d, con errores: %d" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


func _collect(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)
