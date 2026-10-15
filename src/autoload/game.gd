extends Node
## Estado global: perfil del jugador, progreso, partida en curso y guardado.

signal profile_changed

const SAVE_PATH := "user://clutteria_save.json"

## Ruta del guardado (las pruebas y herramientas usan otra para no pisarlo).
var save_path := SAVE_PATH
var profile: Dictionary = {}
## Partida en curso (habitación). Vacío si no hay.
var run: Dictionary = {}
## Semilla forzada para depuración (--seed=N en la línea de comandos).
var debug_seed := -1
## Mensaje para mostrar al volver al mapa (venta, desbloqueos...).
var pending_notice: Array = []

var _dirty := false
var _save_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--seed="):
			debug_seed = int(a.substr(7))
	load_game()


func _process(delta: float) -> void:
	if _dirty:
		_save_timer -= delta
		if _save_timer <= 0.0:
			save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()


func now() -> int:
	return int(Time.get_unix_time_from_system())


func new_profile() -> Dictionary:
	return {
		"coins": Balance.START_COINS,
		"lives": Balance.MAX_LIVES,
		"life_ts": now(),
		"tools": Balance.START_TOOLS.duplicate(),
		"stars": {},
		"completed": {},
		"restored": {},
		"properties": {},
		"neighborhoods": ["centro"],
		"keys": {},
		"settings": {"sensitivity": 1.0, "volume": 0.8, "mute": false},
		"tutorial": {},
		"daily_claimed": -1,
		"contracts_done": {},
		"sold_log": [],
	}


func load_game() -> void:
	var data := SaveStore.load_json(save_path)
	var fresh := new_profile()
	profile = data.get("profile", fresh)
	# Completar claves nuevas si el guardado es anterior.
	for k in fresh:
		if not profile.has(k):
			profile[k] = fresh[k]
	for k in fresh.settings:
		if not profile.settings.has(k):
			profile.settings[k] = fresh.settings[k]
	for t in Balance.START_TOOLS:
		profile.tools[t] = int(profile.tools.get(t, 0))
	profile.coins = int(profile.coins)
	profile.lives = int(profile.lives)
	profile.life_ts = int(profile.life_ts)
	profile.daily_claimed = int(profile.daily_claimed)
	run = data.get("run", {})
	_grant_free_properties()
	Economy.update_lives(profile, now())


func save_now() -> void:
	_dirty = false
	SaveStore.save_json(save_path, {"profile": profile, "run": run})


## Guardado diferido (agrupa cambios frecuentes).
func mark_dirty(immediate := false) -> void:
	if immediate:
		save_now()
		return
	if not _dirty:
		_dirty = true
		_save_timer = 1.0


func reset_progress() -> void:
	profile = new_profile()
	run = {}
	_grant_free_properties()
	save_now()
	profile_changed.emit()


func setting(key: String):
	return profile.settings.get(key)


func set_setting(key: String, value) -> void:
	profile.settings[key] = value
	Sfx.apply_settings()
	mark_dirty()


# --- Vidas y monedas ------------------------------------------------------

func lives() -> int:
	Economy.update_lives(profile, now())
	return profile.lives


func seconds_to_next_life() -> int:
	Economy.update_lives(profile, now())
	return Economy.seconds_to_next_life(profile, now())


func add_coins(n: int) -> void:
	profile.coins = maxi(0, int(profile.coins) + n)
	mark_dirty()
	profile_changed.emit()


func spend(n: int) -> bool:
	if int(profile.coins) < n:
		return false
	profile.coins = int(profile.coins) - n
	mark_dirty()
	profile_changed.emit()
	return true


func buy_tool(tool: String) -> bool:
	if not spend(Balance.TOOL_PRICES[tool]):
		return false
	profile.tools[tool] = int(profile.tools.get(tool, 0)) + 1
	mark_dirty()
	profile_changed.emit()
	return true


func apply_prize(prize: Dictionary) -> String:
	match prize.get("type", ""):
		"coins":
			add_coins(int(prize.amount))
			return "+%d monedas" % int(prize.amount)
		"tool":
			profile.tools[prize.tool] = int(profile.tools.get(prize.tool, 0)) + 1
			mark_dirty()
			profile_changed.emit()
			return "Herramienta: %s" % Balance.TOOL_NAMES[prize.tool]
		"treasure":
			add_coins(int(prize.amount))
			return "¡Tesoro! +%d monedas y +%d de valor para la casa" % [int(prize.amount), int(prize.value)]
	return ""


# --- Progreso -------------------------------------------------------------

func total_stars() -> int:
	var n := 0
	for k in profile.stars:
		n += int(profile.stars[k])
	return n


func _grant_free_properties() -> void:
	for n in PropertyCatalog.NEIGHBORHOODS:
		if not profile.neighborhoods.has(n.id):
			continue
		for pid in n.properties:
			if PropertyCatalog.PROPERTIES[pid].price == 0 and not profile.properties.has(pid):
				profile.properties[pid] = {"owned": true, "sold": false, "purchase": 0}


