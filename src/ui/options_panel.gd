class_name OptionsPanel
extends RefCounted
## Controles de opciones: sensibilidad de cámara, volumen y silencio.


static func make() -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(520, 0)
	vb.add_theme_constant_override("separation", 12)
	vb.add_child(UiKit.label("Sensibilidad de la cámara", 20))
	var sens := HSlider.new()
	sens.min_value = 0.3
	sens.max_value = 2.5
	sens.step = 0.05
	sens.value = float(Game.setting("sensitivity"))
	sens.custom_minimum_size = Vector2(0, 40)
	sens.value_changed.connect(func(v): Game.set_setting("sensitivity", v))
	vb.add_child(sens)
	vb.add_child(UiKit.label("Volumen de efectos", 20))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = float(Game.setting("volume"))
	vol.custom_minimum_size = Vector2(0, 40)
	vol.value_changed.connect(func(v):
		Game.set_setting("volume", v)
		Sfx.play("click"))
	vb.add_child(vol)
	var mute := CheckButton.new()
	mute.text = "Silenciar"
	mute.button_pressed = bool(Game.setting("mute"))
	mute.toggled.connect(func(on): Game.set_setting("mute", on))
	vb.add_child(mute)
	var fps := CheckButton.new()
	fps.text = "Mostrar FPS y memoria"
	fps.button_pressed = bool(Game.setting("show_fps"))
	fps.toggled.connect(func(on): Game.set_setting("show_fps", on))
	vb.add_child(fps)
	return vb
