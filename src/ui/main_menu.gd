extends Control
## Pantalla principal.

var _status: Label
var _lives_label: Label
var _coins_label: Label
var _stars_label: Label
var _continue: Button
var _ad_button: Button
var _dialog: Control


func _ready() -> void:
	theme = UiKit.theme()
	UiKit.fullscreen(self)
	var bg := ColorRect.new()
	UiKit.fullscreen(bg)
	add_child(bg)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; void fragment(){ vec2 uv = UV; COLOR = vec4(mix(vec3(0.16,0.32,0.42), vec3(0.08,0.1,0.15), uv.y) + 0.03*sin(uv.x*40.0+uv.y*20.0), 1.0); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	bg.material = mat

	var root := HBoxContainer.new()
	UiKit.fullscreen(root)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 40
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 40)
	add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 14)
	root.add_child(left)
	left.add_child(UiKit.label("Clutteria 3D", 72, UiKit.ACCENT))
	left.add_child(UiKit.label("Encontrá tríos exactos, limpiá, restaurá y vendé casas.", 24, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, 500))
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 18)
	stats.add_child(VectorIcon.make("coin", UiKit.ACCENT, 34))
	_coins_label = UiKit.label("", 28)
	stats.add_child(_coins_label)
	stats.add_child(VectorIcon.make("heart", UiKit.BAD, 34))
	_lives_label = UiKit.label("", 28)
	stats.add_child(_lives_label)
	stats.add_child(VectorIcon.make("star", UiKit.ACCENT, 34))
	_stars_label = UiKit.label("", 28)
	stats.add_child(_stars_label)
	left.add_child(stats)
	_status = UiKit.label("", 20, UiKit.MUTED)
	left.add_child(_status)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(420, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 14)
	root.add_child(right)
	_continue = UiKit.button("Continuar partida", _on_continue, UiKit.GOOD.darkened(0.25), Vector2(0, 78))
	right.add_child(_continue)
	right.add_child(UiKit.button("Jugar", _on_play, Color(0.85, 0.55, 0.15), Vector2(0, 78)))
	right.add_child(UiKit.button("Mapa de barrios", func(): get_tree().change_scene_to_file("res://scenes/map.tscn"), Color(0.25, 0.45, 0.6), Vector2(0, 70)))
	right.add_child(UiKit.button("Herramientas", func(): ShopDialog.open(self, _refresh), Color(0.3, 0.35, 0.5), Vector2(0, 70)))
	right.add_child(UiKit.button("Opciones", _on_options, Color(0.3, 0.32, 0.38), Vector2(0, 70)))
	_ad_button = UiKit.button("Ver anuncio: +1 vida", func():
		RewardedAds.show(func():
			Economy.add_life(Game.profile, Game.now())
			Game.mark_dirty(true)
			_refresh()), Color(0.45, 0.3, 0.5), Vector2(0, 60))
	right.add_child(_ad_button)
	Game.profile_changed.connect(_refresh)
	_refresh()


func _process(_d: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		_refresh()


func _refresh() -> void:
	_coins_label.text = str(int(Game.profile.coins))
	var lives := Game.lives()
	_lives_label.text = "%d/%d" % [lives, Balance.MAX_LIVES]
	_stars_label.text = str(Game.total_stars())
	var s := ""
	if lives < Balance.MAX_LIVES:
		s = "Próxima vida en %s" % Game.format_time(Game.seconds_to_next_life())
	if Game.has_run():
		var key: String = Game.run.room_key
		var name := "Encargo de limpieza" if key == "contract" else "%s — %s" % [PropertyCatalog.PROPERTIES[key.split("/")[0]].name, PropertyCatalog.room_def(key).name]
		s += ("\n" if s != "" else "") + "Partida en curso: " + name
	_status.text = s
	_continue.visible = Game.has_run()
	# Sólo se muestra si hay un proveedor de anuncios integrado y listo.
	_ad_button.visible = lives < Balance.MAX_LIVES and RewardedAds.is_available()


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/room.tscn")


func _on_play() -> void:
	if Game.has_run():
		_on_continue()
		return
	var key := Game.next_story_room()
	if key == "":
		get_tree().change_scene_to_file("res://scenes/map.tscn")
		return
	var err := Game.start_room(key)
	if err != "":
		_dialog = UiKit.dialog(self, "No se puede jugar", err, [["Ir al mapa", func(): get_tree().change_scene_to_file("res://scenes/map.tscn")], ["Cerrar", func(): pass]])
		return
	get_tree().change_scene_to_file("res://scenes/room.tscn")


func _on_options() -> void:
	var extra := OptionsPanel.make()
	var reset_row := HBoxContainer.new()
	reset_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reset_row.add_child(UiKit.button("Repetir tutorial", func():
		Game.profile.tutorial = {}
		Game.mark_dirty(true)
		UiKit.toast(self, "El tutorial se mostrará otra vez en el Monoambiente"), Color(0.3, 0.35, 0.45), Vector2(240, 56)))
	reset_row.add_child(UiKit.button("Borrar progreso", func(): _confirm_reset(), UiKit.BAD.darkened(0.3), Vector2(240, 56)))
	extra.add_child(reset_row)
	_dialog = UiKit.dialog(self, "Opciones", "", [["Cerrar", func(): pass]], extra)


func _confirm_reset() -> void:
	_dialog = UiKit.dialog(self, "¿Borrar todo?", "Se pierden monedas, casas y estrellas. No se puede deshacer.", [
		["Borrar", func():
			Game.reset_progress()
			_refresh(), UiKit.BAD],
		["Cancelar", func(): pass],
	])
