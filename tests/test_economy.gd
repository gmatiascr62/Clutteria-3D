extends "res://tests/test_base.gd"


func test_lives_regenerate() -> void:
	var p := {"lives": 2, "life_ts": 1000}
	Economy.update_lives(p, 1000 + Balance.LIFE_REGEN_SECONDS - 1)
	eq(p.lives, 2, "aún no regenera")
	Economy.update_lives(p, 1000 + Balance.LIFE_REGEN_SECONDS * 2 + 5)
	eq(p.lives, 4, "regenera 2")
	eq(Economy.seconds_to_next_life(p, 1000 + Balance.LIFE_REGEN_SECONDS * 2 + 5), Balance.LIFE_REGEN_SECONDS - 5, "cuenta regresiva conserva el resto")
	Economy.update_lives(p, 1000 + Balance.LIFE_REGEN_SECONDS * 50)
	eq(p.lives, Balance.MAX_LIVES, "tope de vidas")


func test_lose_life_starts_timer() -> void:
	var p := {"lives": Balance.MAX_LIVES, "life_ts": 0}
	Economy.lose_life(p, 5000)
	eq(p.lives, Balance.MAX_LIVES - 1, "pierde una")
	eq(p.life_ts, 5000, "el contador arranca al perder")
	Economy.lose_life(p, 5000)
	Economy.lose_life(p, 5000)
	Economy.lose_life(p, 5000)
	Economy.lose_life(p, 5000)
	Economy.lose_life(p, 5000)
	eq(p.lives, 0, "no baja de cero")


func test_sale_is_profitable_with_reasonable_restoration() -> void:
	for pid in PropertyCatalog.PROPERTIES:
		var P: Dictionary = PropertyCatalog.PROPERTIES[pid]
		var restored := {}
		for i in P.rooms.size():
			var L: Dictionary = PropertyCatalog.LAYOUTS[P.rooms[i].layout]
			var furn := {}
			var spent := 0
			for fi in L.furniture.size():
				furn[str(fi)] = "repaired"
				spent += Economy.repair_cost(L.furniture[fi])
			restored["%s/%d" % [pid, i]] = {"clean": 1.0, "paint": "crema", "furniture": furn, "spent": spent}
		var s := Economy.sale_breakdown(pid, restored, P.price)
		check(s.profit > 0, "%s deja ganancia (%d)" % [pid, s.profit])
		check(s.sale > P.price, "%s vende más caro de lo que cuesta" % pid)


func test_replacement_adds_more_value_than_repair() -> void:
	var f: Dictionary = PropertyCatalog.LAYOUTS.living.furniture[0]
	check(Economy.replace_value(f) > Economy.repair_value(f), "reemplazar agrega más valor")
	check(Economy.replace_cost(f) > Economy.repair_cost(f), "y cuesta más")


func test_rewards_scale_with_stars_and_mode() -> void:
	check(Balance.room_reward(60, 3, "story") > Balance.room_reward(60, 1, "story"), "más estrellas, más monedas")
	check(Balance.room_reward(60, 3, "replay") < Balance.room_reward(60, 3, "story"), "repetir paga menos")
	check(Balance.room_reward(60, 1, "contract") > 0, "encargo paga")


func test_contracts_always_available() -> void:
	for day in 30:
		var c := Economy.contracts_for_day(day, 0)
		eq(c.size(), 3, "3 encargos por día")
		for x in c:
			eq(x.items % 3, 0, "encargo con tríos completos")
			check(x.reward > 0, "encargo paga")
	eq(JSON.stringify(Economy.contracts_for_day(4, 1)), JSON.stringify(Economy.contracts_for_day(4, 1)), "deterministas por día")


func test_time_scales_with_difficulty() -> void:
	var small := LevelGenerator.generate("studio", 30, 0.0, 1)
	var big := LevelGenerator.generate("living", 240, 0.8, 1)
	var t1 := Balance.level_time(small.info)
	var t2 := Balance.level_time(big.info)
	check(t1 >= 90 and t1 <= 240, "30 objetos: entre 1:30 y 4:00 (%d s)" % t1)
	check(t2 > t1 * 5, "240 objetos llevan bastante más tiempo (%d s)" % t2)
