class_name Economy
extends RefCounted
## Reglas económicas puras (sin estado): vidas, ventas, restauración,
## desbloqueos y encargos.


## Regenera vidas según el tiempo transcurrido. Modifica `profile`.
static func update_lives(profile: Dictionary, now: int) -> void:
	var lives: int = profile.get("lives", Balance.MAX_LIVES)
	var ts: int = profile.get("life_ts", now)
	if lives >= Balance.MAX_LIVES:
		profile.lives = Balance.MAX_LIVES
		profile.life_ts = now
		return
	var elapsed := now - ts
	if elapsed >= Balance.LIFE_REGEN_SECONDS:
		var gained := elapsed / Balance.LIFE_REGEN_SECONDS
		lives = mini(Balance.MAX_LIVES, lives + gained)
		ts += gained * Balance.LIFE_REGEN_SECONDS
	profile.lives = lives
	profile.life_ts = now if lives >= Balance.MAX_LIVES else ts


static func seconds_to_next_life(profile: Dictionary, now: int) -> int:
	if profile.get("lives", 0) >= Balance.MAX_LIVES:
		return 0
	return maxi(0, Balance.LIFE_REGEN_SECONDS - (now - int(profile.get("life_ts", now))))


static func lose_life(profile: Dictionary, now: int) -> void:
	update_lives(profile, now)
	if profile.lives >= Balance.MAX_LIVES:
		profile.life_ts = now
	profile.lives = maxi(0, profile.lives - 1)


static func add_life(profile: Dictionary, now: int) -> void:
	update_lives(profile, now)
	profile.lives = mini(Balance.MAX_LIVES, profile.lives + 1)
	if profile.lives >= Balance.MAX_LIVES:
		profile.life_ts = now


## Costos de muebles en la restauración.
static func repair_cost(furniture: Dictionary) -> int:
	return int(round(furniture.get("value", 100) * 0.3))


static func replace_cost(furniture: Dictionary) -> int:
	return int(round(furniture.get("value", 100) * 1.0))


static func repair_value(furniture: Dictionary) -> int:
	return int(round(furniture.get("value", 100) * 0.45))


static func replace_value(furniture: Dictionary) -> int:
	return int(round(furniture.get("value", 100) * 1.35))


## Valor que agrega la restauración de una habitación.
static func room_restoration_value(layout_id: String, restore: Dictionary) -> int:
	var L: Dictionary = PropertyCatalog.LAYOUTS[layout_id]
	var v := 0
	var paint := Balance.paint_by_id(restore.get("paint", ""))
	if restore.has("paint"):
		v += int(paint.value)
	var furn: Dictionary = restore.get("furniture", {})
	for k in furn:
		var f: Dictionary = L.furniture[int(k)]
		if furn[k] == "repaired":
			v += repair_value(f)
		elif furn[k] == "replaced":
			v += replace_value(f)
	var fixed: Dictionary = restore.get("fixtures", {})
	for f in fixed:
		if fixed[f] and Balance.FIXTURES.has(f):
			v += int(Balance.FIXTURES[f].value)
	v += int(restore.get("treasure_value", 0))
	return v


## Venta de una propiedad. `restored`: room_key -> datos de restauración.
static func sale_breakdown(prop_id: String, restored: Dictionary, purchase_price: int) -> Dictionary:
	var P: Dictionary = PropertyCatalog.PROPERTIES[prop_id]
	var clean_sum := 0.0
	var count := 0
	var added := 0
	var spent := 0
	for i in P.rooms.size():
		var room: Dictionary = P.rooms[i]
		if room.get("secret", false):
			continue
		var key := "%s/%d" % [prop_id, i]
		var r: Dictionary = restored.get(key, {})
		clean_sum += float(r.get("clean", 0.0))
		count += 1
		added += room_restoration_value(room.layout, r)
		spent += int(r.get("spent", 0))
	var condition := clean_sum / maxf(1.0, count)
	var base := int(round(P.base_value * (0.7 + 0.3 * condition)))
	var sale := base + added
	var invest := purchase_price + spent
	return {"base": base, "added": added, "sale": sale, "invest": invest, "spent": spent,
		"purchase": purchase_price, "profit": sale - invest, "condition": condition}


static func can_unlock_neighborhood(n: Dictionary, total_stars: int, coins: int) -> bool:
	return total_stars >= n.stars and coins >= n.cost


## Encargos de limpieza: dependen del día, no arriesgan vidas.
static func contracts_for_day(day: int, progress_level: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * day + 13
	var layouts := PropertyCatalog.LAYOUTS.keys()
	var out := []
	var base_items := [30, 45, 60, 90, 120]
	for i in 3:
		var tier := clampi(progress_level + i - 1, 0, base_items.size() - 1)
		var layout: String = layouts[rng.randi_range(0, layouts.size() - 1)]
		var items: int = mini(base_items[tier], PropertyCatalog.LAYOUTS[layout].max_items)
		var reward := int(round(items * 1.5)) + 20
		out.append({"id": "c%d_%d" % [day, i], "layout": layout, "items": items,
			"difficulty": clampf(0.1 + tier * 0.15, 0.0, 0.8), "seed": rng.randi(), "reward": reward,
			"daily": i == 0, "name": "Encargo: %s" % PropertyCatalog.LAYOUTS[layout].name})
	return out
