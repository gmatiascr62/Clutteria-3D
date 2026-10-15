extends Control
## Mapa de barrios, propiedades, habitaciones y encargos.

var _list: VBoxContainer
var _contracts: VBoxContainer
var _coins: Label
var _lives: Label
var _stars: Label


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fullscreen(self)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.16)
	UiKit.fullscreen(bg)
	add_child(bg)
	var root := VBoxContainer.new()
	UiKit.fullscreen(root)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 12
	root.offset_bottom = -12
	add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	root.add_child(top)
	top.add_child(UiKit.button("< Menú", func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), Color(0.3, 0.32, 0.38), Vector2(140, 60)))
	top.add_child(UiKit.label("Mapa de barrios", 30, UiKit.ACCENT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UiKit.button("Herramientas", func(): ShopDialog.open(self, _rebuild), Color(0.3, 0.35, 0.5), Vector2(0, 60)))
	top.add_child(VectorIcon.make("star", UiKit.ACCENT, 30))
	_stars = UiKit.label("", 26)
	top.add_child(_stars)
	top.add_child(VectorIcon.make("coin", UiKit.ACCENT, 30))
	_coins = UiKit.label("", 26)
	top.add_child(_coins)
	top.add_child(VectorIcon.make("heart", UiKit.BAD, 30))
	_lives = UiKit.label("", 26)
	top.add_child(_lives)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	scroll.add_child(_list)

	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(390, 0)
	body.add_child(side)
	var side_scroll := ScrollContainer.new()
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(side_scroll)
	_contracts = VBoxContainer.new()
	_contracts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(_contracts)

	Game.profile_changed.connect(_rebuild)
	_rebuild()
	_show_notices()


func _process(_d: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		_update_top()


func _update_top() -> void:
	_coins.text = str(int(Game.profile.coins))
	var l := Game.lives()
	_lives.text = "%d/%d" % [l, Balance.MAX_LIVES] + ("" if l >= Balance.MAX_LIVES else " (%s)" % Game.format_time(Game.seconds_to_next_life()))
	_stars.text = str(Game.total_stars())


func _show_notices() -> void:
	if Game.pending_notice.is_empty():
		return
	var text := "\n".join(Game.pending_notice)
	Game.pending_notice.clear()
	UiKit.dialog(self, "Novedades", text, [["OK", func(): pass]])


func _rebuild() -> void:
	if not is_inside_tree():
		return
	_update_top()
	for c in _list.get_children():
		c.queue_free()
	for n in PropertyCatalog.NEIGHBORHOODS:
		_list.add_child(_neighborhood_panel(n))
	for c in _contracts.get_children():
		c.queue_free()
	_contracts.add_child(UiKit.label("Encargos de limpieza", 26, UiKit.ACCENT))
	_contracts.add_child(UiKit.label("Ganá monedas sin arriesgar vidas. Se renuevan cada día.", 16, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 340))
	for c in Game.contracts():
		_contracts.add_child(_contract_row(c))


func _neighborhood_panel(n: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var unlocked := Game.neighborhood_unlocked(n.id)
	var head := HBoxContainer.new()
	vb.add_child(head)
	head.add_child(UiKit.label(n.name, 28, UiKit.ACCENT if unlocked else UiKit.MUTED))
	if not unlocked:
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(sp)
		head.add_child(VectorIcon.make("lock", UiKit.MUTED, 30))
		var can := Economy.can_unlock_neighborhood(n, Game.total_stars(), int(Game.profile.coins))
		vb.add_child(UiKit.label("Requiere %d estrellas (tenés %d) y %d monedas." % [n.stars, Game.total_stars(), n.cost], 19, UiKit.MUTED))
		var b := UiKit.button("Desbloquear (%d monedas)" % n.cost, func():
			if Game.unlock_neighborhood(n.id):
				Sfx.play("win")
				UiKit.dialog(self, "¡Barrio desbloqueado!", n.name + " ya está disponible.", [["OK", func(): pass]])
			_rebuild(), UiKit.GOOD.darkened(0.3), Vector2(0, 60))
		b.disabled = not can
		vb.add_child(b)
		return panel
	for pid in n.properties:
		vb.add_child(_property_card(pid))
	return panel


func _property_card(pid: String) -> Control:
	var P: Dictionary = PropertyCatalog.PROPERTIES[pid]
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(Color(0.2, 0.24, 0.31), 14, 10))
	var vb := VBoxContainer.new()
	card.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	head.add_child(UiKit.label("%s  ·  %s" % [P.name, P.kind], 23))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	if Game.property_sold(pid):
		head.add_child(UiKit.label("VENDIDA", 20, UiKit.GOOD))
	elif not Game.property_owned(pid):
		var b := UiKit.button("Comprar (%d)" % P.price, func():
			if Game.buy_property(pid):
				Sfx.play("coin")
			_rebuild(), UiKit.GOOD.darkened(0.3), Vector2(200, 54))
		b.disabled = int(Game.profile.coins) < P.price
		head.add_child(b)
		vb.add_child(UiKit.label("Valor base de venta: %d · %d habitaciones" % [P.base_value, P.rooms.size()], 17, UiKit.MUTED))
		return card
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for key in PropertyCatalog.room_keys(pid):
		grid.add_child(_room_row(key))
	return card


func _room_row(key: String) -> Control:
	var def := PropertyCatalog.room_def(key)
	var st := Game.room_state(key)
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(390, 0)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name: String = def.name
	if st == "secret_locked":
		name = "??? (secreta)"
	info.add_child(UiKit.label(name, 19))
	var stars := HBoxContainer.new()
	stars.add_theme_constant_override("separation", 0)
	var n := int(Game.profile.stars.get(key, 0))
	for i in 3:
		stars.add_child(VectorIcon.make("star", UiKit.ACCENT, 18, i < n))
	var lbl := UiKit.label("  %d objetos" % def.items, 14, UiKit.MUTED)
	stars.add_child(lbl)
	info.add_child(stars)
	hb.add_child(info)
	var text := ""
	var color := Color(0.25, 0.45, 0.6)
	var enabled := true
	match st:
		"available":
			text = "Limpiar"
			color = Color(0.85, 0.55, 0.15)
		"restore":
			text = "Restaurar"
			color = UiKit.GOOD.darkened(0.3)
		"done":
			text = "Repetir"
		"locked":
			text = "Bloqueada"
			enabled = false
		"secret_locked":
			text = "Falta llave"
			enabled = false
	if Game.has_run() and Game.run.room_key == key:
		text = "Continuar"
		color = UiKit.GOOD.darkened(0.3)
	var b := UiKit.button(text, func(): _launch_room(key), color, Vector2(150, 54))
	b.disabled = not enabled
	hb.add_child(b)
	return hb


func _launch_room(key: String) -> void:
	if Game.has_run():
		if Game.run.room_key == key:
			get_tree().change_scene_to_file("res://scenes/room.tscn")
			return
		UiKit.dialog(self, "Partida en curso", "Tenés otra habitación empezada. ¿Abandonarla y empezar esta? (No cuesta vidas)", [
			["Abandonar", func():
				Game.clear_run()
				_launch_room(key), UiKit.BAD.darkened(0.2)],
			["Cancelar", func(): pass],
		])
		return
	var err := Game.start_room(key)
	if err != "":
		UiKit.dialog(self, "No se puede jugar", err, [["OK", func(): pass]])
		return
	get_tree().change_scene_to_file("res://scenes/room.tscn")


func _contract_row(c: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(Color(0.2, 0.24, 0.31) if not c.daily else Color(0.3, 0.24, 0.12), 14, 10))
	var vb := VBoxContainer.new()
	card.add_child(vb)
	var done: bool = Game.profile.contracts_done.has(c.id)
	var title: String = ("Desafío diario — " if c.daily else "") + c.name
	vb.add_child(UiKit.label(title, 19, UiKit.ACCENT if c.daily else UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 340))
	var desc := "%d objetos · paga hasta %d monedas" % [c.items, c.reward]
	if c.daily:
		desc += "\nCon 2+ estrellas: +1 vida y +50 monedas (una vez por día)"
	vb.add_child(UiKit.label(desc, 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_LEFT, 340))
	var b := UiKit.button("Hecho (repetir)" if done else "Aceptar", func():
		var launch := func():
			Game.start_contract(c)
			get_tree().change_scene_to_file("res://scenes/room.tscn")
		if Game.has_run():
			UiKit.dialog(self, "Partida en curso", "¿Abandonar la partida actual? (No cuesta vidas)", [
				["Abandonar", func():
					Game.clear_run()
					launch.call(), UiKit.BAD.darkened(0.2)],
				["Cancelar", func(): pass]])
		else:
			launch.call(), Color(0.25, 0.45, 0.6), Vector2(0, 52))
	vb.add_child(b)
	return card