func neighborhood_unlocked(nid: String) -> bool:
	return profile.neighborhoods.has(nid)


func unlock_neighborhood(nid: String) -> bool:
	for n in PropertyCatalog.NEIGHBORHOODS:
		if n.id == nid and not neighborhood_unlocked(nid):
			if not Economy.can_unlock_neighborhood(n, total_stars(), int(profile.coins)):
				return false
			spend(n.cost)
			profile.neighborhoods.append(nid)
			_grant_free_properties()
			mark_dirty(true)
			profile_changed.emit()
			return true
	return false


func property_owned(pid: String) -> bool:
	return profile.properties.has(pid) and profile.properties[pid].owned


func property_sold(pid: String) -> bool:
	return profile.properties.has(pid) and profile.properties[pid].get("sold", false)


func buy_property(pid: String) -> bool:
	var P: Dictionary = PropertyCatalog.PROPERTIES[pid]
	if property_owned(pid) or not neighborhood_unlocked(PropertyCatalog.neighborhood_of(pid).id):
		return false
	if not spend(P.price):
		return false
	profile.properties[pid] = {"owned": true, "sold": false, "purchase": P.price}
	mark_dirty(true)
	profile_changed.emit()
	return true


func is_completed(room_key: String) -> bool:
	return profile.completed.get(room_key, false)


func is_restored(room_key: String) -> bool:
	return profile.restored.has(room_key)


func has_key(room_key: String) -> bool:
	return profile.keys.get(room_key, false)


## Estado de una habitación: locked | secret_locked | available | restore | done
func room_state(room_key: String) -> String:
	var parts := room_key.split("/")
	var pid := parts[0]
	var idx := int(parts[1])
	var def := PropertyCatalog.room_def(room_key)
	if not property_owned(pid):
		return "locked"
	if def.get("secret", false) and not has_key(room_key):
		return "secret_locked"
	if is_restored(room_key):
		return "done"
	if is_completed(room_key):
		return "restore"
	# Las habitaciones normales se habilitan en orden.
	if not def.get("secret", false):
		for i in idx:
			var prev := "%s/%d" % [pid, i]
			if PropertyCatalog.room_def(prev).get("secret", false):
				continue
			if not is_restored(prev):
				return "locked"
	return "available"


## Siguiente habitación sugerida para "Jugar".
func next_story_room() -> String:
	for n in PropertyCatalog.NEIGHBORHOODS:
		if not neighborhood_unlocked(n.id):
			continue
		for pid in n.properties:
			if not property_owned(pid) or property_sold(pid):
				continue
			for key in PropertyCatalog.room_keys(pid):
				var st := room_state(key)
				if st == "available" or st == "restore":
					return key
	return ""


func tutorial_done(step: String) -> bool:
	return profile.tutorial.get(step, false)


func set_tutorial_done(step: String) -> void:
	profile.tutorial[step] = true
	mark_dirty()


# --- Partidas ---------------------------------------------------------------

func has_run() -> bool:
	return not run.is_empty()


func _new_seed() -> int:
	if debug_seed >= 0:
		return debug_seed
	return randi() & 0x7fffffff


## Inicia una habitación de una propiedad. Devuelve "" o un motivo de error.
func start_room(room_key: String) -> String:
	var def := PropertyCatalog.room_def(room_key)
	if def.is_empty():
		return "Habitación inválida"
	var st := room_state(room_key)
	if st == "locked" or st == "secret_locked":
		return "Habitación bloqueada"
	if st == "restore":
		# Basura ya retirada: continuar con la restauración.
		run = {"room_key": room_key, "mode": "story", "layout": def.layout, "items": def.items,
			"difficulty": def.difficulty, "challenge": def.challenge, "seed": _new_seed(),
			"restore_only": true, "session": {}, "camera": {}, "restore": {}}
		mark_dirty(true)
		return ""
	var mode := "replay" if is_completed(room_key) else "story"
	if mode == "story" and lives() <= 0:
		return "Sin vidas. Esperá %s o jugá un encargo / desafío diario." % format_time(seconds_to_next_life())
	var parts := room_key.split("/")
	var key_for := -1
	if def.has("key_for"):
		var secret_key := "%s/%d" % [parts[0], int(def.key_for)]
		if not has_key(secret_key):
			key_for = int(def.key_for)
	run = {"room_key": room_key, "mode": mode, "layout": def.layout, "items": def.items,
		"difficulty": def.difficulty, "challenge": def.challenge, "seed": _new_seed(),
		"key_for": key_for, "tutorial": def.get("tutorial", false) and mode == "story",
		"session": {}, "camera": {}, "restore": {}}
	mark_dirty(true)
	return ""


