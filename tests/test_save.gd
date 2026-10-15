extends "res://tests/test_base.gd"

const PATH := "user://test_save.json"


func before_each() -> void:
	for p in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_roundtrip_with_vectors() -> void:
	var d := {"a": 1, "v": Vector3(1, 2, 3), "list": [Vector2(4, 5)], "nested": {"x": "y"}}
	check(SaveStore.save_json(PATH, d), "guarda")
	var back := SaveStore.load_json(PATH)
	eq(back.v, Vector3(1, 2, 3), "Vector3")
	eq(back.list[0], Vector2(4, 5), "Vector2")
	eq(back.nested.x, "y", "anidado")
	eq(int(back.schema), SaveStore.SCHEMA_VERSION, "versión de esquema")


func test_corrupt_main_falls_back_to_backup() -> void:
	SaveStore.save_json(PATH, {"n": 1})
	SaveStore.save_json(PATH, {"n": 2})
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{roto")
	f.close()
	var back := SaveStore.load_json(PATH)
	eq(int(back.get("n", -1)), 1, "usa la copia de respaldo")


func test_missing_returns_empty() -> void:
	eq(SaveStore.load_json(PATH), {}, "sin archivo => vacío")
