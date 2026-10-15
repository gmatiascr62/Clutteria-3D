extends "res://tests/test_base.gd"


func test_three_identical_clear() -> void:
	var t := Tray.new()
	t.add("lata_roja_blanca", 1)
	t.add("lata_roja_blanca", 2)
	var r := t.add("lata_roja_blanca", 3)
	eq(r.cleared, "lata_roja_blanca", "tres iguales forman trío")
	eq(t.slots.size(), 0, "la bandeja queda vacía")


func test_near_identical_do_not_clear() -> void:
	var t := Tray.new()
	t.add("botella_verde_blanca", 1)
	t.add("botella_verde_amarilla", 2)
	var r := t.add("botella_verde_roja", 3)
	eq(r.cleared, "", "variantes parecidas NO forman trío")
	eq(t.slots.size(), 3, "siguen en la bandeja")
	# Mismo color y forma pero distinta escala tampoco.
	t.add("botella_ambar_crema", 4)
	t.add("botella_ambar_crema", 5)
	r = t.add("botella_ambar_corta", 6)
	eq(r.cleared, "", "misma etiqueta, distinto tamaño no forma trío")


func test_grouping_order() -> void:
	var t := Tray.new()
	t.add("a", 1)
	t.add("b", 2)
	t.add("a", 3)
	eq(t.slots[0].variant, "a", "agrupa iguales")
	eq(t.slots[1].variant, "a", "agrupa iguales (2)")
	eq(t.slots[2].variant, "b", "otras al final")


func test_full_without_trio() -> void:
	var t := Tray.new()
	var r := {}
	for i in 7:
		r = t.add("v%d" % (i % 4), i)
	# v0,v1,v2 tienen 2 copias, v3 1: 7 objetos sin trío.
	check(r.full, "7 objetos sin trío => llena")
	eq(t.free_slots(), 0, "sin espacios libres")


func test_seventh_completing_trio_is_not_full() -> void:
	var t := Tray.new()
	for v in ["a", "a", "b", "b", "c", "c"]:
		t.add(v, 0)
	var r := t.add("c", 9)
	eq(r.cleared, "c", "el séptimo completa trío")
	check(not r.full, "no queda llena porque el trío se elimina primero")
	eq(r.fill, 7, "fill registra 7 al entrar")


func test_pop_latest_and_serialize() -> void:
	var t := Tray.new()
	t.add("a", 1)
	t.add("b", 2)
	t.add("a", 3)
	var t2 := Tray.new()
	t2.from_dict(JSON.parse_string(JSON.stringify(t.to_dict())))
	eq(t2.slots.size(), 3, "serializa")
	var popped := t2.pop_latest(2)
	eq(popped, [3, 2], "devuelve los más recientes primero")
	eq(t2.slots.size(), 1, "queda uno")