func start_contract(c: Dictionary) -> String:
	run = {"room_key": "contract", "mode": "contract", "layout": c.layout, "items": c.items,
		"difficulty": c.difficulty, "challenge": "tray_max5" if c.daily else "find_mystery",
		"seed": int(c.seed) if debug_seed < 0 else debug_seed, "contract": c, "key_for": -1,
		"session": {}, "camera": {}, "restore": {}}
	mark_dirty(true)
	return ""


func run_level() -> Dictionary:
	var opts := {"key": int(run.get("key_for", -1)) >= 0}
	return LevelGenerator.generate(run.layout, int(run.items), float(run.difficulty), int(run.seed), opts)


func clear_run() -> void:
	run = {}
	mark_dirty(true)


## Registra la derrota. Devuelve true si se descontó una vida.
func record_loss(session: RoomSession) -> bool:
	if session.loss_life_taken:
		return false
	var costs: bool = run.get("mode", "") == "story" and session.loss_costs_life(is_completed(run.get("room_key", "")))
	if costs:
		Economy.lose_life(profile, now())
	session.loss_life_taken = true
	save_session(session)
	profile_changed.emit()
	return costs


func save_session(session: RoomSession, camera := {}) -> void:
	if run.is_empty():
		return
	run.session = session.to_dict()
	if not camera.is_empty():
		run.camera = camera
	mark_dirty()


func on_key_found() -> void:
	var parts := String(run.room_key).split("/")
	if parts.size() == 2 and int(run.get("key_for", -1)) >= 0:
		var key := "%s/%d" % [parts[0], int(run.key_for)]
		profile.keys[key] = true
		pending_notice.append("¡Encontraste una llave! Se desbloqueó: %s" % PropertyCatalog.room_def(key).name)
		mark_dirty(true)


## Fin de la fase de basura. Devuelve el resumen de recompensas.
func finish_trash(session: RoomSession) -> Dictionary:
	var stars := session.stars()
	var mode: String = run.mode
	var key: String = run.room_key
	var coins := 0
	var extra := []
	if mode == "contract":
		var c: Dictionary = run.contract
		coins = int(round(c.reward * (0.6 + 0.2 * (stars - 1))))
		if profile.contracts_done.has(c.id):
			coins = coins / 2 # repetir un encargo paga la mitad
		profile.contracts_done[c.id] = true
		if c.daily and stars >= 2 and int(profile.daily_claimed) != today():
			profile.daily_claimed = today()
			Economy.add_life(profile, now())
			coins += 50
			extra.append("Desafío diario cumplido: +1 vida y +50 monedas")
	else:
		var def := PropertyCatalog.room_def(key)
		coins = Balance.room_reward(int(run.items), stars, mode)
		if def.get("secret", false):
			coins *= 2
		var prev := int(profile.stars.get(key, 0))
		if stars > prev:
			profile.stars[key] = stars
		profile.completed[key] = true
		if def.get("secret", false) and not is_restored(key):
			# Las habitaciones secretas no requieren restauración.
			profile.restored[key] = {"clean": 1.0, "spent": 0, "secret": true}
	add_coins(coins)
	var result := {"stars": stars, "coins": coins, "time_left": session.time_left,
		"time_star": session.time_star(), "challenge": session.challenge_met(), "extra": extra,
		"treasure_value": session.stats.treasure_value}
	run["result"] = result
	run.session = session.to_dict()
	mark_dirty(true)
	profile_changed.emit()
	return result


func needs_restoration() -> bool:
	if run.get("mode", "") != "story" and not run.get("restore_only", false):
		return false
	var key: String = run.get("room_key", "")
	return key != "contract" and not is_restored(key)


## Guarda la restauración y vende la propiedad si quedó completa.
func finish_restoration(restore: Dictionary) -> Dictionary:
	var key: String = run.room_key
	profile.restored[key] = restore
	var pid := key.split("/")[0]
	var sale := {}
	var complete := true
	for rk in PropertyCatalog.room_keys(pid):
		if PropertyCatalog.room_def(rk).get("secret", false):
			continue
		if not is_restored(rk):
			complete = false
	if complete and not property_sold(pid):
		sale = Economy.sale_breakdown(pid, profile.restored, int(profile.properties[pid].get("purchase", 0)))
		profile.properties[pid].sold = true
		profile.sold_log.append({"property": pid, "sale": sale.sale, "profit": sale.profit})
		add_coins(sale.sale)
		sale["name"] = PropertyCatalog.PROPERTIES[pid].name
	mark_dirty(true)
	profile_changed.emit()
	return sale


func today() -> int:
	return now() / 86400


func contracts() -> Array:
	var level := 0
	if neighborhood_unlocked("jardines"):
		level = 1
	if neighborhood_unlocked("colinas"):
		level = 2
	if neighborhood_unlocked("lomas"):
		level = 3
	return Economy.contracts_for_day(today(), level)


static func format_time(seconds: float) -> String:
	var s := int(ceil(seconds))
	return "%d:%02d" % [s / 60, s % 60]
